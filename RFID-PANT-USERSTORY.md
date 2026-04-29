# RFID-basert Pant-system – GS1 Nordic Summit 2025
## User Stories & Teknisk Praksis

**Prosjekt:** GS1 Nordic Summit – Carlsberg Bottle Tracker  
**Utarbeidet av:** Invig AS  
**Dato:** April 2025  

---

## Bakgrunn

På GS1 Nordic Summit 2025 demonstreres GS1 Digital Link i praksis ved å utstyre 300 Carlsberg-flasker med unike RFID-tagger og QR-koder. Hver flaske har en unik GIAI (Global Individual Asset Identifier) kodet i GS1-format, og kan spores fra bryggeri til pant. Demonstrasjonen viser verdikjeden for sporbarhet, sirkulærøkonomi og integrasjon med eksisterende systemer.

---

## User Stories

### Epic: Registrering og sporing av øl-flaske

---

### US-01 – Registrere seg som drikker

**Som** en deltaker på GS1 Nordic Summit  
**Ønsker jeg** å skanne QR-koden på min Carlsberg-flaske med mobiltelefonen  
**Slik at** jeg kan registrere meg som drikker og se flaskens reise fra bryggeri til event

**Akseptansekriterier:**
- Siden åpner umiddelbart etter skanning uten app-installasjon
- Første gang: bruker oppgir mobilnummer → navn, selskap og rolle
- Andre gang (ny flaske): mobilnummer gjenkjennes → ett klikk legger til ny flaske
- Antall registrerte flasker per bruker vises i sanntid
- Siden viser temperaturlogg, reise og produktinfo for akkurat denne flasken

**Teknisk mapping:**  
`QR → https://id.invig.no/8004/{GIAI} → dashboard V2 med ?giai={GIAI}`

---

### US-02 – Kaste tom flaske i pant-beholder

**Som** en deltaker som er ferdig med sin Carlsberg  
**Ønsker jeg** å kaste den tomme flasken i en merket pant-beholder på eventet  
**Slik at** flasken registreres som pantet og mitt navn vises på leaderboardet

**Akseptansekriterier:**
- Beholderen er tydelig merket med "Pant her – RFID-registrering"
- Flasken kastes i beholderen – ingen handling kreves av brukeren
- Keonn AdvanReader inne i beholderen leser RFID-taggen automatisk
- Innen 5 sekunder vises flasken som "pantet" på leaderboard-skjermen
- Brukerens navn og antall pantede flasker oppdateres på storskjerm

**Teknisk mapping:**  
`Tom flaske → RFID-leser i beholder → EPC → GIAI → bruker-oppslag → leaderboard`

---

### US-03 – Se leaderboard på storskjerm

**Som** en arrangør eller deltaker  
**Ønsker jeg** å se en live-oppdatert leaderboard på storskjermen i lokalet  
**Slik at** det skapes engasjement og konkurranse om hvem som panter flest flasker

**Akseptansekriterier:**
- Leaderboard viser: rangering, navn, selskap, antall flasker, antall pantet
- Oppdateres automatisk uten sideopplasting (polling hvert 3. sekund)
- Viser fire nøkkeltall: registrerte drikkere, pantede flasker, unike flasker, pant-rate
- Nylig pantede flasker vises i en "live feed" med navn og tidsstempel
- Siden fungerer på alle skjermstørrelser (mobil, nettbrett, storskjerm)

---

### US-04 – Arrangør konfigurerer RFID-leser

**Som** en teknisk arrangør  
**Ønsker jeg** å koble leaderboard-dashboardet til Keonn AdvanReader via IP-adresse  
**Slik at** RFID-avlesninger fra pant-beholderen vises i sanntid på dashboardet

**Akseptansekriterier:**
- Konfigurasjonspanel i dashboardet lar arrangør skrive inn IP-adresse til AdvanReader
- Systemet prøver automatisk kjente Keonn REST-endepunkter
- Polling-intervall kan justeres (standard: 3 sekunder)
- Tilkoblingsstatus vises tydelig (live / ikke tilkoblet / demo-modus)
- Demo-modus simulerer RFID-avlesninger for testing uten fysisk leser

---

## Teknisk Praksis: RFID på Glassflasker

### Hvorfor UHF EPC Gen2 fungerer på tomme glassflasker

Et vanlig spørsmål ved RFID-implementasjon på drikkevarer er om væske i flasken påvirker lesbarhet. Svaret er todelt og avhenger av fyllingsgrad:

| Tilstand | Effekt på UHF RFID | Forklaring |
|---|---|---|
| Full glassflaske (vann/øl) | Moderat demping | Væske absorberer RF-energi ved 865–868 MHz |
| Tom glassflaske | **Ingen demping** | Glass er RF-transparent; luft demper ikke |
| Tom aluminiumsboks | Sterk demping | Metall reflekterer og blokkerer signal |

**Konklusjon:** Tomme glassflasker er ideelle for RFID-avlesning. Når flasken kastes tom i beholderen, er signalkvaliteten faktisk bedre enn da flasken var full.

### Tag-plassering – anbefalt praksis

For Carlsberg 330 ml glassflaske anbefales følgende tag-plassering:

1. **Bunn av flasken** (foretrukket): Maksimal avstand fra metallkapselen, god RF-eksponering mot leseren i bunnen av beholderen.
2. **Side av flasken** (alternativ): Fungerer godt, men krever at leseren er plassert på siden av beholderen.
3. **Unngå:** Metallkapselen øverst og etikettens metallfolie (hvis aktuelt).

### Keonn AdvanReader – integrasjon

Keonn AdvanReader bruker **AdvanNet** som firmware-plattform, som eksponerer et REST API for integrasjon:

```
GET http://{reader-ip}/rest/session/tags
Accept: application/json

Response:
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

Dashboardet poller dette endepunktet hvert 3. sekund, mapper EPC til GIAI via `bottles.json`, slår opp registrert bruker i `localStorage`, og oppdaterer leaderboardet.

**EPC-struktur for GS1 GIAI (GS1-96 bit encoding):**

```
Header (8 bit): 34 (hex) = SGTIN-96 / GIAI-96
Filter (3 bit): 1
Partition (3 bit): 5
GCP (24 bit): 7073539 → 0xAFBC0C
Asset ref (38 bit): flaske-nummer
```

### Systemarkitektur

```
[Carlsberg-flaske]
    │
    ├── QR-kode → https://id.invig.no/8004/{GIAI}
    │       └── GS1 Digital Link resolver → V2/index.html?giai={GIAI}
    │               └── Bruker registrerer seg med mobilnummer
    │                       └── Lagres i localStorage (gs1ns_users)
    │
    └── RFID-tag (EPC Gen2 UHF)
            └── Flaske kastes i pant-beholder
                    └── Keonn AdvanReader leser EPC
                            └── REST API → dashboard.html
                                    └── EPC → GIAI → bruker → leaderboard
```

### Viktige tekniske hensyn

**Leserekkevidde i beholder:** Keonn AdvanReader med standard antenne leser typisk 0,3–1,0 m. For en pant-beholder anbefales antennen plassert i bunnen eller siden, med leseavstand ≤ 50 cm for pålitelig avlesning.

**Duplikat-håndtering:** Samme EPC kan leses mange ganger. Dashboardet bruker en `Set` for å sikre at hver EPC kun telles én gang som pantet.

**Offline-modus:** Dersom AdvanReader ikke er tilgjengelig, kan dashboardet kjøres i demo-modus som simulerer RFID-avlesninger. Dette er nyttig for presentasjoner og testing.

**CORS-begrensning:** Keonn AdvanReader returnerer ikke CORS-headere som standard. For produksjon anbefales en enkel proxy-server (f.eks. Node.js eller nginx) som videresender API-kall og legger til `Access-Control-Allow-Origin: *`.

---

## Dataflyt – sekvensdiagram

```
Deltaker          QR-kode         id.invig.no      V2/index.html    localStorage
    │                │                  │                 │               │
    │── Skanner QR ──►                  │                 │               │
    │                │── Redirect ──────►                 │               │
    │                │                  │── Viser side ──►               │
    │                │                  │                 │── Registrer ──►
    │                │                  │                 │               │
    │                │                  │                 │◄── Lagret ────│

Deltaker       Tom flaske       AdvanReader       dashboard.html   localStorage
    │                │                  │                 │               │
    │── Kaster flaske►                  │                 │               │
    │                │── RFID-les ──────►                 │               │
    │                │                  │── REST API ─────►               │
    │                │                  │                 │── Oppslag ────►
    │                │                  │                 │◄── Bruker ────│
    │                │                  │                 │               │
    │                │                  │           Leaderboard oppdatert │
```

---

## Fremtidige utvidelser

Systemet er designet for å skalere til produksjonsbruk med følgende utvidelser:

**Backend-persistens:** Erstatt `localStorage` med et API-kall til Bifrost eller Supabase, slik at data deles på tvers av enheter og bevares etter eventet.

**Sanntids-push:** Bruk WebSocket eller Server-Sent Events i stedet for polling, for umiddelbar oppdatering av leaderboardet uten forsinkelse.

**Multi-event støtte:** Legg til event-ID i GIAI-strukturen for å støtte flere samtidige events med samme infrastruktur.

**Pant-verifisering:** Integrer med Infinitum (Norsk Resirk) sitt API for å verifisere at flasker faktisk er registrert i det nasjonale pant-systemet.

---

*Dokument utarbeidet av Invig AS for GS1 Nordic Summit 2025.*  
*Kontakt: [sales@invig.no](mailto:sales@invig.no) · [invig.no](https://invig.no)*
