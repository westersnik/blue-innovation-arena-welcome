/**
 * Supabase Edge Function: rfid-relay
 *
 * Accepts POST from Keonn AdvanReader (SimpleHTTPService) and writes
 * EPC tag reads to the rfid_events table using the service role key.
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

// GS1 GIAI-96 EPC → GIAI conversion
// Matches the logic in server/supabase.ts (Manus app)
function epcToGiai(epcHex: string): string | null {
  try {
    const hex = epcHex.replace(/\s/g, '').toUpperCase();
    if (hex.length !== 24) return null;
    const bigint = BigInt('0x' + hex);
    // Extract asset reference: last 38 bits (bits 58-95)
    const assetRef = bigint & BigInt('0x3FFFFFFFFF');
    const gcp = '7073539';
    const giai = gcp + assetRef.toString().padStart(4, '0');
    return giai;
  } catch {
    return null;
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

  for (const { epc, readerId } of rawTags) {
    const giai = epcToGiai(epc);

    const { error } = await supabase.from('rfid_events').insert({
      epc,
      giai: giai ?? epc, // fallback: use EPC as GIAI if conversion fails
      reader_id: readerId ?? 'advanreader',
      recycled_at: new Date().toISOString(),
    });

    if (error) {
      if (error.code === '23505') {
        // Unique constraint violation — already recorded
        duplicates++;
        results.push({ epc, giai, status: 'duplicate' });
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
      results,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  );
});
