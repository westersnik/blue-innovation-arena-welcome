# Produksjonsnotater

| Område | Status | Merknad |
|---|---|---|
| Supabase-prosjekt | Klargjort | Prosjekt `vvqpbvicvhwqbjezifst` er valgt for Event Welcome. |
| Datamigrasjoner | Anvendt | RFID-katalog og velkomsttabeller er opprettet via `20260810_welcome_bootstrap.sql` og `20260813_welcome_events.sql`. |
| RFID-endepunkt | Aktivt | `welcome-rfid-relay` er distribuert uten JWT og krever `X-Event-Key`. |
| GitHub-repository | Offentlig | Repositoryet måtte gjøres offentlig fordi GitHub Pages ikke var tilgjengelig for private repositoryer i den aktive planen. |
| GitHub Pages | Klargjøres | Publiser fra `gh-pages`-grenen og `/ (root)` når Pages-innstillingen er tilgjengelig. |

Bruk `https://westersnik.github.io/gs1-nordic-welcome/` som offentlig grunn-URL etter at GitHub Pages er aktivert.

## GitHub Pages-kontroll

GitHub Pages ble aktivert fra `gh-pages`-grenen med `/ (root)` som publiseringsmappe. GitHub bekreftet at nettstedet bygges fra den valgte grenen. Repositoryet er offentlig, etter uttrykkelig godkjenning, fordi Pages ikke var tilgjengelig for private repositoryer på den aktive planen.

## Offentlig nettstedsverifisering

Startsiden er publisert og tilgjengelig på `https://westersnik.github.io/gs1-nordic-welcome/`. Konfigurasjonssiden lastes fra samme GitHub Pages-domene og viser det forventede skjemaet. Den asynkrone lastingen av RFID-batchen skal verifiseres videre mot Supabase etter at nettleseren har fått fullføre dataoppkallet.

## Sluttkontroll

Konfigurasjonssiden viser `RFID-tag batch 1` med gyldig ID-serie `1–300` fra det nye Supabase-prosjektet. Direkte API-kontroll bekreftet lesetilgang til alle fem datakildene som siden bruker. Det offentlige `welcome-rfid-relay`-endepunktet svarer med `401 Unauthorized` uten `X-Event-Key`, som bekrefter at RFID-hemmeligheten er aktiv og at uautoriserte lesninger blir avvist.
