
-- Leasing DB — zapytania raportowe


-- 1. Portfel klientów: liczba umów, wartość finansowania, saldo do spłaty
SELECT k.nazwa,
       COUNT(u.id_umowy)                                    AS liczba_umow,
       SUM(p.wartosc_netto - u.wplata_wlasna)               AS kwota_finansowania,
       SUM(pkg_leasing.saldo_umowy(u.id_umowy))             AS saldo_do_splaty
  FROM klienci k
  JOIN umowy u      ON u.id_klienta    = k.id_klienta
  JOIN przedmioty p ON p.id_przedmiotu = u.id_przedmiotu
 GROUP BY k.nazwa
 ORDER BY saldo_do_splaty DESC;


-- 2. Zaległości: które umowy mają raty po terminie i na jaką kwotę
SELECT k.nazwa,
       u.nr_umowy,
       u.status                                             AS status_umowy,
       COUNT(*)                                             AS zalegle_raty,
       SUM(h.kwota)                                         AS kwota_zalegla,
       DATE '2026-10-09' - MIN(h.termin)                    AS max_dni_opoznienia
  FROM harmonogram h
  JOIN umowy u   ON u.id_umowy   = h.id_umowy
  JOIN klienci k ON k.id_klienta = u.id_klienta
 WHERE h.status = 'ZALEGLA'
 GROUP BY k.nazwa, u.nr_umowy, u.status
 ORDER BY kwota_zalegla DESC;


-- 3. Wpływy miesięczne z narastającą sumą (funkcja okna)
SELECT TRUNC(data_platnosci, 'MM')                          AS miesiac,
       SUM(kwota)                                           AS wplywy,
       SUM(SUM(kwota)) OVER (ORDER BY TRUNC(data_platnosci, 'MM')) AS wplywy_narastajaco
  FROM platnosci
 GROUP BY TRUNC(data_platnosci, 'MM')
 ORDER BY miesiac;


-- 4. Struktura portfela wg kategorii przedmiotu (udział procentowy)
SELECT p.kategoria,
       COUNT(*)                                             AS liczba_umow,
       SUM(p.wartosc_netto)                                 AS wartosc,
       ROUND(100 * RATIO_TO_REPORT(SUM(p.wartosc_netto)) OVER (), 1) AS udzial_proc
  FROM umowy u
  JOIN przedmioty p ON p.id_przedmiotu = u.id_przedmiotu
 GROUP BY p.kategoria
 ORDER BY wartosc DESC;


-- 5. Ranking umów wg odsetek zapłaconych dotąd przez klienta
SELECT u.nr_umowy,
       k.nazwa,
       SUM(CASE WHEN h.status = 'OPLACONA' THEN h.odsetki ELSE 0 END) AS odsetki_zaplacone,
       RANK() OVER (ORDER BY SUM(CASE WHEN h.status = 'OPLACONA'
                                      THEN h.odsetki ELSE 0 END) DESC) AS miejsce
  FROM umowy u
  JOIN klienci k     ON k.id_klienta = u.id_klienta
  JOIN harmonogram h ON h.id_umowy   = u.id_umowy
 GROUP BY u.nr_umowy, k.nazwa;


-- 6. Historia zmian statusu umów (z wyzwalacza)
SELECT u.nr_umowy, l.stary_status, l.nowy_status, l.data_zmiany
  FROM log_statusu_umowy l
  JOIN umowy u ON u.id_umowy = l.id_umowy
 ORDER BY l.id_logu;
