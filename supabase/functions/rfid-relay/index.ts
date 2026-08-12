/**
 * Supabase Edge Function: rfid-relay
 *
 * Accepts POST from Keonn AdvanReader (SimpleHTTPService) and writes
 * EPC tag reads to the rfid_events table using the service role key.
 *
 * EPC validation is done by looking up the EPC in the `beers` table.
 * A valid read must also belong to the active event configured for the reader.
 * All other tags are written to rfid_feedback with their rejection reason.
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

  // Fetch all EPCs from the physical inventory catalogue in one query.
  const epcList = rawTags.map(t => t.epc.toUpperCase());
  const { data: beerRows, error: beerLookupError } = await supabase
    .from('beers')
    .select('id, epc, giai, bottle_num, batch_id, display_number')
    .in('epc', epcList);

  if (beerLookupError) {
    return new Response(JSON.stringify({ error: `Cup catalogue lookup failed: ${beerLookupError.message}` }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  // Build a map: EPC → physical inventory record.
  const beerMap: Record<string, { id: number; giai: string; bottle_num: number; batch_id: string; display_number: number }> = {};
  if (beerRows) {
    for (const row of beerRows) {
      beerMap[row.epc.toUpperCase()] = {
        id: row.id,
        giai: row.giai,
        bottle_num: row.bottle_num,
        batch_id: row.batch_id,
        display_number: row.display_number,
      };
    }
  }

  // One reader can have one active event. The reader ID is selected on the
  // configuration page, so different locations can run independently.
  const readerIds = [...new Set(rawTags.map(t => String(t.readerId ?? 'advanreader')))];
  const { data: activeEvents, error: activeEventError } = await supabase
    .from('event_sessions')
    .select('id, reader_id, batch_id')
    .eq('status', 'active')
    .in('reader_id', readerIds);

  if (activeEventError) {
    return new Response(JSON.stringify({ error: `Active event lookup failed: ${activeEventError.message}` }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const activeEventByReader: Record<string, { id: string; batch_id: string }> = {};
  for (const event of activeEvents ?? []) {
    activeEventByReader[event.reader_id] = { id: event.id, batch_id: event.batch_id };
  }
  // Existing installations keep their legacy behavior until a configuration
  // page has started an event for that reader. Once an active event exists,
  // RFID reads are strictly scoped to its allocated cups.
  const hasConfiguredActiveEvent = (activeEvents ?? []).length > 0;

  const results: Array<{ epc: string; giai: string | null; bottle_num: number | null; display_number: number | null; event_id: string | null; status: string }> = [];
  let recorded = 0;
  let duplicates = 0;
  let skipped = 0;

  for (const { epc, readerId } of rawTags) {
    const normalizedEpc = epc.toUpperCase();
    const beer = beerMap[normalizedEpc];
    const normalizedReaderId = String(readerId ?? 'advanreader');
    const activeEvent = activeEventByReader[normalizedReaderId];

    // Not in the physical inventory catalogue.
    if (!beer) {
      skipped++;
      results.push({ epc, giai: null, bottle_num: null, display_number: null, event_id: null, status: 'skipped (not in cup catalogue)' });
      await supabase.from('rfid_feedback').insert({ epc, giai: null, event_type: 'invalid' });
      continue;
    }

    const { id: cupId, giai, bottle_num, batch_id, display_number } = beer;

    // When configuration is in use, the reader must be assigned to an active event.
    if (!activeEvent && hasConfiguredActiveEvent) {
      skipped++;
      results.push({ epc, giai, bottle_num, display_number, event_id: null, status: 'skipped (no active event for reader)' });
      await supabase.from('rfid_feedback').insert({ epc: normalizedEpc, giai, event_type: 'no_active_event' });
      continue;
    }

    // No configured event yet: preserve the established eventless ingestion flow.
    if (!activeEvent) {
      const { error } = await supabase.from('rfid_events').insert({
        epc: normalizedEpc,
        giai,
        reader_id: normalizedReaderId,
        recycled_at: new Date().toISOString(),
      });
      if (error) {
        if (error.code === '23505') {
          duplicates++;
          results.push({ epc, giai, bottle_num, display_number, event_id: null, status: 'duplicate' });
        } else {
          results.push({ epc, giai, bottle_num, display_number, event_id: null, status: `error: ${error.message}` });
        }
      } else {
        recorded++;
        results.push({ epc, giai, bottle_num, display_number, event_id: null, status: 'recorded (legacy mode)' });
      }
      continue;
    }

    // A coffee event cannot record an RFID tag from a beer batch, and vice versa.
    if (activeEvent.batch_id !== batch_id) {
      skipped++;
      results.push({ epc, giai, bottle_num, display_number, event_id: activeEvent.id, status: 'skipped (cup belongs to another batch)' });
      await supabase.from('rfid_feedback').insert({ epc: normalizedEpc, giai, event_id: activeEvent.id, event_type: 'outside_event_batch' });
      continue;
    }

    // Check that the cup is part of this event's allocated number range.
    const { data: eventCup, error: eventCupError } = await supabase
      .from('event_cups')
      .select('id, status')
      .eq('event_id', activeEvent.id)
      .eq('cup_id', cupId)
      .in('status', ['allocated', 'registered'])
      .maybeSingle();

    if (eventCupError || !eventCup) {
      skipped++;
      results.push({ epc, giai, bottle_num, display_number, event_id: activeEvent.id, status: 'skipped (cup is not available in active event)' });
      await supabase.from('rfid_feedback').insert({ epc: normalizedEpc, giai, event_id: activeEvent.id, event_type: 'outside_event_range' });
      continue;
    }

    const { error } = await supabase.from('rfid_events').insert({
      epc: normalizedEpc,
      giai,
      reader_id: normalizedReaderId,
      event_id: activeEvent.id,
      event_cup_id: eventCup.id,
      recycled_at: new Date().toISOString(),
    });

    if (error) {
      if (error.code === '23505') {
        // Unique constraint violation — already recorded (idempotent)
        duplicates++;
        results.push({ epc, giai, bottle_num, display_number, event_id: activeEvent.id, status: 'duplicate' });
      } else {
        results.push({ epc, giai, bottle_num, display_number, event_id: activeEvent.id, status: `error: ${error.message}` });
      }
    } else {
      await supabase.from('event_cups').update({
        status: 'recycled',
        recycled_at: new Date().toISOString(),
      }).eq('id', eventCup.id);
      recorded++;
      results.push({ epc, giai, bottle_num, display_number, event_id: activeEvent.id, status: 'recorded' });
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
