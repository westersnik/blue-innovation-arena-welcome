# Visuell kontroll

Utført lokalt 13. august 2026.

| Flate | Resultat | Merknad |
|---|---|---|
| `konfigurasjon.html` | Bestått | Opprettelse av arrangement og gjestetildeling er visuelt tydelige. Felter, etiketter og handlingsknapper har god kontrast både på desktop og i smal layout. |
| `storskjerm.html` | Bestått | Tomtilstanden «Klar for neste gjest» har et tydelig visuelt hierarki og er egnet for storskjerm. Den personlige velkomstflaten er skjult til en gyldig skann mottas. |
| Datakobling | Forventet blokkering lokalt | Den eksisterende Supabase-instansen har ikke `welcome_*`-migrasjonen anvendt ennå. Sidene viser derfor en schema-cache-feil lokalt. Dette er forventet frem til `20260813_welcome_events.sql` er kjørt og funksjonen er distribuert. |

Før produksjonsbruk må migrasjonen kjøres og `welcome-rfid-relay` distribueres. Se `docs/WELCOME-SETUP.md`.
