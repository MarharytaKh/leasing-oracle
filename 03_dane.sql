
-- Leasing DB — dane testowe
-- Scenariusze: umowa spłacana w terminie, umowa w windykacji,
-- umowa z jedną zaległą ratą, umowa w pełni spłacona.


INSERT INTO klienci (nazwa, nip, typ) VALUES ('TransLog Sp. z o.o.',  '5250000001', 'FIRMA');
INSERT INTO klienci (nazwa, nip, typ) VALUES ('BudMax S.A.',          '5250000002', 'FIRMA');
INSERT INTO klienci (nazwa, nip, typ) VALUES ('Jan Kowalski',         '5250000003', 'OSOBA');
INSERT INTO klienci (nazwa, nip, typ) VALUES ('SoftPoint Sp. z o.o.', '5250000004', 'FIRMA');
INSERT INTO przedmioty (kategoria, opis, wartosc_netto) VALUES ('SAMOCHOD',  'Samochód dostawczy, 3,5 t', 145000);
INSERT INTO przedmioty (kategoria, opis, wartosc_netto) VALUES ('MASZYNA',   'Koparka gąsienicowa',       420000);
INSERT INTO przedmioty (kategoria, opis, wartosc_netto) VALUES ('SAMOCHOD',  'Samochód osobowy',           98000);
INSERT INTO przedmioty (kategoria, opis, wartosc_netto) VALUES ('SPRZET_IT', 'Serwery i macierz dyskowa',  60000);

INSERT INTO umowy (nr_umowy, id_klienta, id_przedmiotu, data_zawarcia, liczba_rat, oprocentowanie, wplata_wlasna)
SELECT 'L/2025/11/001', k.id_klienta, p.id_przedmiotu, DATE '2025-11-01', 24, 8.5, 20000
  FROM klienci k, przedmioty p WHERE k.nip = '5250000001' AND p.opis = 'Samochód dostawczy, 3,5 t';

INSERT INTO umowy (nr_umowy, id_klienta, id_przedmiotu, data_zawarcia, liczba_rat, oprocentowanie, wplata_wlasna)
SELECT 'L/2026/01/002', k.id_klienta, p.id_przedmiotu, DATE '2026-01-15', 48, 9.2, 50000
  FROM klienci k, przedmioty p WHERE k.nip = '5250000002' AND p.opis = 'Koparka gąsienicowa';

INSERT INTO umowy (nr_umowy, id_klienta, id_przedmiotu, data_zawarcia, liczba_rat, oprocentowanie, wplata_wlasna)
SELECT 'L/2026/06/003', k.id_klienta, p.id_przedmiotu, DATE '2026-06-01', 36, 7.9, 10000
  FROM klienci k, przedmioty p WHERE k.nip = '5250000003' AND p.opis = 'Samochód osobowy';

INSERT INTO umowy (nr_umowy, id_klienta, id_przedmiotu, data_zawarcia, liczba_rat, oprocentowanie, wplata_wlasna)
SELECT 'L/2024/10/004', k.id_klienta, p.id_przedmiotu, DATE '2024-10-01', 12, 6.5, 0
  FROM klienci k, przedmioty p WHERE k.nip = '5250000004' AND p.opis = 'Serwery i macierz dyskowa';

-- Harmonogramy rat dla wszystkich umów
BEGIN
    FOR u IN (SELECT id_umowy FROM umowy ORDER BY id_umowy) LOOP
        pkg_leasing.generuj_harmonogram(u.id_umowy);
    END LOOP;
END;
/

-- Wpłaty: ile pierwszych rat opłacił każdy klient (w dniu terminu)
DECLARE
    PROCEDURE oplac_raty (p_nr_umowy VARCHAR2, p_ile NUMBER) IS
    BEGIN
        FOR r IN (SELECT h.id_raty, h.kwota, h.termin
                    FROM harmonogram h JOIN umowy u ON u.id_umowy = h.id_umowy
                   WHERE u.nr_umowy = p_nr_umowy AND h.nr_raty <= p_ile
                   ORDER BY h.nr_raty) LOOP
            pkg_leasing.zarejestruj_platnosc(r.id_raty, r.kwota, r.termin);
        END LOOP;
    END;
BEGIN
    oplac_raty('L/2025/11/001', 11);  -- płaci w terminie
    oplac_raty('L/2026/01/002', 4);   -- 4 raty po terminie  windykacja
    oplac_raty('L/2026/06/003', 3);   -- 1 rata po terminie
    oplac_raty('L/2024/10/004', 12);  -- spłacona w całości  ZAKONCZONA
END;
/

-- Przegląd zaległości na stały dzień, żeby wyniki były powtarzalne
BEGIN
    pkg_leasing.oznacz_zalegle(DATE '2026-10-09');
END;
/

COMMIT;
