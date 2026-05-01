# Keonn AdvanReader – HTTP Service Setup Guide

**GS1 Nordic Summit 2025 · Recycling Station Integration**

This guide configures the Keonn AdvanReader to POST RFID tag reads to the GS1 Nordic Summit backend whenever a bottle is dropped in the recycling bin.

---

## System Architecture

```
[Bottle dropped in bin]
        │
        ▼
[Keonn AdvanReader reads RFID tag EPC]
        │  HTTPS POST (JSON) to /api/rfid
        ▼
[https://gs1-nordic.invig.no/api/rfid]
        │
        ▼
[Supabase: rfid_events table]
        │  Realtime WebSocket subscription
        ▼
[Display screen: gs1-nordic.invig.no/storskjerm.html]
        │
        ▼
[Popup: "Thank you [Name] for recycling!"]
```

---

## Step 1 – Open AdvanNet Manager

1. Connect the AdvanReader to the local event network.
2. Open a browser and navigate to `http://<reader-ip>:8080` (default AdvanNet Manager port).
3. Log in with your AdvanNet credentials.
4. In the left sidebar, click **HTTPService**.
5. Toggle **Advanced** mode on (top right of the Services panel).

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
| **Authentication Method** | `No Authorization` |
| **Connection timeout** | `5000` |

> **Local testing without domain:** Use `http` + `<server-ip>` + port `3000`.

---

## Step 3 – HTTP Advanced Settings

| Field | Value |
|---|---|
| **Content-Type** | `application/json` |
| **Send one by one** | ☐ Unchecked (batch mode is more efficient) |
| **Inventory tag TTL (s)** | `60` |
| **Re-send when in error** | ✅ Checked |
| **Expected HTTP response** | `200` |

> **TTL note:** With TTL = 60, the same bottle EPC will only be sent once per minute. This prevents duplicate recycling events if a bottle sits in the bin for a while.

---

## Step 4 – JSON Config (paste into the "JSON config" field)

This is the exact payload template from the Keonn official documentation, adapted to POST to `/api/rfid`:

```
[{"event":"TAG_READ","path":"'/api/rfid'","body":"var body='{';body+='\"devid\": \"'+ctx_devid+'\",';body+='\"devip\": \"'+ctx_devip+'\",';body+='\"devmac\": \"'+ctx_devmac+'\",';body+='\"reads\": [';for(i=0;i<ctx_tags.length;i++){body+='{';body+='\"epc\": \"'+ctx_tags[i].getEPC()+'\",';body+='\"sku\": \"'+ctx_tags[i].getSKU()+'\",';body+='\"serial\": \"'+ctx_tags[i].getSerial()+'\",';body+='\"tid\": \"'+ctx_tags[i].getTID()+'\",';body+='\"phase\": \"'+ctx_tags[i].getPhase()+'\",';body+='\"antenna\": \"'+ctx_tags[i].getAntenna()+'\",';body+='\"mux1\": \"'+ctx_tags[i].getMux1()+'\",';body+='\"mux2\": \"'+ctx_tags[i].getMux2()+'\",';body+='\"uri\": \"'+ctx_tags[i].getURI()+'\",';body+='\"rssi\": \"'+ctx_tags[i].getRSSI()+'\",';body+='\"ts\": \"'+ctx_tags[i].getUTC()+'\"';body+='}';if(i<ctx_tags.length-1){body+=',';}}body+=']';body+='}';"  }]
```

> **Important:** The JSON config must be on a single line with no line breaks or tabs before entering it into the device. Validate it at [jsonlint.com](https://jsonlint.com/) before pasting (remove line breaks first).

### Readable version (for reference only – do not paste with line breaks)

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
      body+='\"tid\": \"'+ctx_tags[i].getTID()+'\",';
      body+='\"phase\": \"'+ctx_tags[i].getPhase()+'\",';
      body+='\"antenna\": \"'+ctx_tags[i].getAntenna()+'\",';
      body+='\"mux1\": \"'+ctx_tags[i].getMux1()+'\",';
      body+='\"mux2\": \"'+ctx_tags[i].getMux2()+'\",';
      body+='\"uri\": \"'+ctx_tags[i].getURI()+'\",';
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

---

## Step 5 – What the Backend Receives

The AdvanReader will POST a JSON body like this to `https://gs1-nordic.invig.no/api/rfid`:

```json
{
  "devid": "AdvanSafe-200-eu",
  "devip": "192.168.1.15",
  "devmac": "b0:d5:cc:9f:fd:f8",
  "reads": [
    {
      "epc": "3034257BF400B800000000C8",
      "sku": "",
      "serial": "",
      "tid": "",
      "phase": "1",
      "antenna": "1",
      "mux1": "0",
      "mux2": "0",
      "uri": "",
      "rssi": "-62",
      "ts": "1716900123456"
    }
  ]
}
```

The backend maps the `epc` field to a `giai` using the `bottles.json` lookup table (EPC ↔ GIAI mapping from the GS1 Nordic Summit Excel file), then inserts a row into the `rfid_events` Supabase table.

---

## Step 6 – Save Settings

Click **Save current** in the AdvanNet Manager toolbar. Settings are persisted to the reader's flash memory and survive reboots.

---

## Step 7 – Test the Connection

### Option A: curl (recommended for quick test)

```bash
curl -X POST https://gs1-nordic.invig.no/api/rfid \
  -H "Content-Type: application/json" \
  -d '{
    "devid": "test-reader",
    "devip": "192.168.1.99",
    "devmac": "aa:bb:cc:dd:ee:ff",
    "reads": [
      {
        "epc": "3034257BF400B800000000C8",
        "sku": "",
        "serial": "",
        "tid": "",
        "antenna": "1",
        "rssi": "-62",
        "ts": "1716900123456"
      }
    ]
  }'
```

**Expected response:**

```json
{
  "success": true,
  "processed": 1,
  "results": [
    {
      "epc": "3034257BF400B800000000C8",
      "giai": "70735391688",
      "status": "recorded"
    }
  ],
  "stats": {
    "recycled": 1,
    "total": 300
  },
  "milestones_triggered": []
}
```

### Option B: Python test server (local debugging)

Use the official Keonn `httpServer.py` to verify the reader is sending data before pointing it at the production endpoint:

```python
"""
Simple HTTP server for logging Keonn AdvanReader requests.
Usage: python3 httpServer.py [port]
Default port: 8080
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
import logging

class S(BaseHTTPRequestHandler):
    def _set_response(self):
        self.send_response(200)
        self.end_headers()

    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        logging.info("POST body:\n%s", post_data.decode('utf-8'))
        self._set_response()

def run(port=8080):
    logging.basicConfig(level=logging.INFO)
    httpd = HTTPServer(('', port), S)
    logging.info('Listening on port %d', port)
    httpd.serve_forever()

if __name__ == '__main__':
    import sys
    run(port=int(sys.argv[1]) if len(sys.argv) == 2 else 8080)
```

Run it on a laptop on the same network as the reader:

```bash
python3 httpServer.py 8080
```

Then set the Keonn reader to POST to `http://<laptop-ip>:8080/api/rfid` and hold a bottle near the antenna. The raw JSON payload will appear in the terminal.

---

## API Endpoint Reference

### `POST /api/rfid`  ← Keonn AdvanReader posts here

| Field | Value |
|---|---|
| **URL** | `https://gs1-nordic.invig.no/api/rfid` |
| **Method** | `POST` |
| **Content-Type** | `application/json` |
| **Authentication** | None (open endpoint) |

**Accepted body formats:**

```jsonc
// Format 1: Full Keonn batch (recommended)
{ "devid": "...", "reads": [{ "epc": "...", "ts": "..." }] }

// Format 2: Single tag shorthand
{ "epc": "3034257BF400B800000000C8" }

// Format 3: Tags array
{ "tags": [{ "epc": "3034257BF400B800000000C8" }] }
```

**Response fields:**

| Field | Description |
|---|---|
| `success` | `true` if at least one tag was processed |
| `processed` | Number of EPC tags in the request |
| `results[].status` | `"recorded"` (new) or `"duplicate"` (already in database) |
| `stats.recycled` | Total recycled bottles so far |
| `milestones_triggered` | Array of milestone objects if a threshold was crossed |

---

### `GET /api/stats`  ← Display screen polls this

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

### `POST /api/register`  ← Mobile QR scan page posts here

```json
{
  "phone": "+4712345678",
  "name": "Ola Normann",
  "company": "GS1 Norway",
  "giai": "70735391141"
}
```

---

## EPC ↔ GIAI Mapping

The Keonn reader returns raw EPC hex codes. The backend converts EPC to GIAI using the GS1 GIAI-96 encoding:

| EPC (hex, from reader) | GIAI (in Supabase) | Redirect URL |
|---|---|---|
| `3034257BF400B800000000C8` | `70735391688` | `https://id.invig.no/8004/70735391688` |
| `3034257BF400B800000000C9` | `70735391689` | `https://id.invig.no/8004/70735391689` |

The full EPC-to-GIAI mapping for all 300 bottles is in `bottles.json` in this repository.

---

## Advanced JSON Config (optional debug)

To enable debug logging on the reader, paste this into the **Advanced JSON conf** field:

```json
{"debug":true,"debugTransport":true}
```

To add a custom header (e.g. a shared secret for future authentication):

```json
{"debug":false,"customHeaders":[{"header":"X-Event-Key: gs1nordic2025"}]}
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| No POST received by server | HTTPService not enabled | Enable in AdvanNet Manager sidebar |
| `400 Bad Request` | Malformed JSON config | Validate at jsonlint.com (remove line breaks first) |
| `duplicate` for all tags | Same EPC already in database | Expected – each EPC is unique per recycling event |
| Display screen not updating | Supabase Realtime not connected | Check browser console for WebSocket errors |
| HTTPS certificate error | Domain not yet propagated | Use `http://` + server IP for local testing |
| Tags read but not posted | TTL not expired yet | Lower TTL to 5s for testing, restore to 60s for event |
| Reader posts but path wrong | Path must start with `/` | Ensure path is `'/api/rfid'` with single quotes inside |

---

## References

- [Keonn HTTP Service documentation](https://wiki.keonn.com/software/advannet/services/http-service)
- [Keonn HTTP Payload JSON config templates](https://wiki.keonn.com/software/advannet/services/http-service/http-payload-json-config-templates)
- [GS1 GIAI Application Identifier 8004](https://www.gs1.org/standards/id-keys/giai)
- [Supabase Realtime documentation](https://supabase.com/docs/guides/realtime)
- [jsonlint.com – JSON validator](https://jsonlint.com/)
