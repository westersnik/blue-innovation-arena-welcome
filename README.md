# Invig Kaffe med GS1 standard – Event Demo System

A live coffee-cup tracking demo built for the **GS1 Nordic Summit 2026**. Each cup carries a unique GS1 GIAI encoded in a QR code. Guests scan the QR code to claim their cup, and a recycling station with a Keonn AdvanReader RFID reader registers the cup when it is returned. A large-screen display shows live recycling statistics in real time.

**Live URLs**

| Page | URL | Purpose |
|---|---|---|
| Cup scan (QR landing page) | `https://gs1-nordic.invig.no/V2/?giai={GIAI}` | Guest experience after scanning QR |
| Event display screen | `https://gs1-nordic.invig.no/storskjerm.html` | TV/projector leaderboard |
| Event configuration | `https://gs1-nordic.invig.no/konfigurasjon.html` | Lokasjon, batch, nummerserie, fremdrift og avslutning |
| Concept explainer | `https://gs1-nordic.invig.no/konsept.html` | S-GTIN / GS1 standard explainer |
| Demo mode | `https://gs1-nordic.invig.no/storskjerm.html?demo=1` | Simulated data for presentations |

**Example — cup #1:**
```
https://gs1-nordic.invig.no/V2/?giai=70735392043
```

**GS1 Digital Link (via Invig resolver):**
```
https://id.invig.no/8004/70735392043
  → https://gs1-nordic.invig.no/V2/?giai=70735392043
```

---

## Repository Structure

```
gs1-nordic-summit/ (gh-pages branch)
├── V2/
│   ├── index.html              # QR landing page – guest cup experience
│   ├── img/                    # Hero image, Invig logo
│   └── data/
│       ├── tracker-09.json     # SmartPallet cache – SR-Tracker-09
│       └── tracker-03.json     # SmartPallet cache – SR-Tracker-03
├── storskjerm.html             # Event display screen (Supabase real-time)
├── konfigurasjon.html           # Åpen konfigurasjon av arrangement og koppsortiment
├── konsept.html                # S-GTIN / GS1 standard concept explainer
├── supabase/
│   └── functions/
│       └── rfid-relay/
│           └── index.ts        # Edge Function – receives RFID POSTs from AdvanReader
├── KEONN-SETUP.md              # Keonn AdvanReader step-by-step configuration guide
├── BACKLOG.md                  # Feature backlog
├── SUPABASE_SCHEMA.sql         # Database schema (run once in Supabase SQL editor)
├── docs/MULTI_EVENT_OPERATIONS.md # Bruk av batcher, arrangementer og gjenbruk
├── generate_cache.py           # Script to regenerate SmartPallet cache files
├── httpServer.py               # Local debug server for testing RFID payloads
├── CNAME                       # GitHub Pages custom domain (gs1-nordic.invig.no)
└── README.md                   # This file
```

---

## System Architecture

```
Guest scans QR code on cup
        │
        ▼
V2/index.html  (GitHub Pages · gs1-nordic.invig.no/V2/)
  ├── Reads GIAI from URL (?giai=70735392043)
  ├── Checks Supabase registrations – shows owner if already claimed
  ├── Registration flow: phone → name / company → Supabase registrations table
  └── "Hvem drakk den?" panel – shows all registrations for this cup

Guest drops cup in recycling bin
        │
        ▼
Keonn AdvanReader (UHF RFID at recycling station)
  └── SimpleHTTPService → HTTPS POST (JSON)
        │
        ▼
Supabase Edge Function: rfid-relay
  https://spbfuhajwfadzvdidalk.supabase.co/functions/v1/rfid-relay
  ├── Parses EPC from AdvanNet JSON payload
  ├── Looks up EPC in `beers` table (2 062 event cups)
  ├── Inserts into rfid_events (idempotent – duplicate EPC → silently ignored)
  └── Unknown EPC → inserts into rfid_feedback as 'invalid'
        │
        ▼
Supabase PostgreSQL database
  ├── rfid_events      – one row per recycled cup (UNIQUE on epc)
  ├── registrations    – one row per guest/cup claim
  ├── rfid_feedback    – invalid or duplicate tag events
  └── beers            – 2 062 event cups (giai, epc, url, bottle_num)
        │  Realtime WebSocket (supabase-js)
        ▼
storskjerm.html  (Event display screen)
  ├── Live counters: Registered users · Registered cups · Recycled cups · Recycle rate
  ├── Feed: last 5 recycled cups with guest name
  └── Popups: green (recycled) · red (unknown tag) · gold milestone with confetti
```

> **Why a Supabase Edge Function?** `gs1-nordic.invig.no` is a static GitHub Pages site — it cannot receive POST requests. The Edge Function runs server-side, performs the EPC lookup, and writes to the database using the service role key (which bypasses RLS safely). The function requires no JWT — `verify_jwt = false` is set in `supabase/config.toml`.

---

## GS1 Identity Structure

Each cup has a unique **GIAI (Global Individual Asset Identifier)** per the GS1 standard.

| Field | Value | Description |
|---|---|---|
| GS1 Application Identifier | `8004` | Identifies GIAI in GS1 Digital Link |
| GS1 Company Prefix (GCP) | `7073539` | Invig AS GCP (7 digits) |
| Asset reference range | `2043`–`4104` | 2 062 unique cups |
| Full GIAI (example) | `70735392043` | GCP + asset reference |
| GS1 element string | `(8004) 70735392043` | Standard GS1 notation |
| Resolver URL | `https://id.invig.no/8004/70735392043` | GS1 Digital Link |

**EPC encoding for RFID (GS1 GIAI-96, GS1 TDS 1.13 Table 14-3):**

| Bit field | Bits | Value | Notes |
|---|---|---|---|
| Header | 8 | `0x34` | GIAI-96 (not `0x30` which is SGTIN-96) |
| Filter | 3 | `1` | |
| Partition | 3 | `5` | 7-digit GCP |
| GCP | 24 | `0xAFBC0C` | = 7073539 decimal |
| Asset Reference | 58 | cup number | = GIAI − 70735390000 |

The `beers` table stores the pre-computed EPC for each cup, so the Edge Function does a direct table lookup rather than mathematical decoding.

---

## Supabase Database

**Project:** `spbfuhajwfadzvdidalk` · Region: `eu-central-1`
**Dashboard:** https://supabase.com/dashboard/project/spbfuhajwfadzvdidalk

### Tables

**`beers`** — event cup registry (2 062 rows, populated from Excel before the event)

| Column | Type | Description |
|---|---|---|
| `id` | bigserial | Primary key |
| `giai` | text | Full GIAI string, e.g. `70735392043` |
| `epc` | text | Uppercase hex EPC, e.g. `3415AFBC0C000000000007EB` |
| `url` | text | QR landing page URL |
| `bottle_num` | int | Cup number 1–2062 (UNIQUE) |

**`registrations`** — QR scan registrations from guests

| Column | Type | Description |
|---|---|---|
| `id` | bigserial | Primary key |
| `phone` | text | Guest phone number |
| `name` | text | Guest full name |
| `company` | text | Guest company / organisation |
| `giai` | text | Cup GIAI claimed |
| `registered_at` | timestamptz | UTC timestamp |

Unique index on `(phone, giai)` — one registration per phone/cup pair.

**`rfid_events`** — recycling events from the RFID reader

| Column | Type | Description |
|---|---|---|
| `id` | bigserial | Primary key |
| `epc` | text | Raw EPC from reader (UNIQUE — idempotency) |
| `giai` | text | Decoded GIAI |
| `reader_id` | text | Reader identifier string |
| `recycled_at` | timestamptz | UTC timestamp |

**`rfid_feedback`** — invalid or unrecognised tag events

| Column | Type | Description |
|---|---|---|
| `id` | bigserial | Primary key |
| `epc` | text | Raw EPC |
| `giai` | text | null for invalid tags |
| `event_type` | text | `'invalid'` or `'duplicate'` |
| `created_at` | timestamptz | UTC timestamp |

**RLS:** All tables have RLS enabled. `registrations` and `rfid_events` allow anonymous SELECT and INSERT. The Edge Function uses the service role key, which bypasses RLS entirely.

**Realtime:** `rfid_events`, `registrations`, and `rfid_feedback` have `REPLICA IDENTITY FULL` and are added to the `supabase_realtime` publication. `storskjerm.html` subscribes to INSERT events on all three.

---

## Keonn AdvanReader Setup

See **[KEONN-SETUP.md](./KEONN-SETUP.md)** for the complete step-by-step guide. The summary below covers the essential configuration.

### What the reader does

The AdvanReader continuously scans for UHF RFID tags (EPC Gen2, 865–868 MHz). When a cup is placed in the recycling bin, the reader detects the tag and uses its built-in **SimpleHTTPService** to POST the EPC to the Supabase Edge Function over HTTPS.

### Step 1 — Open AdvanNet Manager

1. Connect the AdvanReader to the event network (wired or Wi-Fi).
2. Navigate to `http://<reader-ip>:8080` in a browser (default AdvanNet Manager port).
3. Log in with your AdvanNet credentials.
4. In the left sidebar, go to **Services** → **SimpleHTTPService**.
5. Enable **Advanced** mode (toggle in the top-right of the Services panel).

### Step 2 — HTTP Connection Settings

| Field | Value |
|---|---|
| **Enabled** | ✅ Checked |
| **Endpoint URL** | `https://spbfuhajwfadzvdidalk.supabase.co/functions/v1/rfid-relay` |
| **HTTP method** | `POST` |
| **Content-Type** | `JSON (application/json)` |
| **Username** | *(leave empty — no Basic Auth)* |
| **Password** | *(leave empty — no Basic Auth)* |

### Step 3 — HTTP Advanced Settings

| Field | Value |
|---|---|
| **Send one by one** | ☐ Unchecked (batch mode) |
| **Inventory tag TTL (s)** | `60` |
| **Re-send when in error** | ✅ Checked |
| **Expected HTTP response** | `200` |

The TTL of 60 seconds means the same EPC will only be posted once per minute. The Edge Function also enforces idempotency at the database level — a duplicate EPC is silently ignored (unique constraint on `rfid_events.epc`).

### Step 4 — JSON Config

Paste the following into the **JSON config** field. This template builds the correct JSON body from the AdvanNet scripting context variables:

```
[{"event":"TAG_READ","path":"'/functions/v1/rfid-relay'","body":"var body='{';body+='\"devid\": \"'+ctx_devid+'\",';body+='\"devip\": \"'+ctx_devip+'\",';body+='\"reads\": [';for(i=0;i<ctx_tags.length;i++){body+='{';body+='\"epc\": \"'+ctx_tags[i].getEPC()+'\",';body+='\"rssi\": \"'+ctx_tags[i].getRSSI()+'\",';body+='\"ts\": \"'+ctx_tags[i].getUTC()+'\"';body+='}';if(i<ctx_tags.length-1){body+=',';}}body+=']';body+='}';"  }]
```

> Validate the JSON at [jsonlint.com](https://jsonlint.com/) before saving (remove any line breaks first).

### Step 5 — Custom Header (recommended)

Add the event key header for an extra layer of security. Paste into the **Advanced JSON conf** field:

```json
{"customHeaders":[{"header":"X-Event-Key: gs1nordic2026"}]}
```

### Step 6 — Test the Connection

After saving, verify the pipeline with `curl` from any machine on the network:

```bash
# Single EPC test (cup #1)
curl -s -X POST \
  "https://spbfuhajwfadzvdidalk.supabase.co/functions/v1/rfid-relay" \
  -H "Content-Type: application/json" \
  -H "X-Event-Key: gs1nordic2026" \
  -d '{"epc":"3415AFBC0C000000000007EB","reader_id":"advanreader-test"}'
```

**Expected response — first scan:**
```json
{
  "success": true,
  "processed": 1,
  "recorded": 1,
  "duplicates": 0,
  "skipped": 0,
  "results": [{ "epc": "3415AFBC0C000000000007EB", "giai": "70735392043", "bottle_num": 1, "status": "recorded" }]
}
```

**Expected response — duplicate (same EPC again):**
```json
{
  "success": true,
  "processed": 1,
  "recorded": 0,
  "duplicates": 1,
  "skipped": 0,
  "results": [{ "epc": "3415AFBC0C000000000007EB", "giai": "70735392043", "bottle_num": 1, "status": "duplicate" }]
}
```

**Expected response — unknown tag (not in `beers` table):**
```json
{
  "success": true,
  "processed": 1,
  "recorded": 0,
  "duplicates": 0,
  "skipped": 1,
  "results": [{ "epc": "AABBCCDD00112233", "giai": null, "bottle_num": null, "status": "skipped (not an event bottle)" }]
}
```

### Supported Payload Formats

The Edge Function accepts several JSON body shapes from the AdvanReader:

| Format | Example body |
|---|---|
| Single EPC | `{"epc":"3415AFBC0C000000000007EB"}` |
| AdvanNet batch | `{"devid":"reader-01","reads":[{"epc":"...","rssi":"-60","ts":"..."}]}` |
| Tag array | `{"tags":[{"epc":"..."}]}` |
| EPC list | `{"epc_list":["..."]}` |

### Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| No POST received by Edge Function | SimpleHTTPService not enabled | Enable in AdvanNet Manager → Services |
| `401 Unauthorized` | Wrong `X-Event-Key` header | Use `gs1nordic2026` |
| `400 Bad Request` | Malformed JSON config | Validate at jsonlint.com |
| All tags return `skipped (not an event bottle)` | EPC not in `beers` table | Verify cups are programmed with the correct GIAI range; check EPC header is `0x34` (GIAI-96), not `0x30` (SGTIN-96) |
| `duplicate` for all tags | EPC already in `rfid_events` | Expected and correct — clean the table to re-test: `DELETE FROM rfid_events;` |
| Display screen not updating | Supabase Realtime not connected | Check browser console for WebSocket errors; reload `storskjerm.html` |
| HTTPS certificate error on reader | Network/DNS issue | Verify the reader has internet access and can resolve `supabase.co` |
| Tags read but not posted | TTL not expired | Lower TTL to `5` for testing, restore to `60` for the event |

---

## Event Display Screen (storskjerm.html)

Open `https://gs1-nordic.invig.no/storskjerm.html` on the event display monitor (TV or projector).

The screen connects to Supabase Realtime via WebSocket on page load and shows:

- **Registrerte brukere** — number of unique phone numbers in `registrations`
- **Registrerte kopper** — number of unique GIAIs claimed
- **Resirkulerte kopper** — number of rows in `rfid_events`
- **Resirkuleringsrate** — recycled / registered (%)
- **Feed** — last 5 recycled cups with guest name and company
- **Popups** — green toast when a registered cup is recycled, red toast for unknown tags, gold milestone popup with confetti at 10 / 50 / 100 / 200 / 300 cups

**Demo mode:** Add `?demo=1` to the URL to run a simulated sequence without a live reader. Without this parameter, the screen waits for real Supabase data indefinitely.

---

## Cup Scan Page (V2/index.html)

The guest-facing QR landing page at `https://gs1-nordic.invig.no/V2/?giai={GIAI}` provides:

| Panel | Content |
|---|---|
| **Hero** | Cup number, GIAI, GS1 Digital Link badge |
| **Hvem drakk den?** | Registered guests for this cup; live count of registered / recycled cups from Supabase |
| **Registrer meg** | Phone → name / company flow; saves to `registrations` via Supabase anon key |
| **Claimed banner** | Shown if cup is already registered — displays owner name and company |

If a cup is already claimed, the registration button is hidden and the owner's name is shown. Each cup can only be claimed once (enforced by a unique constraint in Supabase, not just localStorage).

---

## Deployment

The site is deployed via **GitHub Pages** from the `gh-pages` branch with a custom domain.

- Custom domain: `gs1-nordic.invig.no` (configured in `CNAME`)
- All pages are static HTML/CSS/JS — no build step required
- The Supabase Edge Function (`rfid-relay`) is deployed separately via the Supabase CLI

**To deploy changes to the site:**

```bash
git add .
git commit -m "describe your change"
git push origin gh-pages
```

GitHub Pages CDN propagates within approximately 60 seconds. Hard-refresh (`Ctrl+Shift+R`) to bypass browser cache.

**To redeploy the Edge Function:**

```bash
cd gs1-nordic-summit
supabase login   # use your Supabase Personal Access Token (https://supabase.com/dashboard/account/tokens)
supabase link --project-ref spbfuhajwfadzvdidalk
supabase functions deploy rfid-relay --no-verify-jwt
```

---

## Local Development and Testing

**Test RFID payloads locally** (inspect what the reader is sending):

```bash
python3 httpServer.py   # starts on port 8080
# Configure AdvanReader to POST to http://<your-machine-ip>:8080
# All incoming requests are printed to stdout
```

**Regenerate SmartPallet cache files** (if iotpallet.no data needs refreshing):

```bash
python3 generate_cache.py
git add V2/data/
git commit -m "refresh SmartPallet cache"
git push origin gh-pages
```

**Clean the database for a fresh test run:**

```sql
-- Run in Supabase SQL editor
DELETE FROM rfid_events;
DELETE FROM registrations;
DELETE FROM rfid_feedback;
```

---

## Technology Stack

| Layer | Technology |
|---|---|
| Frontend | Vanilla HTML / CSS / JS |
| Real-time | Supabase JS client (WebSocket subscriptions) |
| Database | Supabase (PostgreSQL) · project `spbfuhajwfadzvdidalk` |
| Edge Function | Supabase Edge Functions (Deno) · `rfid-relay` |
| RFID reader | Keonn AdvanReader (UHF EPC Gen2, 865–868 MHz) |
| Sensor data | iotpallet.no API · SR-Tracker-09 · SR-Tracker-03 |
| Hosting | GitHub Pages · custom domain `gs1-nordic.invig.no` |
| GS1 identity | GIAI (AI 8004) · GS1 Digital Link resolver `id.invig.no` |
| Design | Invig brand palette · Figtree + Gelasio fonts |

---

## RFID on Paper Cups

UHF RFID (865–868 MHz, EPC Gen2) works well on paper cups. The cups used in this demo have a small UHF label applied to the outside of the cup.

| Condition | RFID effect |
|---|---|
| Paper cup, dry | Excellent readability |
| Paper cup, with liquid | Some attenuation — still readable at close range |
| Metal-lined cup | Strong blocking — not suitable for UHF |

Recommended read range at the recycling bin: 0.1–0.5 m with a standard patch antenna.

---

## Backlog

See **[BACKLOG.md](./BACKLOG.md)** for planned features, including a configurable progress bar showing recycling progress towards a target cup count.

---

## Contact

**Invig AS** · [invig.no](https://invig.no) · [sales@invig.no](mailto:sales@invig.no)

GS1 Nordic Summit 2026 · Powered by Invig Locate IT
