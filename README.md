# Leasing DB — baza umów leasingowych w Oracle

Mała baza danych firmy leasingowej: klienci, przedmioty leasingu, umowy,
harmonogramy rat i płatności. Logika biznesowa napisana w **PL/SQL**,
raporty w **SQL** z funkcjami okna.

- **Harmonogram rat**: na podstawie wartości przedmiotu, wpłaty własnej,
  oprocentowania i liczby rat procedura liczy ratę annuitetową i rozbija
  każdą ratę na kapitał i odsetki.
- **Księgowanie płatności**: wpłata zamyka ratę, a spłata ostatniej raty
  automatycznie zamyka umowę.
- **Kontrola zaległości**: raty po terminie oznaczane są jako zaległe,
  a umowa z 3 lub więcej zaległymi ratami przechodzi do windykacji.
- **Historia statusów**: wyzwalacz zapisuje każdą zmianę statusu umowy.
- **Raporty**: portfel klientów, zaległości, wpływy miesięczne
  narastająco, struktura portfela, ranking umów.

## Model danych

```
klienci 1───* umowy *───1 przedmioty
                 │
                 1
                 │
                 * harmonogram 1───* platnosci

umowy ──(trigger)──> log_statusu_umowy
```
## Uruchomienie

Skrypty działają w Oracle Database 19c+ lub w przeglądarce w
[Oracle Live SQL](https://livesql.oracle.com). Kolejność:

1. `01_schema.sql` — tabele, ograniczenia, indeksy
2. `02_plsql.sql` — pakiet i wyzwalacz
3. `03_dane.sql` — dane testowe i przykładowe scenariusze
4. `04_raporty.sql` — raporty

Dane testowe pokazują cztery scenariusze: umowę spłacaną w terminie,
umowę w windykacji, umowę z jedną zaległą ratą i umowę spłaconą w całości.
