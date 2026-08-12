# Project TODO

- [x] Diagnose why recent RFID events render as `Kopp #null` on storskjerm.html.
- [x] Apply batch-aware cup-number mapping on storskjerm.html for batch 1 and batch 2.
- [x] Validate the rendered feed against the recent Supabase RFID events.
- [x] Commit and publish the corrected storskjerm display.
- [x] Document the storskjerm RFID cup-number issue, root cause, and technical correction in GitHub.
- [x] Define multi-event data model for locations, event states, cup ranges, and allocated cup count.
- [x] Superseded: create a protected configuration page; the requested implementation is an open configuration page.
- [x] Add an explicit confirmation dialog before an active event can be closed.
- [x] Preserve unused cups after event closure so they can be assigned to a later event.
- [x] Scope RFID ingestion, registrations, and storskjerm statistics to the active event.
- [x] Add configurable progress-bar behavior based on the event cup target.
- [x] Evaluate and document reusable coffee-cup and beer product modes.
- [x] Test the GS1 demo scenario where 50 of 200 allocated cups are used, then close and reuse remaining cups.
- [x] Make the event configuration page openly accessible without user login.
- [x] Include coffee and beer as supported product modes in event configuration.
- [x] Preserve batch 1 and batch 2 as coffee batches, and require every future batch to declare coffee or beer.
