
-- Leasing DB — logika biznesowa w PL/SQL

CREATE OR REPLACE PACKAGE pkg_leasing AS
    -- Rata annuitetowa (stała) dla kwoty finansowania
    FUNCTION oblicz_rate (
        p_kwota          IN NUMBER,
        p_oprocentowanie IN NUMBER,   -- % rocznie
        p_liczba_rat     IN NUMBER
    ) RETURN NUMBER;

    -- Saldo kapitału pozostałego do spłaty dla umowy
    FUNCTION saldo_umowy (p_id_umowy IN NUMBER) RETURN NUMBER;

    -- Tworzy harmonogram rat dla nowej umowy
    PROCEDURE generuj_harmonogram (p_id_umowy IN NUMBER);

    -- Księguje wpłatę do raty; zamyka ratę i umowę, gdy są spłacone
    PROCEDURE zarejestruj_platnosc (
        p_id_raty IN NUMBER,
        p_kwota   IN NUMBER,
        p_data    IN DATE DEFAULT SYSDATE
    );

    -- Oznacza raty po terminie jako zaległe; umowy z 3+ zaległymi
    -- ratami przenosi do windykacji
    PROCEDURE oznacz_zalegle (p_na_dzien IN DATE DEFAULT TRUNC(SYSDATE));
END pkg_leasing;
/

CREATE OR REPLACE PACKAGE BODY pkg_leasing AS

    FUNCTION oblicz_rate (
        p_kwota          IN NUMBER,
        p_oprocentowanie IN NUMBER,
        p_liczba_rat     IN NUMBER
    ) RETURN NUMBER IS
        v_r NUMBER := p_oprocentowanie / 12 / 100;   -- stopa miesięczna
    BEGIN
        IF p_kwota <= 0 OR p_liczba_rat <= 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Kwota i liczba rat muszą być dodatnie');
        END IF;

        IF v_r = 0 THEN
            RETURN ROUND(p_kwota / p_liczba_rat, 2);
        END IF;

        -- R = K * r / (1 - (1 + r)^-n)
        RETURN ROUND(p_kwota * v_r / (1 - POWER(1 + v_r, -p_liczba_rat)), 2);
    END oblicz_rate;


    FUNCTION saldo_umowy (p_id_umowy IN NUMBER) RETURN NUMBER IS
        v_saldo NUMBER;
    BEGIN
        SELECT NVL(SUM(kapital), 0)
          INTO v_saldo
          FROM harmonogram
         WHERE id_umowy = p_id_umowy
           AND status <> 'OPLACONA';
        RETURN v_saldo;
    END saldo_umowy;


    PROCEDURE generuj_harmonogram (p_id_umowy IN NUMBER) IS
        v_umowa     umowy%ROWTYPE;
        v_wartosc   przedmioty.wartosc_netto%TYPE;
        v_istnieje  NUMBER;
        v_saldo     NUMBER;
        v_rata      NUMBER;
        v_r         NUMBER;
        v_odsetki   NUMBER;
        v_kapital   NUMBER;
    BEGIN
        SELECT * INTO v_umowa FROM umowy WHERE id_umowy = p_id_umowy;

        SELECT COUNT(*) INTO v_istnieje
          FROM harmonogram WHERE id_umowy = p_id_umowy;
        IF v_istnieje > 0 THEN
            RAISE_APPLICATION_ERROR(-20002,
                'Harmonogram dla umowy ' || v_umowa.nr_umowy || ' już istnieje');
        END IF;

        SELECT wartosc_netto INTO v_wartosc
          FROM przedmioty WHERE id_przedmiotu = v_umowa.id_przedmiotu;

        v_saldo := v_wartosc - v_umowa.wplata_wlasna;
        v_r     := v_umowa.oprocentowanie / 12 / 100;
        v_rata  := oblicz_rate(v_saldo, v_umowa.oprocentowanie, v_umowa.liczba_rat);

        FOR i IN 1 .. v_umowa.liczba_rat LOOP
            v_odsetki := ROUND(v_saldo * v_r, 2);
            -- ostatnia rata domyka saldo (różnice z zaokrągleń)
            IF i = v_umowa.liczba_rat THEN
                v_kapital := v_saldo;
            ELSE
                v_kapital := v_rata - v_odsetki;
            END IF;

            INSERT INTO harmonogram (id_umowy, nr_raty, termin, kwota, kapital, odsetki)
            VALUES (p_id_umowy, i, ADD_MONTHS(v_umowa.data_zawarcia, i),
                    v_kapital + v_odsetki, v_kapital, v_odsetki);

            v_saldo := v_saldo - v_kapital;
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'Nie znaleziono umowy o id ' || p_id_umowy);
    END generuj_harmonogram;


    PROCEDURE zarejestruj_platnosc (
        p_id_raty IN NUMBER,
        p_kwota   IN NUMBER,
        p_data    IN DATE DEFAULT SYSDATE
    ) IS
        v_kwota_raty  harmonogram.kwota%TYPE;
        v_id_umowy    harmonogram.id_umowy%TYPE;
        v_wplacono    NUMBER;
        v_otwarte     NUMBER;
    BEGIN
        SELECT kwota, id_umowy
          INTO v_kwota_raty, v_id_umowy
          FROM harmonogram
         WHERE id_raty = p_id_raty
           FOR UPDATE;                        -- blokada raty na czas księgowania

        INSERT INTO platnosci (id_raty, data_platnosci, kwota)
        VALUES (p_id_raty, p_data, p_kwota);

        SELECT SUM(kwota) INTO v_wplacono
          FROM platnosci WHERE id_raty = p_id_raty;

        IF v_wplacono >= v_kwota_raty THEN
            UPDATE harmonogram SET status = 'OPLACONA' WHERE id_raty = p_id_raty;

            SELECT COUNT(*) INTO v_otwarte
              FROM harmonogram
             WHERE id_umowy = v_id_umowy AND status <> 'OPLACONA';

            IF v_otwarte = 0 THEN
                UPDATE umowy SET status = 'ZAKONCZONA' WHERE id_umowy = v_id_umowy;
            END IF;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20004, 'Nie znaleziono raty o id ' || p_id_raty);
    END zarejestruj_platnosc;


    PROCEDURE oznacz_zalegle (p_na_dzien IN DATE DEFAULT TRUNC(SYSDATE)) IS
    BEGIN
        UPDATE harmonogram
           SET status = 'ZALEGLA'
         WHERE status = 'NIEOPLACONA'
           AND termin < p_na_dzien;

        UPDATE umowy
           SET status = 'WINDYKACJA'
         WHERE status = 'AKTYWNA'
           AND id_umowy IN (SELECT id_umowy
                              FROM harmonogram
                             WHERE status = 'ZALEGLA'
                             GROUP BY id_umowy
                            HAVING COUNT(*) >= 3);
    END oznacz_zalegle;

END pkg_leasing;
/

-- Każda zmiana statusu umowy trafia do historii
CREATE OR REPLACE TRIGGER trg_umowy_log_statusu
AFTER UPDATE OF status ON umowy
FOR EACH ROW
WHEN (OLD.status <> NEW.status)
BEGIN
    INSERT INTO log_statusu_umowy (id_umowy, stary_status, nowy_status)
    VALUES (:NEW.id_umowy, :OLD.status, :NEW.status);
END;
/
