# Keonn AdvanReader – HTTP Service Setup Guide

**GS1 Nordic Summit 2026 · Recycling Station Integration**

This guide configures the Keonn AdvanReader to POST RFID tag reads directly to the Supabase Edge Function whenever a bottle is dropped in the recycling bin.

---

## System Architecture

```
[Bottle dropped in bin]
        │
        ▼
[Keonn AdvanReader reads RFID tag EPC]
        │  HTTPS POST (JSON) — SimpleHTTPService
        ▼
[Supabase Edge Function: rfid-relay]
https://spbfuhajwfadzvdidalk.supabase.co/functions/v1/rfid-relay
        │  Converts EPC → GIAI, inserts into rfid_events (idempotent)
        ▼
[Supabase: rfid_events table]
        │  Realtime WebSocket subscription
        ▼
[Display screen: gs1-nordic.invig.no/storskjerm.html]
        │
        ▼
[Popup: "Thank you [Name] for recycling!"]
```

> **Why Edge Function?** `gs1-nordic.invig.no` is a static GitHub Pages site — it cannot receive POST requests. The Supabase Edge Function runs server-side, converts the EPC to GIAI, and writes to the database with the service role key (bypassing RLS safely).

---

## Step 1 – Open AdvanNet Manager

1. Connect the AdvanReader to the local event network.
2. Open a browser and navigate to `http://<reader-ip>:8080` (default AdvanNet Manager port).
3. Log in with your AdvanNet credentials.
4. In the left sidebar, click **Services** → **SimpleHTTPService**.
5. Toggle **Advanced** mode on (top right of the Services panel).

---

## Step 2 – HTTP Connection Settings

Fill in the fields **exactly** as shown:

| Field | Value |
|---|---|
| **Enabled** | ✅ Checked |
| **Endpoint URL** | `https://spbfuhajwfadzvdidalk.supabase.co/functions/v1/rfid-relay` |
| **HTTP method** | `POST` |
| **Content-Type** | `JSON (application/json)` |
| **Username (Basic auth)** | *(leave empty)* |
| **Password (Basic auth)** | *(leave empty)* |

> **Note:** No Basic Auth is needed — the Edge Function uses an event key in the JSON payload config instead.

---

## Step 3 – HTTP Advanced Settings

| Field | Value |
|---|---|
| **Send one by one** | ☐ Unchecked (batch mode) |
| **Inventory tag TTL (s)** | `60` |
| **Re-send when in error** | ✅ Checked |
| **Expected HTTP response** | `200` |

> **TTL note:** With TTL = 60, the same bottle EPC will only be sent once per minute. The Edge Function also enforces idempotency at the database level — duplicate EPCs are silently ignored.

---

## Step 4 – JSON Config (paste into the "JSON config" field)

This payload template sends EPC tags to the Edge Function in the correct format:

```
[{"event":"TAG_READ","path":"'/functions/v1/rfid-relay'","body":"var body='{';body+='\"devid\": \"'+ctx_devid+'\",';body+='\"devip\": \"'+ctx_devip+'\",';body+='\"reads\": [';for(i=0;i<ctx_tags.length;i++){body+='{';body+='\"epc\": \"'+ctx_tags[i].getEPC()+'\",';body+='\"rssi\": \"'+ctx_tags[i].getRSSI()+'\",';body+='\"ts\": \"'+ctx_tags[i].getUTC()+'\"';body+='}';if(i<ctx_tags.length-1){body+=',';}}body+=']';body+='}';"  }]
```

> **Validate your JSON config** at [jsonlint.com](https://jsonlint.com/) before saving (remove line breaks first).

---

## Step 5 – Custom Headers (optional but recommended)

To add the event key header for extra security, paste this into the **Advanced JSON conf** field:

```json
{"customHeaders":[{"header":"X-Event-Key: gs1nordic2026"}]}
```

---

## Step 6 – Test the Connection

After saving, test with curl from any machine:

```bash
curl -s -X POST \
  "https://spbfuhajwfadzvdidalk.supabase.co/functions/v1/rfid-relay" \
  -H "Content-Type: application/json" \
  -H "X-Event-Key: gs1nordic2026" \
  -d '{"epc":"3034257BF400B800000000C8","reader_id":"advanreader-test"}'
```

**Expected response (first time):**
```json
{"success":true,"processed":1,"recorded":1,"duplicates":0,"results":[{"epc":"3034257BF400B800000000C8","giai":"70735390200","status":"recorded"}]}
```

**Expected response (duplicate):**
```json
{"success":true,"processed":1,"recorded":0,"duplicates":1,"results":[{"epc":"3034257BF400B800000000C8","giai":"70735390200","status":"duplicate"}]}
```

---

## EPC ↔ GIAI Mapping

The AdvanReader returns raw EPC hex codes. The Edge Function converts EPC to GIAI using the GS1 GIAI-96 encoding (GS1 TDS 1.13, Table 14-3).

**GIAI-96 EPC structure** for GCP `7073539` (7 digits, partition 5):
- Header: `0x34` (8 bits) — note: `0x30` is SGTIN-96, NOT GIAI-96
- Filter: 3 bits
- Partition: `5` (3 bits)
- GCP: 24 bits
- Asset Reference: 58 bits
- **Total: 96 bits**

| EPC (hex, from reader) | GIAI (in Supabase) | Bottle # |
|---|---|---|
| `3415AFBC0C000000000003E9` | `70735391001` | #1 |
| `3415AFBC0C00000000000412` | `70735391042` | #42 |
| `3415AFBC0C0000000000044C` | `70735391100` | #100 |
| `3415AFBC0C00000000000514` | `70735391300` | #300 |

Formula: `GIAI = "7073539" + AR_decimal` where AR = bits 38–95 (58-bit field)

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| No POST received | SimpleHTTPService not enabled | Enable in AdvanNet Manager sidebar |
| `401 Unauthorized` | Wrong X-Event-Key | Use `gs1nordic2026` |
| `400 Bad Request` | Malformed JSON config | Validate at jsonlint.com |
| `duplicate` for all tags | Same EPC already in database | Expected — each EPC is unique per event |
| All tags show `skipped (not an event bottle)` | EPC header mismatch — bottles not programmed as GIAI-96 | Verify bottle tags start with `0x34`; if they start with `0x30` they are SGTIN-96 not GIAI-96 |
| Display screen not updating | Supabase Realtime not connected | Check browser console for WebSocket errors |
| HTTPS certificate error | Network issue | Verify internet connectivity on reader |
| Tags read but not posted | TTL not expired yet | Lower TTL to 5s for testing, restore to 60s for event |

---

## Registration API

To register a guest for a bottle via the mobile QR scan page:

```bash
curl -s -X POST \
  "https://spbfuhajwfadzvdidalk.supabase.co/functions/v1/rfid-relay" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+4712345678",
    "name": "Ola Normann",
    "company": "GS1 Norway",
    "giai": "70735391141"
  }'
```

---

## References

- [Keonn HTTP Service documentation](https://wiki.keonn.com/software/advannet/services/http-service)
- [Keonn HTTP Payload JSON config templates](https://wiki.keonn.com/software/advannet/services/http-service/http-payload-json-config-templates)
- [GS1 GIAI Application Identifier 8004](https://www.gs1.org/standards/id-keys/giai)
- [Supabase Edge Functions documentation](https://supabase.com/docs/guides/functions)
- [Supabase Realtime documentation](https://supabase.com/docs/guides/realtime)
- [jsonlint.com – JSON validator](https://jsonlint.com/)
