# Event Welcome – GS1 Nordic

**Event Welcome** er en separat avlegger av GS1 Nordic-prosjektet for personlige velkomster på arrangementer. I stedet for å registrere kopper og resirkulering, kobler løsningen en RFID-tagg til en gjests **navn** og **selskap**. Når taggen leses av i arrangementets RFID-sone, viser storskjermen:

> **Velkommen til vår stand!**
>
> *[Navn], [Selskap]*

Prosjektet beholder den etablerte modellen for **flere arrangementer**, **RFID-leser per aktivt arrangement**, **taggbatcher** og **sammenhengende nummerserier**.

## Arbeidsflyt

| Steg | Ansvarlig | Handling |
|---:|---|---|
| 1 | Arrangør | Oppretter arrangement med stand/lokasjon, RFID-leser, batch og ID-nummerserie. |
| 2 | Arrangør | Taster ID-nummeret på taggen, navn og selskap i konfigurasjonssiden. |
| 3 | Arrangør | Gir den tildelte taggen til gjesten. |
| 4 | RFID-leser | Poster EPC-data til `welcome-rfid-relay`. |
| 5 | Storskjerm | Mottar en ny `welcome_scans`-rad i sanntid og viser personlig velkomst. |

## Viktige sider

| Side | Fil | Formål |
|---|---|---|
| Startside | `https://westersnik.github.io/gs1-nordic-welcome/` | Kort introduksjon og inngang til administrasjon. |
| Konfigurasjon | `https://westersnik.github.io/gs1-nordic-welcome/konfigurasjon.html` | Opprette/avslutte arrangementer og tildele gjester til taggnummer. |
| Storskjerm | `https://westersnik.github.io/gs1-nordic-welcome/storskjerm.html?event={EVENT_ID}` | Sanntids velkomstvisning for TV eller projektor. |
| RFID-katalog | `supabase/migrations/20260810_welcome_bootstrap.sql` | Importerer 300 fysiske EPC-tagger med synlige ID-numre 1–300. |
| Datamigrasjon | `supabase/migrations/20260813_welcome_events.sql` | Nye tabeller, funksjoner, indekser og Realtime-publisering. |
| RFID-endepunkt | `supabase/functions/welcome-rfid-relay/index.ts` | Edge Function som validerer RFID-lesninger og utløser velkomst. |
| Oppsettguide | `docs/WELCOME-SETUP.md` | Stegvis database-, funksjons- og leseroppsett. |

## Datamodell

| Tabell | Innhold |
|---|---|
| `welcome_tag_batches` | Tilgjengelige RFID-tagg-batcher og synlige nummerserier. |
| `welcome_events` | Arrangement, lokasjon, leser, batch og tildelt serie. |
| `welcome_event_tags` | Fysiske tagger som er reservert til arrangementet. |
| `welcome_guests` | Navn og selskap knyttet til én tildelt tagg. |
| `welcome_scans` | Én godkjent velkomstlesning per tagg; Realtime-kilden for storskjermen. |
| `welcome_feedback` | Avviste lesninger med feilmelding for feilsøking. |

Tagger følger livssyklusen **available → assigned → welcomed**. Ved avslutning frigjøres kun tagger som aldri er tildelt. Dermed kan ubrukt materiell gjenbrukes, mens persondata og historikk ikke blandes med nye arrangementer.

## Produksjonsoppsett

GitHub Pages publiseres fra `gh-pages`-grenens rotmappe. Supabase-prosjektet `vvqpbvicvhwqbjezifst` inneholder RFID-katalogen på 300 tagger og hele velkomstdatamodellen. Funksjonen `welcome-rfid-relay` er distribuert uten JWT og er beskyttet av den separate `RFID_EVENT_KEY`-hemmeligheten.

Konfigurer Keonn AdvanReader til å poste til:

```text
https://vvqpbvicvhwqbjezifst.supabase.co/functions/v1/welcome-rfid-relay
```

Detaljert konfigurasjon, inkludert header og testflyt, finnes i [oppsettguiden](docs/WELCOME-SETUP.md).

## Lokal kvalitetssikring

```bash
node tests/welcome_flow.test.mjs
```

Prosjektet består av statiske HTML-, CSS- og JavaScript-filer. Publiser grenen `gh-pages` etter at database og Edge Function er oppdatert.

```bash
git add .
git commit -m "Implement event welcome experience"
git push origin gh-pages
```

## Avgrensning

Denne avleggeren inneholder en selvstendig fysisk EPC-katalog med 300 RFID-tagger i oppstartsmigrasjonen og bruker et eget prefiks (`welcome_*`) for arrangementer, gjester og lesninger. Den offentlige GitHub Pages-versjonen eksponerer kun Event Welcome-flater.
