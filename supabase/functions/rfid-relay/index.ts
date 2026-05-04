/**
 * Supabase Edge Function: rfid-relay
 *
 * Accepts POST from Keonn AdvanReader (SimpleHTTPService) and writes
 * EPC tag reads to the rfid_events table using the service role key.
 *
 * Only EPC codes that decode to a valid event GIAI (70735391641–70735391940)
 * are accepted. All other tags are silently ignored.
 *
 * Supported body formats:
 *   { "epc": "3034257BF400B800000000C8" }                        – single tag
 *   { "tags": [{ "epc": "..." }] }                               – batch
 *   { "reads": [{ "EPC": "...", "ts": "..." }] }                 – AdvanNet format
 *   { "devid": "...", "reads": [...] }                           – full AdvanNet format
 *
 * URL: https://spbfuhajwfadzvdidalk.supabase.co/functions/v1/rfid-relay
 * Method: POST
 * Content-Type: application/json
 * Auth: none required (uses service role key internally)
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const EVENT_KEY = Deno.env.get('RFID_EVENT_KEY') ?? 'gs1nordic2026'; // optional shared secret

// Valid GIAI range for this event: 70735391641–70735391940 (300 Carlsberg bottles)
const GIAI_MIN = 70735391641n;
const GIAI_MAX = 70735391940n;

// GS1 GIAI-96 EPC → GIAI conversion
// GS1 TDS 1.13 Table 14-3:
//   Header:    8 bits = 0x34  (NOT 0x30 — that's SGTIN-96)
//   Filter:    3 bits
//   Partition: 3 bits
//   GCP:       variable (depends on partition)
//   Asset Ref: variable (depends on partition)
//   Total:     96 bits
//
// Partition table (GCP digits → field widths):
//   P=0: GCP=40b(12d), AR=42b  |  P=1: GCP=37b(11d), AR=45b
//   P=2: GCP=34b(10d), AR=48b  |  P=3: GCP=30b(9d),  AR=52b
//   P=4: GCP=27b(8d),  AR=55b  |  P=5: GCP=24b(7d),  AR=58b  ← GCP 7073539
//   P=6: GCP=20b(6d),  AR=62b
const GIAI96_HEADER = 0x34n;
const PARTITION_TABLE: Record<number, [number, number, number]> = {
  0: [40, 42, 12], 1: [37, 45, 11], 2: [34, 48, 10], 3: [30, 52, 9],
  4: [27, 55, 8],  5: [24, 58, 7],  6: [20, 62, 6],
};

function epcToGiai(epcHex: string): string | null {
  try {
    const hex = epcHex.replace(/\s/g, '').toUpperCase();
    if (hex.length !== 24) return null;
    const val = BigInt('0x' + hex);
    // Check GIAI-96 header (top 8 bits must be 0x34)
    const header = (val >> 88n) & 0xFFn;
    if (header !== GIAI96_HEADER) return null;
    // Extract partition (bits 82-84)
    const partition = Number((val >> 82n) & 0x7n);
    const entry = PARTITION_TABLE[partition];
    if (!entry) return null;
    const [gcpBits, arBits, gcpDigits] = entry;
    // Extract GCP and Asset Reference
    const gcpMask = (1n << BigInt(gcpBits)) - 1n;
    const gcp = (val >> BigInt(arBits)) & gcpMask;
    const arMask = (1n << BigInt(arBits)) - 1n;
    const ar = val & arMask;
    // GIAI = GCP (zero-padded to gcpDigits) + AR (decimal)
    const giai = gcp.toString().padStart(gcpDigits, '0') + ar.toString();
    return giai;
  } catch {
    return null;
  }
}

// Validate that a GIAI belongs to this event's bottle range
function isValidEventGiai(giai: string): boolean {
  try {
    const n = BigInt(giai);
    return n >= GIAI_MIN && n <= GIAI_MAX;
  } catch {
    return false;
  }
}

Deno.serve(async (req: Request) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Event-Key',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Optional: validate event key header
  const eventKey = req.headers.get('X-Event-Key');
  if (EVENT_KEY && eventKey && eventKey !== EVENT_KEY) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Parse EPC tags from various Keonn body formats
  let rawTags: Array<{ epc: string; readerId?: string }> = [];

  if (typeof body.epc === 'string') {
    rawTags = [{ epc: body.epc, readerId: body.devid ?? body.reader_id ?? 'advanreader' }];
  } else if (Array.isArray(body.tags)) {
    rawTags = body.tags.map((t: any) => ({
      epc: (t.epc ?? t.EPC ?? '').toUpperCase(),
      readerId: body.devid ?? t.reader_id ?? 'advanreader',
    }));
  } else if (Array.isArray(body.reads)) {
    rawTags = body.reads.map((r: any) => ({
      epc: (r.epc ?? r.EPC ?? '').toUpperCase(),
      readerId: body.devid ?? r.reader_id ?? 'advanreader',
    }));
  }

  rawTags = rawTags.filter(t => t.epc && t.epc.length > 0);

  if (rawTags.length === 0) {
    return new Response(JSON.stringify({ success: true, processed: 0, message: 'No tags in payload' }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  const results: Array<{ epc: string; giai: string | null; status: string }> = [];
  let recorded = 0;
  let duplicates = 0;
  let skipped = 0;

  for (const { epc, readerId } of rawTags) {
    const giai = epcToGiai(epc);

    // ── GIAI range validation ─────────────────────────────────────────────────────────────────
    // Only accept EPC codes that decode to a valid event bottle GIAI.
    // Any other tag (wrong event, wrong type, stray tags) is written to
    // rfid_feedback so the display can show a "not recognised" popup.
    if (!giai || !isValidEventGiai(giai)) {
      skipped++;
      results.push({ epc, giai, status: 'skipped (not an event bottle)' });
      // Write feedback so display can react
      await supabase.from('rfid_feedback').insert({ epc, giai, event_type: 'invalid' });
      continue;
    }

    const { error } = await supabase.from('rfid_events').insert({
      epc,
      giai,
      reader_id: readerId ?? 'advanreader',
      recycled_at: new Date().toISOString(),
    });

    if (error) {
      if (error.code === '23505') {
        // Unique constraint violation — already recorded (idempotent)
        duplicates++;
        results.push({ epc, giai, status: 'duplicate' });
        // Write feedback so display can show "already recycled" popup
        await supabase.from('rfid_feedback').insert({ epc, giai, event_type: 'duplicate' });
      } else {
        results.push({ epc, giai, status: `error: ${error.message}` });
      }
    } else {
      recorded++;
      results.push({ epc, giai, status: 'recorded' });
    }
  }

  return new Response(
    JSON.stringify({
      success: true,
      processed: rawTags.length,
      recorded,
      duplicates,
      skipped,
      results,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  );
});
