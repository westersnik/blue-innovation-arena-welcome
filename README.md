# GS1 Nordic Summit 2025 – Carlsberg Beer Tracker

A mobile-first event landing page served when a delegate scans the unique QR code on their Carlsberg beer bottle at GS1 Nordic Summit. Built on the **Invig Locate IT** platform using GS1 GIAI for per-bottle identity.

Live: [westersnik.github.io/gs1-nordic-summit/](https://westersnik.github.io/gs1-nordic-summit/)

---

## Concept

400 Carlsberg Pilsner bottles are distributed at the event. Each bottle carries a unique QR code encoding a GS1 Digital Link URL. When a delegate scans their bottle, they land on a personalised page showing:

- Which bottle number they received (1–400)
- The current temperature of the bottle
- The full cold-chain journey from brewery to glass
- A temperature log with readings at each checkpoint
- A list of registered drinkers for that bottle
- A registration form to add themselves as a drinker
- Full product information and GS1 identity details

---

## GIAI identity

Each bottle is assigned a **GIAI (Global Individual Asset Identifier)** using the Invig GCP prefix.

| Field | Value |
|---|---|
| Invig GCP prefix | `7073539` |
| GIAI range | `70735390001` – `70735390400` |
| Bottle #1 | GIAI `70735390001` |
| Bottle #400 | GIAI `70735390400` |
| GS1 Application Identifier | `(8004)` |

### QR code URL format

Each QR code encodes a GS1 Digital Link URL via the Invig resolver:

```
https://id.invig.no/8004/70735390001   ← Bottle #1
https://id.invig.no/8004/70735390042   ← Bottle #42
https://id.invig.no/8004/70735390400   ← Bottle #400
```

The resolver redirects to this landing page with the GIAI as a query parameter:

```
https://westersnik.github.io/gs1-nordic-summit/?giai=70735390042
```

---

## Features

| Feature | Description |
|---|---|
| **Bottle identity** | Displays bottle number (1–400) derived from GIAI |
| **Live temperature** | Current temperature with colour-coded status (optimal 3–6 °C) |
| **Cold-chain journey** | Step-by-step journey from Carlsberg brewery to the delegate's hand |
| **Temperature log** | Full log of readings at each supply chain checkpoint |
| **Drinker registry** | List of people who registered themselves for this bottle |
| **Registration form** | Name, company and role – adds delegate to the bottle's drinker list |
| **Event progress** | Shows how many of the 400 bottles have been scanned at the event |
| **Product info** | GTIN, batch, production date, ABV, serving temperature |
| **GIAI identity box** | Full GS1 Digital Link breakdown: prefix, reference, AI, resolver URL |

---

## Demo URLs

Test the page with these example GIAIs:

| URL | Bottle |
|---|---|
| `?giai=70735390001` | Bottle #1 |
| `?giai=70735390042` | Bottle #42 |
| `?giai=70735390100` | Bottle #100 |
| `?giai=70735390250` | Bottle #250 |
| `?giai=70735390400` | Bottle #400 |

Without a `?giai=` parameter, the page shows a generic branded view.

---

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | Vanilla HTML/CSS/JS – no build step |
| Fonts | Space Grotesk (Google Fonts) |
| Hosting | GitHub Pages (`gh-pages` branch) |
| Tag identity | GS1 GIAI (AI `8004`) |
| Resolver | `id.invig.no` – GS1 Digital Link |
| Data | Deterministic mock data (seeded by bottle number) |
| Images | AI-generated hero, temperature chart, journey map |

---

## Repository structure

```
gh-pages branch
├── index.html        # Self-contained event landing page
├── img/
│   ├── hero-bottle.jpg     # Carlsberg bottle hero image
│   ├── temp-chart.jpg      # Temperature curve visualisation
│   ├── journey-map.jpg     # Cold-chain journey map
│   └── gs1-event-bg.jpg    # Abstract event background
└── README.md
```

---

## Roadmap

- [x] Bottle identity from GIAI (1–400)
- [x] Temperature display with optimal range indicator
- [x] Cold-chain journey visualisation
- [x] Temperature log table
- [x] Drinker registry with event progress bar
- [x] Registration form (local state)
- [x] Product information panel
- [x] GS1 Digital Link identity box
- [ ] Connect registration to live backend (persist drinker data)
- [ ] Real-time temperature from IoT sensor via Bifrost API
- [ ] Live event leaderboard (most bottles scanned per person)
- [ ] Share bottle card to LinkedIn / social media

---

## Contact

**Invig AS** · [invig.no](https://invig.no) · [sales@invig.no](mailto:sales@invig.no)  
**GS1 Norway** · [gs1.no](https://gs1.no)
