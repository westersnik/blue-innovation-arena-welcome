/**
 * Supabase Edge Function: rfid-relay
 *
 * Accepts POST from Keonn AdvanReader (SimpleHTTPService) and writes
 * EPC tag reads to the rfid_events table using the service role key.
 *
 * EPC validation is done by looking up the EPC in the `beers` table.
 * Only EPCs present in that table (the 300 event bottles) are accepted.
 * All other tags are written to rfid_feedback as 'invalid'.
 *
 * Supported body formats:
 *   { "epc": "3415AFBC0C0000000000014F" }                        – single tag
 *   { "tags": [{ "epc": "..." }] }                               – batch
 *   { "reads": [{ "EPC": "...", "ts": "..." }] }                 – AdvanNet format
 *   { "devid": "...", "reads": [...] }                           – full AdvanNet format
 *   { "epc_list": ["..."] }                                      – test format
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
  } else if (Array.isArray(body.epc_list)) {
    rawTags = body.epc_list.map((e: string) => ({ epc: e.toUpperCase(), readerId: 'advanreader' }));
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

  // Fetch all EPCs from beers table in one query for batch lookup
  const epcList = rawTags.map(t => t.epc.toUpperCase());
  const { data: beerRows, error: beerLookupError } = await supabase
    .from('beers')
    .select('epc, giai, bottle_num')
    .in('epc', epcList);

  // Build a map: EPC → { giai, bottle_num }
  const beerMap: Record<string, { giai: string; bottle_num: number }> = {};
  if (beerRows) {
    for (const row of beerRows) {
      beerMap[row.epc.toUpperCase()] = { giai: row.giai, bottle_num: row.bottle_num };
    }
  }

  const results: Array<{ epc: string; giai: string | null; bottle_num: number | null; status: string }> = [];
  let recorded = 0;
  let duplicates = 0;
  let skipped = 0;

  for (const { epc, readerId } of rawTags) {
    const normalizedEpc = epc.toUpperCase();
    const beer = beerMap[normalizedEpc];

    // Not in beers table → not an event bottle
    if (!beer) {
      skipped++;
      results.push({ epc, giai: null, bottle_num: null, status: 'skipped (not an event bottle)' });
      // Write feedback so display can show "tag not recognised" popup
      await supabase.from('rfid_feedback').insert({ epc, giai: null, event_type: 'invalid' });
      continue;
    }

    const { giai, bottle_num } = beer;

    const { error } = await supabase.from('rfid_events').insert({
      epc: normalizedEpc,
      giai,
      reader_id: readerId ?? 'advanreader',
      recycled_at: new Date().toISOString(),
    });

    if (error) {
      if (error.code === '23505') {
        // Unique constraint violation — already recorded (idempotent)
        duplicates++;
        results.push({ epc, giai, bottle_num, status: 'duplicate' });
      } else {
        results.push({ epc, giai, bottle_num, status: `error: ${error.message}` });
      }
    } else {
      recorded++;
      results.push({ epc, giai, bottle_num, status: 'recorded' });
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
