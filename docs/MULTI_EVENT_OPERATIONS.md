# Drift av flere arrangementer

Denne løsningen gjør Digi-Coffee gjenbrukbar på flere lokasjoner og arrangementer. Hvert arrangement velger en **lokasjon**, en **RFID-leser**, én **lagerbatch** og en sammenhengende nummerserie. Systemet beregner selv antall tildelte kopper fra nummerserien og bruker dette som mål på storskjermen. [1]

> **Åpen konfigurasjon:** Konfigurasjonssiden er tilgjengelig uten innlogging etter uttrykkelig valg. Del derfor bare lenken med arrangementsansvarlige.

## Konfigurasjonssiden

Åpne [konfigurasjonssiden](https://gs1-nordic.invig.no/konfigurasjon.html) og opprett et arrangement. Når arrangementet er opprettet, vises egne lenker til storskjerm og digital koppflate. Disse lenkene inneholder arrangementets ID og gjør at registreringer, RFID-lesninger og fremdrift filtreres til riktig arrangement. [2]

| Felt | Betydning |
|---|---|
| **Arrangementnavn** | Navnet som vises på storskjermen. |
| **Lokasjon** | Fritt navn, for eksempel «GS1 Norge» eller «Invig showroom». Lokasjoner kan gjenbrukes. |
| **RFID-leser** | Identifikatoren leseren sender, normalt `advanreader`. Én leser kan ha ett aktivt arrangement om gangen. |
| **Koppbatch** | Lagerbatchen som inneholder de fysiske EPC- og GIAI-tagene. Produktmodus kommer fra batchen. |
| **Fra / til koppnummer** | Den delen av batchen som reserveres til arrangementet. Det beregnede antallet blir fremdriftsmålet. |

## Batch og produktmodus

Produktmodus ligger på **batchen**, ikke på arrangementet. Dette gjør at en fremtidig batch kan registreres som kaffe eller øl uten å endre eksisterende arrangementer.

| Batch | Produkttype | Synlig nummerserie | Status |
|---|---|---:|---|
| `coffee-batch-1` | Kaffe | 1–2062 | Opprettet fra eksisterende kaffekatalog |
| `coffee-batch-2` | Kaffe | 1–500 | Opprettet fra batch 2; fysisk `bottle_num` 4096–4595 vises som 1–500 |
| Fremtidig batch 3+ | Kaffe eller øl | Defineres ved import | Klar for å opprette |

En ny batch må opprettes i `cup_batches` med `product_mode = 'coffee'` eller `product_mode = 'beer'`, og de importerte koppene må få denne batchens `batch_id` og riktig `display_number`. [1]

## Eksempel: GS1-demo med en del av lageret

Velg eksempelvis batch 1 og serien **50–249** for nøyaktig 200 kopper. Serien **50–250** består av 201 kopper, fordi begge ytterpunktene teller med.

Når arrangementet startes, reserveres alle valgte fysiske kopper. RFID-reléet aksepterer bare tagger som både tilhører riktig batch og er tildelt arrangementet. Dette beskytter mot at en kopp fra en annen demo blandes inn i statistikken. [3]

Storskjermlenken for arrangementet viser en fremdriftslinje som er basert på:

> **resirkulerte kopper / tildelte kopper**

En registrert kopp teller i registreringskortet. En resirkulert kopp teller i fremdriftslinjen. Det er derfor mulig å vise en korrekt fremdrift selv om bare en del av koppene blir brukt.

## Avslutte et arrangement og bruke kopper senere

Konfigurasjonssiden viser knappen **Avslutt arrangement** bare for aktive arrangementer. Før avslutning viser løsningen en dialog med en konkret oppsummering. Ansvarlig må velge **Ja, avslutt arrangement** for å fortsette.

| Koppstatus ved avslutning | Resultat |
|---|---|
| **Ubrukt / allokert** | Frigis og kan brukes i et senere arrangement. |
| **Registrert** | Beholdes som brukt i arrangementshistorikken. |
| **Resirkulert** | Beholdes som brukt i arrangementshistorikken. |

For GS1-eksempelet betyr dette at dersom 200 kopper er tildelt og bare 50 er brukt, frigjøres de 150 som fortsatt står som **allokert**. De 50 brukte koppene forblir knyttet til arrangementet og kan ikke ved et uhell tildeles på nytt. [1]

### Verifisert scenario

En rollback-only test er kjørt mot Supabase uten å etterlate testdata. Testen opprettet arrangement 1 med koppene #50–#249, markerte 50 som brukt, avsluttet arrangementet og opprettet arrangement 2 med koppene #100–#249. Resultatet var at **150 kopper** kunne tildeles arrangement 2. Testskriptet er lagret i repositoryet. [4]

## RFID- og QR-flyt

Konfigurasjonslenkene gir både storskjerm og V2-siden et `event`-parameter. QR-registrering bruker da `claim_event_cup`, som kontrollerer at koppen er tildelt det aktive arrangementet før den kan registreres. RFID-reléet lagrer på tilsvarende måte `event_id` og `event_cup_id` på lesningen. [2] [3]

Før et arrangement opprettes for en leser beholder RFID-reléet den gamle, uavgrensede driftsmåten. Dette er en kompatibilitetsmekanisme for dagens demo. Når et aktivt arrangement er konfigurert for leseren, avvises tagger som ikke er med i den valgte batchen eller nummerserien. [3]

## Referanser

[1]: ../supabase/migrations/20260811_multi_event_configuration.sql "Batch-, arrangement- og koppallokeringsskjema"
[2]: ../konfigurasjon.html "Åpen arrangementskonfigurasjon"
[3]: ../supabase/functions/rfid-relay/index.ts "RFID-relé med arrangementsskoping"
[4]: ../supabase/tests/event_reuse_rollback_test.sql "Rollback-only test av gjenbruk"
