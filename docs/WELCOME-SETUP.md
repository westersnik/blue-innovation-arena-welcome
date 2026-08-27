# Oppsettguide: Blue Innovation Arena Event Welcome

Denne veiledningen beskriver RFID-velkomstflyten for **Blue Innovation Arena**. Løsningen bruker egne `welcome_*`-tabeller, Edge Function-en `welcome-rfid-relay` og en Zebra SN5604-sensor ved inngangen.

> **Personvern:** Konfigurasjonssiden inneholder navn og selskapsnavn. Ikke del administrasjonslenken offentlig ved reell bruk. Legg den bak tilgangskontroll eller begrens tilgangen til arrangementsansvarlige.

## 1. Datamodell og RFID-tagger

Supabase-prosjektet trenger disse migrasjonene i rekkefølge:

```text
supabase/migrations/20260810_welcome_bootstrap.sql
supabase/migrations/20260813_welcome_events.sql
supabase/migrations/20260814_event_branding.sql
```

Den første migrasjonen importerer katalogen med 300 fysiske EPC-tagger. De neste oppretter arrangementer, nummerserier, gjester, velkomstskanninger og skjermprofilering. Duplikatkontroll er innebygd i `record_welcome_scan`, slik at én tagg bare kan utløse én velkomst per arrangement.

| Funksjon | Brukes av | Formål |
|---|---|---|
| `create_welcome_event` | Konfigurasjon | Reserverer batch og en sammenhengende ID-serie. |
| `assign_welcome_guest` | Konfigurasjon | Kobler navn og selskap til én ledig ID-tagg. |
| `record_welcome_scan` | RFID-endepunkt | Validerer EPC, aktiv leser, gjest og duplikatbeskyttelse. |
| `set_welcome_event_logo` | Konfigurasjon | Knytter en logo til arrangementets storskjerm. |
| `close_welcome_event` | Konfigurasjon | Frigir aldri-tildelte tagger etter arrangementet. |

## 2. Distribuer RFID-endepunktet

Kjør fra repositoryets rot etter at Supabase CLI er koblet til prosjektet:

```bash
supabase functions deploy welcome-rfid-relay --project-ref vvqpbvicvhwqbjezifst --no-verify-jwt
```

Angi en sterk `RFID_EVENT_KEY` som Edge Function-hemmelighet. Integrasjonen som sender RFID-lesningene må oppgi samme verdi i HTTP-headeren `X-Event-Key`. Hemmeligheten skal aldri lagres i Git-repositoryet eller i en nettleser.

```text
https://vvqpbvicvhwqbjezifst.supabase.co/functions/v1/welcome-rfid-relay
```

## 3. Konfigurer Zebra SN5604 ved inngangen

Zebra SN5604 er sensoren som monteres over eller ved inngangsdøren. Den kobles til en kompatibel Zebra RFID-leser eller SmartLens-kontroller som kan videresende EPC-lesninger til dette HTTP-endepunktet. SN5604-sensoren skal derfor **ikke** konfigureres som en selvstendig HTTP-klient.

Opprett arrangementet med en unik leseridentifikator, for eksempel `zebra-sn5604-entry`. Den samme verdien må brukes av integrasjonen som sender lesningen i feltet `reader_id` eller `devid`.

| Oppsettpunkter | Anbefalt verdi |
|---|---|
| Fysisk plassering | Over inngangsdøren, med lesesonen rett innenfor passasjen. |
| Sensor | Zebra SN5604 / SmartLens Gen II Snap-sensor. |
| Videresending | Zebra RFID-leser eller SmartLens-kontroller med HTTP-integrasjon. |
| Metode | `POST` |
| Endepunkt | `https://vvqpbvicvhwqbjezifst.supabase.co/functions/v1/welcome-rfid-relay` |
| Content-Type | `application/json` |
| Header | `X-Event-Key: DIN_RFID_EVENT_KEY` |
| Leser-ID | `zebra-sn5604-entry` eller den valgte arrangementskoden. |

Eksempel på generisk melding fra Zebra-integrasjonen:

```json
{
  "reader_id": "zebra-sn5604-entry",
  "tags": [
    {"epc": "3415AFBC0C000000000007EB"}
  ]
}
```

Endepunktet støtter også `devid` sammen med `reads`, og enkeltverdier i `epc`, slik at integrasjonen kan tilpasses den aktuelle Zebra-kontrolleren. Den returnerer `200` for mottatte meldinger, men forkaster ukjente, ikke-tildelte eller repeterte lesninger på serversiden.

## 4. Opprett og klargjør arrangementet

Etter at den nye repositoryen er publisert, åpner du dens `konfigurasjon.html` og oppretter arrangementet. Velg lokasjon, RFID-batch, nummerserie og profillogo. Sett RFID-leser til samme ID som Zebra-integrasjonen, for eksempel `zebra-sn5604-entry`.

Deretter velger du arrangementet under **Registrer gjest** og knytter hvert ID-nummer til navn og selskap.

| Felt | Eksempel |
|---|---|
| ID-nummer på tagg | `42` |
| Navn | `Ada Lovelace` |
| Selskapsnavn | `Acme AS` |
| RFID-leser | `zebra-sn5604-entry` |

## 5. Åpne storskjermen

I arrangementslisten velger du **Åpne storskjerm**. Lenken inneholder arrangementets UUID, mens demoen kan bruke det korte aliaset `?event=demo`.

```text
storskjerm.html?event={EVENT_ID}
storskjerm.html?event=demo
```

Når en gyldig, tildelt tagg passerer Zebra-sonen, viser skjermen gjestens navn og selskap. Visningen går tilbake til «Klar for neste gjest» etter ni sekunder. Gjentatte lesninger er kontrollert på serversiden for å hindre flimmer på storskjermen.

## 6. Verifiser før dørene åpner

Gjennomfør en test med en liten, ubrukt nummerserie før arrangementet åpner.

1. Opprett arrangementet med samme leser-ID som Zebra-integrasjonen.
2. Tildel en fysisk RFID-tagg til et testnavn.
3. Åpne arrangementets storskjerm i et eget vindu.
4. Send en testlesning via Zebra-kontrolleren eller med `curl`.
5. Kontroller at navnet og selskapet vises én gang.
6. Test en ukjent EPC og en ikke-tildelt tagg; begge skal avvises og registreres i `welcome_feedback`.

```bash
curl -sS -X POST \
  'https://vvqpbvicvhwqbjezifst.supabase.co/functions/v1/welcome-rfid-relay' \
  -H 'Content-Type: application/json' \
  -H 'X-Event-Key: DIN_RFID_EVENT_KEY' \
  -d '{"reader_id":"zebra-sn5604-entry","tags":[{"epc":"3415AFBC0C000000000007EB"}]}'
```

En førstegangslesning skal returnere `recorded: 1`; en gjentatt lesning skal returnere en duplikatstatus i stedet for å utløse en ny velkomst.

## Avslutte arrangementet

Velg **Avslutt arrangement** i konfigurasjonssiden etter arrangementet. Bare tagger som aldri har vært tildelt, blir frigitt. Tildelte og velkomne tagger beholdes i historikken og kan ikke uforvarende gjenbrukes.
