# GS1 Nordic Summit – Carlsberg Bottle Tracker

**Invig Locate IT** · GS1 Digital Link demo · Keonn AdvanReader · Bifrost API

Dette repoet inneholder landingssider og et event-dashboard for demonstrasjonen av GS1 Digital Link på GS1 Nordic Summit 2025. 300 Carlsberg-flasker er utstyrt med unike RFID-tagger og QR-koder. Deltakere skanner sin flaske, registrerer navn og selskap, og flasken spores fra bryggeri til pant via GS1 GIAI og Invig Bifrost API.

---

## Live URL-er

| Side | URL | Formål |
|---|---|---|
| **Flaske-side (V2)** | `…/V2/?giai={GIAI}` | Vises når deltaker skanner QR-kode |
| **Dashboard** | `…/dashboard.html` | Oversikt med leaderboard og RFID-feed |
| **Storskjerm** | `…/storskjerm.html` | Ren display-side for TV/projektor |

Base URL: `https://westersnik.github.io/gs1-nordic-summit/`

**Eksempel – flaske #1:**
```
https://westersnik.github.io/gs1-nordic-summit/V2/?giai=70735391641
```

**GS1 Digital Link redirect (via Invig resolver):**
```
https://id.invig.no/8004/70735391641
  → https://westersnik.github.io/gs1-nordic-summit/V2/?giai=70735391641
```

---

## Filstruktur

```
gs1-nordic-summit/ (gh-pages branch)
├── index.html              # V1 – enkel landingsside
├── dashboard.html          # Event-dashboard med leaderboard og RFID-feed
├── storskjerm.html         # Storskjerm-display (TV/projektor)
├── RFID-PANT-USERSTORY.md  # User stories og RFID-praksis
├── README.md               # Denne filen
└── V2/
    ├── index.html          # V2 – dynamisk flaske-side med registrering
    ├── bottles.json        # 300 flasker: EPC, GIAI, redirect-URL
    └── img/
        ├── invig-logo.png
        ├── hero-bottle.jpg
        ├── temp-chart.jpg
        ├── journey-map.jpg
        └── gs1-event-bg.jpg
```

---

## Dataflyt

```
[Carlsberg-flaske]
    │
    ├── QR-kode → https://id.invig.no/8004/{GIAI}
    │       └── Invig GS1 Digital Link resolver
    │               └── V2/index.html?giai={GIAI}
    │                       └── Deltaker registrerer navn + selskap
    │                               └── Lagres i localStorage (nå) / Bifrost (produksjon)
    │
    └── RFID-tag (EPC Gen2 UHF 865–868 MHz)
            └── Tom flaske kastes i pant-beholder
                    └── Keonn AdvanReader leser EPC
                            └── EPC → GIAI (via bottles.json)
                                    └── GIAI → bruker-oppslag
                                            └── dashboard.html / storskjerm.html oppdateres
```

---

## GS1 GIAI – Identifikasjonsstruktur

Hver flaske har en unik **GIAI (Global Individual Asset Identifier)** i henhold til GS1-standarden.

| Felt | Verdi | Forklaring |
|---|---|---|
| GS1 Application Identifier | `8004` | Identifiserer GIAI i GS1 Digital Link |
| GS1 Company Prefix (GCP) | `7073539` | Invig AS sitt GCP |
| Asset reference | `1641`–`1940` | Unikt nummer per flaske (300 stk) |
| Full GIAI (eksempel) | `70735391641` | GCP + asset reference |
| GS1 elementstreng | `(8004) 70735391641` | Standard GS1-notasjon |
| EPC (RFID, hex) | `3415AFBC0C00000000000669` | 96-bit EPC Gen2 encoding |
| Redirect-URL | `https://id.invig.no/8004/70735391641` | GS1 Digital Link |

**EPC-encoding (GS1 GIAI-96):**
```
Header    (8 bit):  34 hex  → GIAI-96
Filter    (3 bit):  1
Partition (3 bit):  5
GCP      (24 bit):  7073539 → 0xAFBC0C
Asset    (38 bit):  flaske-nummer
```

Alle 300 EPC/GIAI-par er tilgjengelige i [`V2/bottles.json`](V2/bottles.json).

---

## Keonn AdvanReader – Integrasjon

### REST API

Keonn AdvanReader eksponerer et REST API via **AdvanNet**-firmware. Dashboard og storskjerm poller dette endepunktet for å hente leste RFID-tagger.

**Primært endepunkt:**
```http
GET http://{reader-ip}/rest/session/tags
Accept: application/json
```

**Respons:**
```json
{
  "tags": [
    {
      "epc": "3415AFBC0C00000000000669",
      "rssi": -62,
      "port": 1,
      "ts": 1716300000000
    }
  ]
}
```

**Alternative endepunkter (eldre firmware):**
```
GET http://{reader-ip}/api/inventory/tags
GET http://{reader-ip}/rest/tags
```

Dashboardet prøver alle tre automatisk.

### Konfigurere storskjerm mot leser

Åpne storskjermen med reader-IP som URL-parameter:
```
storskjerm.html?reader=192.168.1.100&interval=3
```

| Parameter | Standard | Beskrivelse |
|---|---|---|
| `reader` | – | IP-adresse til Keonn AdvanReader |
| `interval` | `3` | Polling-intervall i sekunder |

### CORS-proxy (nødvendig for produksjon)

Keonn AdvanReader returnerer ikke CORS-headere, noe som blokkerer direkte API-kall fra nettleseren. For produksjon anbefales en enkel proxy.

**nginx (anbefalt):**
```nginx
server {
    listen 8080;
    location /rfid/ {
        proxy_pass http://192.168.1.100/;
        add_header Access-Control-Allow-Origin *;
        add_header Access-Control-Allow-Methods "GET, OPTIONS";
    }
}
```

Oppdater deretter `readerIP` i `storskjerm.html` til `localhost:8080/rfid`.

---

## Bifrost API – Integrasjonsguide

[Invig Bifrost](https://invig.no) er Invig sin backend-plattform for asset-sporing. Når systemet kobles mot Bifrost, erstattes `localStorage` med persistent, delt lagring som fungerer på tvers av alle enheter og bevares etter eventet.

Kontakt [sales@invig.no](mailto:sales@invig.no) for API-nøkkel og onboarding.

### Autentisering

```http
Authorization: Bearer {BIFROST_API_KEY}
Content-Type: application/json
```

### Endepunkter

#### Hente asset-informasjon fra GIAI

```http
GET https://api.bifrost.invig.no/v1/assets/{giai}
Authorization: Bearer {API_KEY}
```

**Respons:**
```json
{
  "giai": "70735391641",
  "name": "Carlsberg 330ml",
  "type": "bottle",
  "customer": "GS1 Nordic Summit",
  "status": "active",
  "location": {
    "name": "Oslo Spektrum",
    "lat": 59.9139,
    "lon": 10.7522,
    "ts": "2025-05-14T18:30:00Z"
  },
  "temperature": {
    "current": 4.2,
    "unit": "celsius",
    "ts": "2025-05-14T18:28:00Z"
  },
  "journey": [
    { "location": "Carlsberg Fredericia", "ts": "2025-05-10T08:00:00Z", "temp": 3.8 },
    { "location": "Kastrup Lager",        "ts": "2025-05-12T14:00:00Z", "temp": 4.1 },
    { "location": "Oslo Spektrum",        "ts": "2025-05-14T10:00:00Z", "temp": 4.2 }
  ]
}
```

#### Registrere en drikker på en flaske

```http
POST https://api.bifrost.invig.no/v1/assets/{giai}/registrations
Authorization: Bearer {API_KEY}
Content-Type: application/json

{
  "phone": "+4790000001",
  "name": "Ola Nordmann",
  "company": "GS1 Norway",
  "ts": "2025-05-14T18:35:00Z"
}
```

#### Registrere panting (RFID-avlesning fra Keonn)

```http
POST https://api.bifrost.invig.no/v1/assets/{giai}/events
Authorization: Bearer {API_KEY}
Content-Type: application/json

{
  "type": "recycled",
  "epc": "3415AFBC0C00000000000669",
  "reader_id": "advanreader-150-01",
  "ts": "2025-05-14T20:10:00Z"
}
```

#### Hente event-statistikk (for dashboard/storskjerm)

```http
GET https://api.bifrost.invig.no/v1/events/{event_id}/stats
Authorization: Bearer {API_KEY}
```

**Respons:**
```json
{
  "event_id": "gs1-nordic-summit-2025",
  "total_bottles": 300,
  "registered": 187,
  "recycled": 142,
  "recycle_rate": 0.76,
  "top_recyclers": [
    { "name": "Ola Nordmann", "company": "GS1 Norway", "count": 3 }
  ]
}
```

### Implementere Bifrost i V2/index.html

Erstatt `lookupAsset()`-funksjonen:

```js
const BIFROST_API = 'https://api.bifrost.invig.no/v1';
const API_KEY     = 'din-api-nøkkel-her';

async function lookupAsset(giai) {
  const resp = await fetch(`${BIFROST_API}/assets/${giai}`, {
    headers: { Authorization: `Bearer ${API_KEY}` }
  });
  if (!resp.ok) return null;
  return await resp.json();
}

async function registerDrinker(giai, phone, name, company) {
  await fetch(`${BIFROST_API}/assets/${giai}/registrations`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ phone, name, company, ts: new Date().toISOString() })
  });
}
```

### Implementere Bifrost i storskjerm.html

Erstatt `updateUI()` med API-kall:

```js
async function fetchStats() {
  const resp = await fetch(
    `${BIFROST_API}/events/gs1-nordic-summit-2025/stats`,
    { headers: { Authorization: `Bearer ${API_KEY}` } }
  );
  return await resp.json();
}

// I updateUI():
const stats = await fetchStats();
document.getElementById('cnt-registered').textContent = stats.registered;
document.getElementById('cnt-panted').textContent     = stats.recycled;
document.getElementById('cnt-unique').textContent     = stats.total_bottles;
document.getElementById('cnt-rate').textContent       =
  Math.round(stats.recycle_rate * 100) + '%';
```

---

## localStorage-skjema (nåværende implementasjon)

Inntil Bifrost er koblet til, brukes `localStorage` for lokal lagring i nettleseren.

```
gs1ns_users
  └── { [telefon]: { name, company, registeredAt, bottles: [giai, ...] } }

gs1ns_bottle_{giai}
  └── [{ phone, name, company, ts }, ...]

gs1ns_my_phone
  └── "+4790000001"   (husker innlogget bruker)

gs1ns_reader_ip
  └── "192.168.1.100" (Keonn AdvanReader IP)

gs1ns_poll_interval
  └── "3"             (sekunder)
```

**Begrensning:** Data deles ikke mellom enheter. For delt state på tvers av deltakere og enheter må Bifrost API brukes.

---

## RFID-praksis: UHF EPC Gen2 på glassflasker

UHF RFID (865–868 MHz, EPC Gen2) fungerer utmerket på tomme glassflasker. Tomme flasker demper ikke RF-signalet – fravær av væske gir faktisk bedre lesbarhet enn fulle flasker.

| Tilstand | Effekt på RFID | Anbefaling |
|---|---|---|
| Full glassflaske | Moderat demping | Fungerer, kortere rekkevidde |
| Tom glassflaske | Ingen demping | Optimal lesbarhet |
| Aluminiumsboks | Sterk blokkering | Ikke anbefalt for UHF |

**Anbefalt tag-plassering:** Bunn av flasken, unna metallkapselen.  
**Leserekkevidde i beholder:** 0,3–1,0 m med standard antenne.

Se [`RFID-PANT-USERSTORY.md`](RFID-PANT-USERSTORY.md) for fullstendig teknisk dokumentasjon og user stories.

---

## Roadmap

- [x] Bottle identity fra GIAI (300 flasker)
- [x] EPC/GIAI-mapping fra Excel (bottles.json)
- [x] Temperaturvisning og cold-chain reise
- [x] Registreringsskjema med mobilnummer (navn + selskap)
- [x] Gjenkjenning av returnerende brukere (ett klikk)
- [x] Multi-flaske-telling per bruker
- [x] Keonn AdvanReader REST API-integrasjon
- [x] Event-dashboard med leaderboard
- [x] Storskjerm-display (TV/projektor)
- [x] GS1 Digital Link resolver (id.invig.no)
- [ ] Bifrost API-integrasjon (persistent, delt lagring)
- [ ] Sanntids-temperatur fra IoT-sensor via Bifrost
- [ ] WebSocket/SSE for push-oppdatering av storskjerm
- [ ] CORS-proxy for Keonn AdvanReader i produksjon
- [ ] Pant-verifisering mot Infinitum (Norsk Resirk)

---

## Kontakt

**Invig AS**  
[invig.no](https://invig.no) · [sales@invig.no](mailto:sales@invig.no)  
GS1 Nordic Summit 2025 · Powered by Invig Locate IT
