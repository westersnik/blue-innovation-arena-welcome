# Keonn AdvanReader – Oppsettguide

**Invig Kaffe med GS1 standard · GS1 Nordic Summit 2026**

Denne guiden konfigurerer Keonn AdvanReader til å sende RFID-avlesninger direkte til Supabase Edge Function (`rfid-relay`) hver gang en kaffekopp legges i resirkuleringsstasjonen.

---

## Systemflyt

```
[Kopp legges i resirkuleringsstasjonen]
        │
        ▼
[Keonn AdvanReader leser RFID-tag EPC]
        │  HTTPS POST (JSON) – SimpleHTTPService
        ▼
[Supabase Edge Function: rfid-relay]
https://spbfuhajwfadzvdidalk.supabase.co/functions/v1/rfid-relay
        │  Slår opp EPC i `beers`-tabellen → finner GIAI
        │  Setter inn i rfid_events (idempotent – duplikater ignoreres)
        ▼
[Supabase: rfid_events-tabell]
        │  Realtime WebSocket-abonnement
        ▼
[Storskjerm: gs1-nordic.invig.no/storskjerm.html]
        │
        ▼
[Popup: "✅ [Navn] sin kopp er resirkulert!"]
```

> **Hvorfor Edge Function?** `gs1-nordic.invig.no` er en statisk GitHub Pages-side og kan ikke motta POST-forespørsler direkte. Edge Function kjører server-side, slår opp EPC-en i databasen og skriver til `rfid_events` med service role key (omgår RLS på trygg måte). Funksjonen krever ingen JWT — `verify_jwt = false` er satt i `supabase/config.toml`.

---

## Forutsetninger

- AdvanReader er koblet til eventnettet (kablet eller Wi-Fi)
- AdvanReader har internettilgang og kan nå `supabase.co` over HTTPS (port 443)
- Du har tilgang til AdvanNet Manager (webgrensesnitt på `http://<reader-ip>:8080`)
- `beers`-tabellen i Supabase er fylt med de 2 062 koppene (GIAI + EPC + kopp-nummer)

---

## Steg 1 – Åpne AdvanNet Manager

1. Åpne nettleser og gå til `http://<reader-ip>:8080`
2. Logg inn med AdvanNet-legitimasjon
3. Klikk **Services** i venstremenyen
4. Velg **SimpleHTTPService**
5. Slå på **Advanced**-modus (øverst til høyre i Services-panelet)

---

## Steg 2 – HTTP-tilkoblingsinnstillinger

Fyll inn feltene **nøyaktig** som vist:

| Felt | Verdi |
|---|---|
| **Enabled** | ✅ Avkrysset |
| **Endpoint URL** | `https://spbfuhajwfadzvdidalk.supabase.co/functions/v1/rfid-relay` |
| **HTTP method** | `POST` |
| **Content-Type** | `JSON (application/json)` |
| **Username (Basic auth)** | *(la stå tomt)* |
| **Password (Basic auth)** | *(la stå tomt)* |

> Ingen Basic Auth er nødvendig — Edge Function bruker en event-nøkkel i headeren i stedet.

---

## Steg 3 – Avanserte HTTP-innstillinger

| Felt | Verdi |
|---|---|
| **Send one by one** | ☐ Ikke avkrysset (batch-modus) |
| **Inventory tag TTL (s)** | `60` |
| **Re-send when in error** | ✅ Avkrysset |
| **Expected HTTP response** | `200` |

> **TTL-merknad:** Med TTL = 60 sendes samme EPC maksimalt én gang per minutt. Edge Function håndhever også idempotens på databasenivå — duplikat-EPC gir en `23505`-feil (unik indeks) og ignoreres stille.

---

## Steg 4 – JSON Config

Lim inn følgende i feltet **JSON config**. Malen bygger korrekt JSON-body fra AdvanNet-skriptvariabler:

```
[{"event":"TAG_READ","path":"'/functions/v1/rfid-relay'","body":"var body='{';body+='\"devid\": \"'+ctx_devid+'\",';body+='\"devip\": \"'+ctx_devip+'\",';body+='\"reads\": [';for(i=0;i<ctx_tags.length;i++){body+='{';body+='\"epc\": \"'+ctx_tags[i].getEPC()+'\",';body+='\"rssi\": \"'+ctx_tags[i].getRSSI()+'\",';body+='\"ts\": \"'+ctx_tags[i].getUTC()+'\"';body+='}';if(i<ctx_tags.length-1){body+=',';}}body+=']';body+='}';"  }]
```

> Valider JSON-en på [jsonlint.com](https://jsonlint.com/) før du lagrer (fjern linjeskift først).

Resulterende payload som sendes til Edge Function:

```json
{
  "devid": "advanreader-01",
  "devip": "192.168.1.50",
  "reads": [
    {
      "epc": "3415AFBC0C000000000007EB",
      "rssi": "-62",
      "ts": "2026-06-10T09:14:32Z"
    }
  ]
}
```

---

## Steg 5 – Custom Header (anbefalt)

Legg til event-nøkkel-headeren for ekstra sikkerhet. Lim inn i feltet **Advanced JSON conf**:

```json
{"customHeaders":[{"header":"X-Event-Key: gs1nordic2026"}]}
```

---

## Steg 6 – Test tilkoblingen

Etter lagring, test med `curl` fra en hvilken som helst maskin:

```bash
# Test med kopp #1 (EPC for GIAI 70735392043)
curl -s -X POST \
  "https://spbfuhajwfadzvdidalk.supabase.co/functions/v1/rfid-relay" \
  -H "Content-Type: application/json" \
  -H "X-Event-Key: gs1nordic2026" \
  -d '{"epc":"3415AFBC0C000000000007EB","reader_id":"advanreader-test"}'
```

**Forventet svar – første skanning:**
```json
{
  "success": true,
  "processed": 1,
  "recorded": 1,
  "duplicates": 0,
  "skipped": 0,
  "results": [
    {
      "epc": "3415AFBC0C000000000007EB",
      "giai": "70735392043",
      "bottle_num": 1,
      "status": "recorded"
    }
  ]
}
```

**Forventet svar – duplikat (samme EPC igjen):**
```json
{
  "success": true,
  "processed": 1,
  "recorded": 0,
  "duplicates": 1,
  "skipped": 0,
  "results": [
    {
      "epc": "3415AFBC0C000000000007EB",
      "giai": "70735392043",
      "bottle_num": 1,
      "status": "duplicate"
    }
  ]
}
```

**Forventet svar – ukjent tag (ikke i `beers`-tabellen):**
```json
{
  "success": true,
  "processed": 1,
  "recorded": 0,
  "duplicates": 0,
  "skipped": 1,
  "results": [
    {
      "epc": "AABBCCDD00112233",
      "giai": null,
      "bottle_num": null,
      "status": "skipped (not an event bottle)"
    }
  ]
}
```

---

## EPC ↔ GIAI-mapping

AdvanReader returnerer rå EPC-heksadesimalkoder. Edge Function slår opp EPC-en direkte i `beers`-tabellen (forhåndsberegnet fra Excel-filen med 2 062 kopper).

**GIAI-96 EPC-struktur** for GCP `7073539` (7 sifre, partisjon 5):

| Felt | Bits | Verdi | Merknad |
|---|---|---|---|
| Header | 8 | `0x34` | GIAI-96 — **ikke** `0x30` (SGTIN-96) |
| Filter | 3 | `1` | |
| Partisjon | 3 | `5` | 7-sifret GCP |
| GCP | 24 | `0xAFBC0C` | = 7073539 desimal |
| Asset Reference | 58 | kopp-nummer | = GIAI − 70735390000 |

**Eksempel-mapping:**

| EPC (hex, fra leser) | GIAI | Kopp # |
|---|---|---|
| `3415AFBC0C000000000007EB` | `70735392043` | 1 |
| `3415AFBC0C000000000007EC` | `70735392044` | 2 |
| `3415AFBC0C000000000007F4` | `70735392052` | 10 |
| `3415AFBC0C00000000000FF8` | `70735394104` | 2062 |

---

## Feilsøking

| Symptom | Sannsynlig årsak | Løsning |
|---|---|---|
| Ingen POST mottas av Edge Function | SimpleHTTPService ikke aktivert | Aktiver i AdvanNet Manager → Services |
| `401 Unauthorized` | Feil `X-Event-Key`-header | Bruk `gs1nordic2026` |
| `400 Bad Request` | Ugyldig JSON config | Valider på jsonlint.com |
| Alle tags returnerer `skipped (not an event bottle)` | EPC ikke i `beers`-tabellen | Sjekk at koppene er programmert med riktig GIAI-område; verifiser at EPC-header er `0x34` (GIAI-96) og ikke `0x30` (SGTIN-96) |
| `duplicate` for alle tags | EPC allerede i `rfid_events` | Forventet og korrekt. For ny test: `DELETE FROM rfid_events;` i Supabase SQL-editor |
| Storskjerm oppdateres ikke | Supabase Realtime ikke tilkoblet | Sjekk nettleserkonsollen for WebSocket-feil; last inn `storskjerm.html` på nytt |
| HTTPS-sertifikatfeil på leser | Nettverks-/DNS-problem | Verifiser at leseren har internettilgang og kan nå `supabase.co` |
| Tags leses men sendes ikke | TTL ikke utløpt | Sett TTL til `5` for testing, tilbake til `60` for eventet |
| Storskjerm viser ikke navn | Kopp ikke registrert via QR | Gjest må skanne QR-koden og registrere seg i V2-siden før resirkulering |

---

## Tøm databasen for ny test

Kjør i Supabase SQL-editor (`https://supabase.com/dashboard/project/spbfuhajwfadzvdidalk/editor`):

```sql
DELETE FROM rfid_events;
DELETE FROM registrations;
DELETE FROM rfid_feedback;
```

> **OBS:** Slett **ikke** `beers`-tabellen — den inneholder de 2 062 koppenes EPC-mapping og er nødvendig for at Edge Function skal fungere.

---

## Redeploy Edge Function

Hvis `rfid-relay` trenger oppdatering:

```bash
cd gs1-nordic-summit
supabase login   # bruk Supabase Personal Access Token (hentes fra https://supabase.com/dashboard/account/tokens)
supabase link --project-ref spbfuhajwfadzvdidalk
supabase functions deploy rfid-relay --no-verify-jwt
```

---

## Referanser

- [Keonn HTTP Service-dokumentasjon](https://wiki.keonn.com/software/advannet/services/http-service)
- [Keonn HTTP Payload JSON config-maler](https://wiki.keonn.com/software/advannet/services/http-service/http-payload-json-config-templates)
- [GS1 GIAI Application Identifier 8004](https://www.gs1.org/standards/id-keys/giai)
- [GS1 TDS 1.13 – GIAI-96 EPC-struktur](https://www.gs1.org/sites/default/files/docs/epc/GS1_EPC_TDS_i1_13.pdf)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Supabase Realtime](https://supabase.com/docs/guides/realtime)
- [jsonlint.com – JSON-validator](https://jsonlint.com/)
