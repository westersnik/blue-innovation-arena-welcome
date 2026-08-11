# Incident note: RFID cup numbers on `storskjerm.html`

**Date:** 11 August 2026  
**Status:** Resolved and published  
**Scope:** Digi-Coffee batch 1 and batch 2 RFID recycling feed

## Short explanation

RFID events were successfully stored in Supabase, but the big-screen page still used the original batch-1 numbering formula and a maximum of 300 cups. Batch 2 therefore had no accepted display number, which produced `Kopp #null` in the feed. The fix makes the display batch-aware: batch 2 starts from **Kopp #1**, not #2054.

## Observed behavior

The AdvanReader sent valid EPCs to the `rfid-relay` Edge Function. The function found the EPCs in the `beers` catalogue and inserted rows into `rfid_events`; therefore the reader-to-database pipeline was operating correctly. [1]

The affected behavior was entirely in the browser display. Recent batch-2 events were present in Supabase, but the screen either rendered `Kopp #null` or did not include the event in the live feed because the previous mapping only considered numbers from 1 through 300. [2]

| Example RFID event | Expected batch-2 display | Previous behavior |
|---|---:|---|
| GIAI `70735394096`, EPC ending `01000` | Kopp #1 | `Kopp #null` or omitted |
| GIAI `70735394097`, EPC ending `01001` | Kopp #2 | `Kopp #null` |
| GIAI `70735394242`, EPC ending `01092` | Kopp #147 | `Kopp #null` or omitted |
| GIAI `70735394245`, EPC ending `01095` | Kopp #150 | `Kopp #null` or omitted |

## Root cause

The original screen calculated the number as `GIAI − 70735392042`, which is the correct formula only for the first batch. It then accepted only values from 1 to 300. Batch 2 starts at GIAI `70735394096`; this would result in #2054 when the batch-1 formula is used, rather than the intended #1.

The first nine batch-2 GIAIs overlap with the tail end of batch 1 (`70735394096` through `70735394104`). The GIAI value alone is therefore not sufficient as the event identity during the overlap. The associated EPC identifies the physical RFID tag and must be retained for both de-duplication and batch selection. The current catalogue represents the overlapping tags with 24-character EPCs in batch 2 and 25-character EPCs in the prior batch.

> **Important:** An RFID event is stored using the EPC received from the reader. The event display must use that EPC as the physical tag identity, not only the GIAI.

## Technical correction

`storskjerm.html` now contains a dedicated `cupNumberForEvent(giai, epc)` helper. It uses the following mapping. [2]

| Event batch | GIAI range | Displayed cup number |
|---|---|---:|
| Batch 1 | `70735392043`–`70735394104` | #1–#2062 |
| Batch 2 | `70735394096`–`70735394595` | #1–#500 |

For the nine overlapping GIAIs, the helper identifies batch 2 from the current 24-character EPC representation; the 25-character representation remains mapped to batch 1. All other batch-2 GIAIs use their batch-2 range directly.

The implementation also makes four related changes:

1. It retrieves RFID events through the full batch-2 end value, `70735394595`, rather than stopping at the former batch-1 end value.
2. It uses an EPC-based key (`epc:<value>`) to de-duplicate RFID events. This prevents two physical tags with an overlapping GIAI from being incorrectly treated as the same recycling event.
3. It inserts a feed item only after a valid cup number has been determined, preventing `Kopp #null` from appearing.
4. It applies the same mapping to the initial Supabase load and to the real-time insert subscription, so a hard refresh and a live read give the same result.

## Validation

A focused Node regression test verifies the expected mapping for batch 1, the overlapping batch-2 start, ordinary batch-2 events, the batch-2 end, and a GIAI outside both ranges. [3]

The live page was checked after a cache-busting hard refresh. The feed showed the following correct values: `70735394242` as **Kopp #147**, `70735394245` as **Kopp #150**, `70735394241` as **Kopp #146**, `70735394097` as **Kopp #2**, and `70735394240` as **Kopp #145**.

## Operational note

The RFID recycling counter can be higher than the number of registered cups when unregistered cups are recycled. This may show a recycle rate above 100%; it is separate from the cup-numbering correction documented here.

## References

[1]: ../supabase/functions/rfid-relay/index.ts "rfid-relay Edge Function"
[2]: ../storskjerm.html "Batch-aware RFID event rendering"
[3]: ../tests/storskjerm-numbering.test.mjs "Batch-numbering regression test"
