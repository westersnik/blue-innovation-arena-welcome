# Importprotokoll: Invig X ÅKP GIAI 4596–4695

Denne protokollen dokumenterer importen av RFID-taggene fra arbeidsboken `InvigXAKP-GIAI-encoding-100tags-EN.xlsx` til Blue Innovation Arena Event Welcome.

| Kontrollpunkt | Verdi |
|---|---|
| GS1-nøkkel | GIAI-96, AI (8004) |
| Selskapprefiks | `7073539` — 7 sifre |
| GIAI-referanser | `4596–4695` |
| Antall tagger | 100 |
| Batchkode i Event Welcome | `invig-akp-giai-4596-4695` |
| Synlig ID-serie i batchen | `1–100` |
| Global intern katalogserie | `301–400` |
| Første EPC | `3415AFBC0C000000000011F4` |
| Siste EPC | `3415AFBC0C00000000001257` |

## Validering før import

Alle 100 rader ble kontrollert mot GIAI-96-partisjon 5 for et 7-sifret selskapprefiks. Hver EPC ble rekodet fra GIAI-referansen og sammenlignet med arbeidsboken. Resultatet var 100 unike GIAI-verdier og 100 unike EPC-verdier uten avvik.

Serien ble også sammenlignet med den eksisterende Supabase-katalogen før import. Det var ingen treff eller konflikter på verken EPC eller GIAI.

## Import og verifikasjon

Migrasjonen `20260816_import_invig_akp_giai_4596_4695.sql` oppretter batchen og legger inn de 100 taggene. Hver fysisk tagg får en batch-lokal `display_number` fra 1 til 100, mens `bottle_num` holdes globalt unik fra 301 til 400. Oppdateringen av `create_welcome_event` gjør at arrangementer nå reserverer tagger etter batch-lokalt ID-nummer.

Etter import ble følgende kontrollert direkte fra Supabase:

| Kontroll | Resultat |
|---|---|
| Batch finnes | Ja |
| Antall importerte tagger | 100 |
| Synlig nummerserie | Sammenhengende `1–100` |
| Første GIAI/EPC | `70735394596` / `3415AFBC0C000000000011F4` |
| Siste GIAI/EPC | `70735394695` / `3415AFBC0C00000000001257` |
| Digital Link-test | `https://id.invig.no/8004/70735394596` returnerte HTTP 200 og videresendte til `https://ons.invig.no/`. |

> **Viktig:** Selskapprefikset og GIAI-serien er hentet fra den vedlagte, allerede kodede arbeidsboken. EPC-runde-turen og fravær av katalogkonflikter er validert teknisk ved import. Ved en ny fysisk etikettproduksjon skal prefiksautorisasjonen fortsatt kontrolleres mot Invigs GS1-lisens.

## Mål ved mobilskanning

En mobilskanning av en QR-kode eller GS1 Digital Link skal vise en offentlig
informasjonside for gjesten, ikke konfigurasjonssiden eller storskjermen.
Siden finnes i GitHub Pages-publiseringen her:

`https://westersnik.github.io/blue-innovation-arena-welcome/tagg.html?giai={GIAI}`

For denne batchen skal Invigs GS1-resolver beholde den unike, standardiserte
inngangslenken `https://id.invig.no/8004/{GIAI}`, men videresende den til
siden over. Eksempel for tagg-ID 1:

`https://id.invig.no/8004/70735394596` →
`https://westersnik.github.io/blue-innovation-arena-welcome/tagg.html?giai=70735394596`

ID 1–25 tilsvarer GIAI `70735394596–70735394620`. Videresendingen kan settes
som en mønsterregel dersom resolveren støtter å sende den skannede GIAI-verdien
videre som query-parameter. Dersom den ikke gjør det, skal det opprettes én
videresendingsregel per GIAI. Den publiserte mottakersiden viser kun RFID-ID og
GIAI, aldri navn eller selskap.
