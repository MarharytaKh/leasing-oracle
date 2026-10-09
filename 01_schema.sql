-- Leasing DB — schemat bazy danych (Oracle)
-- Ewidencja klientów, przedmiotów leasingu, umów, harmonogramów rat
-- i płatności.

CREATE TABLE klienci (
    id_klienta       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nazwa            VARCHAR2(100) NOT NULL,
    nip              VARCHAR2(10)  NOT NULL UNIQUE,
    typ              VARCHAR2(10)  NOT NULL CHECK (typ IN ('FIRMA', 'OSOBA')),
    data_rejestracji DATE DEFAULT SYSDATE NOT NULL
);

CREATE TABLE przedmioty (
    id_przedmiotu  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kategoria      VARCHAR2(20)  NOT NULL
                   CHECK (kategoria IN ('SAMOCHOD', 'MASZYNA', 'SPRZET_IT')),
    opis           VARCHAR2(200) NOT NULL,
    wartosc_netto  NUMBER(12,2)  NOT NULL CHECK (wartosc_netto > 0)
);

CREATE TABLE umowy (
    id_umowy        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nr_umowy        VARCHAR2(20) NOT NULL UNIQUE,
    id_klienta      NUMBER NOT NULL REFERENCES klienci(id_klienta),
    id_przedmiotu   NUMBER NOT NULL UNIQUE REFERENCES przedmioty(id_przedmiotu),
    data_zawarcia   DATE   NOT NULL,
    liczba_rat      NUMBER(3)    NOT NULL CHECK (liczba_rat BETWEEN 6 AND 120),
    oprocentowanie  NUMBER(5,2)  NOT NULL CHECK (oprocentowanie >= 0),  -- % rocznie
    wplata_wlasna   NUMBER(12,2) DEFAULT 0 NOT NULL CHECK (wplata_wlasna >= 0),
    status          VARCHAR2(15) DEFAULT 'AKTYWNA' NOT NULL
                    CHECK (status IN ('AKTYWNA', 'ZAKONCZONA', 'WINDYKACJA'))
);

CREATE TABLE harmonogram (
    id_raty   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_umowy  NUMBER NOT NULL REFERENCES umowy(id_umowy) ON DELETE CASCADE,
    nr_raty   NUMBER(3)    NOT NULL,
    termin    DATE         NOT NULL,
    kwota     NUMBER(12,2) NOT NULL,
    kapital   NUMBER(12,2) NOT NULL,
    odsetki   NUMBER(12,2) NOT NULL,
    status    VARCHAR2(12) DEFAULT 'NIEOPLACONA' NOT NULL
              CHECK (status IN ('NIEOPLACONA', 'OPLACONA', 'ZALEGLA')),
    CONSTRAINT uq_rata UNIQUE (id_umowy, nr_raty)
);

CREATE TABLE platnosci (
    id_platnosci    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_raty         NUMBER NOT NULL REFERENCES harmonogram(id_raty),
    data_platnosci  DATE   DEFAULT SYSDATE NOT NULL,
    kwota           NUMBER(12,2) NOT NULL CHECK (kwota > 0)
);

-- Historia zmian statusu umów (wypełniana przez wyzwalacz)
CREATE TABLE log_statusu_umowy (
    id_logu      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_umowy     NUMBER       NOT NULL,
    stary_status VARCHAR2(15),
    nowy_status  VARCHAR2(15) NOT NULL,
    data_zmiany  DATE         DEFAULT SYSDATE NOT NULL,
    uzytkownik   VARCHAR2(128) DEFAULT USER NOT NULL
);

-- Indeksy pod najczęstsze zapytania raportowe
CREATE INDEX ix_umowy_klient     ON umowy(id_klienta);
CREATE INDEX ix_harm_status_term ON harmonogram(status, termin);
CREATE INDEX ix_platnosci_rata   ON platnosci(id_raty);
