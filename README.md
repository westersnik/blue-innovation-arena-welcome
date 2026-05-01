# GS1 Nordic Summit 2025 — Digital Product Passport Demo

A live beer-bottle tracking demo built for the **GS1 Nordic Summit 2025** at Radisson Blu Plaza Hotel, Oslo. Each Carlsberg bottle carries a GS1 GIAI encoded in a QR code. Guests scan the QR code to see the bottle's full cold-chain journey, register their name, and watch a live recycling leaderboard on the event display screen.

**Live URLs**

| Page | URL | Purpose |
|---|---|---|
| Bottle scan (QR landing page) | https://gs1-nordic.invig.no/V2/?giai={GIAI} | Guest experience after scanning QR |
| Event display screen | https://gs1-nordic.invig.no/storskjerm.html | TV/projector leaderboard |
| Dashboard | https://gs1-nordic.invig.no/dashboard.html | Admin stats overview |
| Animation test | https://gs1-nordic.invig.no/test.html | Confetti/animation test |

**Example — bottle #1:**
```
https://gs1-nordic.invig.no/V2/?giai=70735391141
```

**GS1 Digital Link redirect (via Invig resolver):**
```
https://id.invig.no/8004/70735391141
  → https://gs1-nordic.invig.no/V2/?giai=70735391141
```

---

## Repository Structure

```
gs1-nordic-summit/ (gh-pages branch)
├── V2/
│   ├── index.html          # QR landing page (main guest experience)
│   └── data/
│       ├── tracker-09.json # SmartPallet cache – odd bottles (SR-Tracker-09)
│       └── tracker-03.json # SmartPallet cache – even bottles (SR-Tracker-03)
├── storskjerm.html         # Event display screen (Supabase real-time)
├── dashboard.html          # Admin/stats dashboard
├── test.html               # Animation/confetti test
├── generate_cache.py       # Script to regenerate SmartPallet cache files
├── KEONN-SETUP.md          # Keonn AdvanReader configuration guide
├── RFID-PANT-USERSTORY.md  # User stories and RFID background
├── httpServer.py           # Local debug server for RFID testing
├── CNAME                   # GitHub Pages custom domain (gs1-nordic.invig.no)
└── README.md               # This file
```

---

## Architecture Overview

```
Guest scans QR code on bottle
        │
        ▼
V2/index.html  (GitHub Pages / gs1-nordic.invig.no)
  ├── Reads GIAI from URL (?giai=70735391141)
  ├── Fetches cold-chain telemetry from SmartPallet cache (V2/data/)
  ├── Renders Leaflet map + temperature chart (Chart.js)
  ├── Registers guest via Supabase (registrations table)
  └── Shows other registered drinkers (Supabase query)

Keonn AdvanReader (RFID at recycling station)
  └── POST /api/rfid → gs1-nordic.invig.no (Manus backend)
        └── Writes to Supabase rfid_events table

storskjerm.html  (Event display screen)
  ├── Subscribes to Supabase rfid_events (real-time INSERT via WebSocket)
  ├── Subscribes to Supabase registrations (real-time INSERT)
  └── Shows live recycling counter + milestone celebrations (confetti)
```

---

## GS1 GIAI Identity Structure

Each bottle has a unique **GIAI (Global Individual Asset Identifier)** per the GS1 standard.

| Field | Value | Description |
|---|---|---|
| GS1 Application Identifier | `8004` | Identifies GIAI in GS1 Digital Link |
| GS1 Company Prefix (GCP) | `7073539` | Invig AS GCP |
| Asset reference | `1001`–`3000` | Unique bottle number (2000 bottles) |
| Full GIAI (example) | `70735391141` | GCP + asset reference |
| GS1 element string | `(8004) 70735391141` | Standard GS1 notation |
| Resolver URL | `https://id.invig.no/8004/70735391141` | GS1 Digital Link |

**EPC encoding for RFID (GS1 GIAI-96):**
```
Header    (8 bit):  34 hex  → GIAI-96
Filter    (3 bit):  1
Partition (3 bit):  5
GCP      (24 bit):  7073539 → 0xAFBC0C
Asset    (38 bit):  bottle number
```

---

## Supabase Database Schema

### `registrations` table

| Column | Type | Description |
|---|---|---|
| `id` | uuid | Primary key |
| `phone` | text | Guest phone number |
| `name` | text | Guest full name |
| `company` | text | Guest company/organisation |
| `giai` | text | Bottle GIAI scanned |
| `registered_at` | timestamptz | Registration timestamp (UTC) |

### `rfid_events` table

| Column | Type | Description |
|---|---|---|
| `id` | uuid | Primary key |
| `epc` | text | Raw EPC from RFID reader |
| `giai` | text | Decoded GIAI |
| `reader_id` | text | Keonn reader identifier |
| `recycled_at` | timestamptz | Scan timestamp (UTC) |

---

## SmartPallet Cold-Chain Data

The map and temperature log in V2 use a **cache-first** strategy:

1. The page fetches `V2/data/tracker-09.json` (odd bottles) or `tracker-03.json` (even bottles) immediately for instant render.
2. It then attempts the live SmartPallet API in the background. If the API responds, it overwrites the cache data.
3. If the live API is unavailable (404 or timeout), the cached data is used.

The cache files contain a realistic fictive cold-chain journey ending at Radisson Blu Plaza, Oslo:

| Date | Location | Temperature |
|---|---|---|
| 7 May | Carlsberg Brewery, Fredericia DK | 18.5°C |
| 8 May | Cold Storage, Kastrup Airport DK | 3.9°C |
| 9 May | Göteborg Distribution Hub, SE | 5.2°C |
| 10 May | Fredrikstad Cold Terminal, NO | 4.3°C |
| 11 May | Oslo Distribution Centre, Alnabru | 3.8°C |
| 13 May | Refrigerated Transport, Oslo | 5.9°C |
| 13–14 May | Venue Cold Room, Radisson Blu Plaza | 4.1°C |
| 14 May | Handed to guest | 5.7°C |

**Regenerating cache files before the event:**

```bash
python3 generate_cache.py
git add V2/data/
git commit -m "refresh SmartPallet cache for event day"
git push origin gh-pages
```

---

## Keonn AdvanReader Setup

See **[KEONN-SETUP.md](./KEONN-SETUP.md)** for the full step-by-step configuration guide.

**Quick summary:**

1. Open AdvanNet web interface → `HTTPService` → `Add Connection`
2. Set URL to: `https://gs1-nordic.invig.no/api/rfid`
3. Set method: `POST`, content type: `application/json`
4. Save and test with:

```bash
curl -X POST https://gs1-nordic.invig.no/api/rfid \
  -H "Content-Type: application/json" \
  -d '{"epc":"3074257BF400B000000006A9","reader_id":"keonn-01","timestamp":"2025-05-14T12:00:00Z"}'
```

The backend decodes the EPC to a GIAI and writes it to the `rfid_events` Supabase table. The `storskjerm.html` display screen picks this up in real-time via Supabase WebSocket subscription.

---

## Event Display Screen (storskjerm.html)

Open `https://gs1-nordic.invig.no/storskjerm.html` on the event display monitor.

- Connects to Supabase real-time via WebSocket on page load
- Updates the recycled bottle counter live as RFID reads arrive
- Shows a feed of the last 10 recycled bottles with guest names (looked up from `registrations`)
- Triggers confetti celebrations at milestones: **10, 50, 100, 200, 300** bottles
- Falls back to demo mode after 5 seconds if Supabase is unreachable

---

## V2 Landing Page Features

The guest-facing QR landing page (`V2/index.html`) provides:

| Panel | Content |
|---|---|
| **Temperature badge** | Current bottle temperature from SmartPallet cache |
| **See the Journey** | Interactive Leaflet map of the full cold-chain route + timestamped steps |
| **Temperature Log** | Chart.js line chart of temperature history + data table |
| **Who Drank It?** | Other guests who scanned this bottle (from Supabase) |
| **About the Product** | GS1 product data: GTIN, GIAI, batch, production/best-before dates |
| **Registration flow** | Phone number → name/company → saved to Supabase |

The page works **without a GIAI in the URL** (demo mode) — it shows the full journey and temperature log using the SR-Tracker-09 demo data.

---

## Deployment

The site is deployed via **GitHub Pages** from the `gh-pages` branch with a custom domain.

- Custom domain: `gs1-nordic.invig.no` (configured in `CNAME`)
- The Manus backend app at `gs1-nordic.invig.no` handles all `/api/*` routes
- Static files (HTML, JS, CSS, data) are served by GitHub Pages CDN

**To deploy changes:**

```bash
git add .
git commit -m "your message"
git push origin gh-pages
```

GitHub Pages CDN propagates within approximately 60 seconds.

---

## Local Development

**Regenerate SmartPallet cache:**
```bash
python3 generate_cache.py
```

**Test RFID endpoint locally:**
```bash
python3 httpServer.py   # starts on port 8080
# Then configure Keonn to POST to http://<your-ip>:8080
```

---

## Technology Stack

| Layer | Technology |
|---|---|
| Frontend | Vanilla HTML/CSS/JS, Leaflet.js, Chart.js |
| Maps | Leaflet + OpenStreetMap (no API key required) |
| Real-time | Supabase JS client (WebSocket subscriptions) |
| Backend API | Node.js + Express + tRPC (Manus app) |
| Database | Supabase (PostgreSQL) |
| RFID | Keonn AdvanReader → POST /api/rfid |
| Hosting | GitHub Pages + Manus (custom domain `gs1-nordic.invig.no`) |
| Cold-chain data | SmartPallet Bifrost API (with cache fallback) |
| GS1 identity | GIAI (AI 8004), GS1 Digital Link |

---

## RFID on Glass Bottles

UHF RFID (865–868 MHz, EPC Gen2) works well on empty glass bottles. Empty bottles do not attenuate the RF signal — the absence of liquid actually improves readability compared to full bottles.

| Condition | RFID effect | Recommendation |
|---|---|---|
| Full glass bottle | Moderate attenuation | Works, shorter range |
| Empty glass bottle | No attenuation | Optimal readability |
| Aluminium can | Strong blocking | Not recommended for UHF |

**Recommended tag placement:** Bottom of bottle, away from the metal cap.  
**Read range in recycling bin:** 0.3–1.0 m with standard antenna.

See [RFID-PANT-USERSTORY.md](./RFID-PANT-USERSTORY.md) for full technical documentation and user stories.

---

## Roadmap

- [x] Bottle identity from GIAI (2000 bottles)
- [x] Temperature display and cold-chain journey (SmartPallet cache)
- [x] Registration form with phone number (name + company)
- [x] Returning user recognition (one-click re-register)
- [x] Multi-bottle counting per user
- [x] Keonn AdvanReader RFID integration (POST /api/rfid)
- [x] Supabase real-time for storskjerm.html
- [x] Supabase registration from V2/index.html
- [x] Event display screen with milestone celebrations
- [x] GS1 Digital Link resolver (id.invig.no)
- [x] Custom domain (gs1-nordic.invig.no)
- [x] Full English translation
- [ ] Live SmartPallet API integration (when available)
- [ ] CORS proxy for Keonn AdvanReader in production
- [ ] Recycling verification against Infinitum (Norsk Resirk)

---

## Contact

**Invig AS**  
[invig.no](https://invig.no) · [sales@invig.no](mailto:sales@invig.no)  
GS1 Nordic Summit 2025 · Powered by Invig Locate IT
