# Keonn AdvanReader – HTTP Service Setup Guide

**GS1 Nordic Summit 2025 · Recycling Station Integration**

This guide configures the Keonn AdvanReader to POST RFID tag reads to the GS1 Nordic Summit backend whenever a bottle is dropped in the recycling bin.

---

## Overview

```
[Bottle dropped in bin]
        │
        ▼
[Keonn AdvanReader reads RFID tag EPC]
        │  HTTP POST (JSON)
        ▼
[https://gs1-nordic.invig.no/api/rfid]
        │
        ▼
[Supabase: rfid_events table]
        │  Realtime subscription
        ▼
[Display screen: storskjerm.html]
        │
        ▼
[Popup: "Thank you [Name] for recycling!"]
```

---

## Step 1 – Open AdvanNet Manager

1. Connect to the AdvanReader on your local network.
2. Open a browser and navigate to `http://<reader-ip>:8080` (default AdvanNet Manager port).
3. Log in with your AdvanNet credentials.
4. In the left sidebar, click **HTTPService** (enable it if not already enabled).

---

## Step 2 – HTTP Connection Settings

Fill in the fields exactly as shown:

| Field | Value |
|---|---|
| **Enabled** | ✅ Checked |
| **Protocol** | `https` |
| **Host** | `gs1-nordic.invig.no` |
| **Port** | `443` |
| **HTTP method** | `POST` |
| **Authentication Method** | `No Authentication` |
| **Connection timeout** | `5000` |

> **Note:** If the domain is not yet live, use `http` + `<your-server-ip>` + port `3000` for local testing.

---

## Step 3 – HTTP Advanced Settings

| Field | Value |
|---|---|
| **Content-Type** | `JSON` |
| **Send one by one** | ☐ Unchecked (batch mode) |
| **Inventory tag TTL (s)** | `60` |
| **Re-send when in error** | ✅ Checked |
| **Expected HTTP response** | `200` |

---

## Step 4 – HTTP Payload JSON Config

Paste the following into the **JSON config** field on the right panel. This template formats each batch of tag reads as a JSON array that the `/api/rfid` endpoint understands.

```json
[{
  "event": "TAG_READ",
  "path": "'/api/rfid'",
  "body": "
    var body='{';
    body+='\"devid\": \"'+ctx_devid+'\",';
    body+='\"devip\": \"'+ctx_devip+'\",';
    body+='\"devmac\": \"'+ctx_devmac+'\",';
    body+='\"reads\": [';
    for(i=0;i<ctx_tags.length;i++) {
      body+='{';
      body+='\"epc\": \"'+ctx_tags[i].getEPC()+'\",';
      body+='\"sku\": \"'+ctx_tags[i].getSKU()+'\",';
      body+='\"serial\": \"'+ctx_tags[i].getSerial()+'\",';
      body+='\"rssi\": \"'+ctx_tags[i].getRSSI()+'\",';
      body+='\"ts\": \"'+ctx_tags[i].getUTC()+'\"';
      body+='}';
      if(i < ctx_tags.length - 1){ body+=','; }
    }
    body+=']';
    body+='}';
  "
}]
```

### What the backend receives

```json
{
  "devid": "AdvanReader-01",
  "devip": "192.168.1.15",
  "devmac": "b0:d5:cc:9f:fd:f8",
  "reads": [
    {
      "epc": "3034257BF400B800000000C8",
      "sku": "",
      "serial": "",
      "rssi": "-62",
      "ts": "1716900123456"
    }
  ]
}
```

---

## Step 5 – Save and Test

1. Click **Save current** in the AdvanNet Manager toolbar.
2. Hold an RFID-tagged bottle near the antenna.
3. The reader should POST to `https://gs1-nordic.invig.no/api/rfid`.
4. The display screen (`storskjerm.html`) should show the recycling popup within 1–2 seconds.

### Manual test with curl

```bash
curl -X POST https://gs1-nordic.invig.no/api/rfid \
  -H "Content-Type: application/json" \
  -d '{
    "devid": "test-reader",
    "reads": [
      { "epc": "3034257BF400B800000000C8", "ts": "1716900123456" }
    ]
  }'
```

Expected response:

```json
{
  "success": true,
  "processed": 1,
  "results": [
    { "epc": "3034257BF400B800000000C8", "giai": "70735391688", "status": "recorded" }
  ],
  "stats": { "recycled": 1, "total": 300 },
  "milestones_triggered": []
}
```

---

## API Endpoint Reference

### `POST /api/rfid`

Accepts RFID tag reads from the Keonn AdvanReader.

**Accepted body formats:**

```jsonc
// Format 1: Keonn HTTP Service (recommended)
{ "reads": [{ "epc": "3034257BF400B800000000C8", "ts": "1716900123456" }] }

// Format 2: Single tag
{ "epc": "3034257BF400B800000000C8" }

// Format 3: Tag array
{ "tags": [{ "epc": "3034257BF400B800000000C8" }] }
```

**Response:**

| Field | Description |
|---|---|
| `success` | `true` if at least one tag was processed |
| `processed` | Number of EPC tags in the request |
| `results[].status` | `"recorded"` (new) or `"duplicate"` (already recycled) |
| `stats.recycled` | Total recycled bottles so far |
| `milestones_triggered` | Array of milestone objects if a threshold was crossed |

---

### `GET /api/stats`

Returns current event statistics for the display screen.

```bash
curl https://gs1-nordic.invig.no/api/stats
```

```json
{
  "registered_drinkers": 47,
  "recycled_bottles": 31,
  "unique_bottles_scanned": 52,
  "total_bottles": 300,
  "recycle_rate": 10.3
}
```

---

### `POST /api/register`

Registers a mobile user when they scan a bottle QR code.

```json
{
  "phone": "+4712345678",
  "name": "Ola Normann",
  "company": "GS1 Norway",
  "giai": "70735391641"
}
```

---

## EPC ↔ GIAI Mapping

The Keonn reader returns raw EPC hex codes. The backend automatically converts EPC to GIAI using the GS1 GIAI-96 encoding scheme:

| EPC (hex) | GIAI |
|---|---|
| `3034257BF400B800000000C8` | `70735391688` |
| `3034257BF400B800000000C9` | `70735391689` |

The conversion uses the Invig GCP prefix `7073539` and the GS1 Application Identifier `8004`.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| No POST received | HTTPService not enabled | Enable in AdvanNet Manager sidebar |
| `400 Bad Request` | Empty reads array | Check JSON config template syntax |
| `duplicate` status for all tags | Same bottle scanned twice | Expected – each EPC is unique per event |
| Display screen not updating | Supabase Realtime not connected | Check browser console for WebSocket errors |
| HTTPS certificate error | Domain not yet live | Use `http://` + server IP for local testing |

---

## References

- [Keonn HTTP Service documentation](https://wiki.keonn.com/software/advannet/services/http-service)
- [Keonn HTTP Payload JSON config templates](https://wiki.keonn.com/software/advannet/services/http-service/http-payload-json-config-templates)
- [GS1 GIAI Application Identifier 8004](https://www.gs1.org/standards/id-keys/giai)
- [Supabase Realtime documentation](https://supabase.com/docs/guides/realtime)
