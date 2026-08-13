-- Welcome Events: event-scoped RFID tags with a personal welcome message.
-- Prerequisite: the existing `beers` table is the physical RFID-tag catalogue.
-- This migration intentionally uses separate tables and does not alter the Digi-Coffee lifecycle.
BEGIN;

CREATE TABLE IF NOT EXISTS welcome_tag_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  display_start INT NOT NULL DEFAULT 1 CHECK (display_start >= 1),
  display_end INT NOT NULL CHECK (display_end >= display_start),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed matching RFID-tag batches from the existing physical catalogue.
INSERT INTO welcome_tag_batches (code, name, display_start, display_end)
VALUES
  ('rfid-batch-1', 'RFID-tag batch 1', 1, 2062),
  ('rfid-batch-2', 'RFID-tag batch 2', 1, 500)
ON CONFLICT (code) DO UPDATE
  SET name = EXCLUDED.name,
      display_start = EXCLUDED.display_start,
      display_end = EXCLUDED.display_end;

CREATE TABLE IF NOT EXISTS welcome_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS welcome_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  location_id UUID NOT NULL REFERENCES welcome_locations(id),
  batch_id UUID NOT NULL REFERENCES welcome_tag_batches(id),
  reader_id TEXT NOT NULL DEFAULT 'advanreader',
  series_start INT NOT NULL CHECK (series_start >= 1),
  series_end INT NOT NULL CHECK (series_end >= series_start),
  target_tags INT GENERATED ALWAYS AS (series_end - series_start + 1) STORED,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed')),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS welcome_one_active_reader_uniq
  ON welcome_events(reader_id) WHERE status = 'active';

CREATE TABLE IF NOT EXISTS welcome_event_tags (
  id BIGSERIAL PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES welcome_events(id),
  tag_id BIGINT NOT NULL REFERENCES beers(id),
  display_number INT NOT NULL,
  status TEXT NOT NULL DEFAULT 'available'
    CHECK (status IN ('available', 'assigned', 'welcomed', 'released')),
  allocated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  assigned_at TIMESTAMPTZ,
  welcomed_at TIMESTAMPTZ,
  released_at TIMESTAMPTZ,
  UNIQUE (event_id, tag_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS welcome_reserved_tag_uniq
  ON welcome_event_tags(tag_id) WHERE status IN ('available', 'assigned', 'welcomed');
CREATE INDEX IF NOT EXISTS welcome_event_tags_event_status_idx
  ON welcome_event_tags(event_id, status);

CREATE TABLE IF NOT EXISTS welcome_guests (
  id BIGSERIAL PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES welcome_events(id),
  event_tag_id BIGINT NOT NULL REFERENCES welcome_event_tags(id),
  name TEXT NOT NULL CHECK (btrim(name) <> ''),
  company TEXT,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  welcomed_at TIMESTAMPTZ,
  last_seen_at TIMESTAMPTZ,
  UNIQUE (event_tag_id)
);
CREATE INDEX IF NOT EXISTS welcome_guests_event_idx ON welcome_guests(event_id);

-- The denormalized name and company make the realtime display independent of a second browser lookup.
CREATE TABLE IF NOT EXISTS welcome_scans (
  id BIGSERIAL PRIMARY KEY,
  event_id UUID NOT NULL REFERENCES welcome_events(id),
  event_tag_id BIGINT NOT NULL REFERENCES welcome_event_tags(id),
  guest_id BIGINT NOT NULL REFERENCES welcome_guests(id),
  epc TEXT NOT NULL,
  reader_id TEXT NOT NULL,
  guest_name TEXT NOT NULL,
  guest_company TEXT,
  scanned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (event_tag_id)
);
CREATE INDEX IF NOT EXISTS welcome_scans_event_time_idx
  ON welcome_scans(event_id, scanned_at DESC);

CREATE TABLE IF NOT EXISTS welcome_feedback (
  id BIGSERIAL PRIMARY KEY,
  event_id UUID REFERENCES welcome_events(id),
  epc TEXT,
  reader_id TEXT,
  reason TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION create_welcome_event(
  p_name TEXT,
  p_location TEXT,
  p_batch UUID,
  p_reader TEXT,
  p_start INT,
  p_end INT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  l UUID;
  e UUID;
  wanted INT;
  available INT;
BEGIN
  IF coalesce(btrim(p_name), '') = ''
     OR coalesce(btrim(p_location), '') = ''
     OR coalesce(btrim(p_reader), '') = ''
     OR p_start < 1
     OR p_end < p_start THEN
    RAISE EXCEPTION 'Invalid welcome event details';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM welcome_tag_batches WHERE id = p_batch) THEN
    RAISE EXCEPTION 'RFID-tag batch was not found';
  END IF;

  IF EXISTS (SELECT 1 FROM welcome_events WHERE reader_id = btrim(p_reader) AND status = 'active') THEN
    RAISE EXCEPTION 'RFID reader already has an active welcome event';
  END IF;

  wanted := p_end - p_start + 1;
  SELECT count(*) INTO available
  FROM beers b
  JOIN welcome_tag_batches wb ON wb.id = p_batch
  WHERE b.display_number BETWEEN p_start AND p_end
    AND (
      (wb.code = 'rfid-batch-1' AND b.bottle_num NOT BETWEEN 4096 AND 4595)
      OR (wb.code = 'rfid-batch-2' AND b.bottle_num BETWEEN 4096 AND 4595)
    )
    AND NOT EXISTS (
      SELECT 1 FROM welcome_event_tags wet
      WHERE wet.tag_id = b.id
        AND wet.status IN ('available', 'assigned', 'welcomed')
    );

  IF available <> wanted THEN
    RAISE EXCEPTION 'Only % of % requested RFID tags are available', available, wanted;
  END IF;

  INSERT INTO welcome_locations(name)
  VALUES (btrim(p_location))
  ON CONFLICT(name) DO UPDATE SET name = EXCLUDED.name
  RETURNING id INTO l;

  INSERT INTO welcome_events(name, location_id, batch_id, reader_id, series_start, series_end)
  VALUES (btrim(p_name), l, p_batch, btrim(p_reader), p_start, p_end)
  RETURNING id INTO e;

  INSERT INTO welcome_event_tags(event_id, tag_id, display_number)
  SELECT e, b.id, b.display_number
  FROM beers b
  JOIN welcome_tag_batches wb ON wb.id = p_batch
  WHERE b.display_number BETWEEN p_start AND p_end
    AND (
      (wb.code = 'rfid-batch-1' AND b.bottle_num NOT BETWEEN 4096 AND 4595)
      OR (wb.code = 'rfid-batch-2' AND b.bottle_num BETWEEN 4096 AND 4595)
    );

  RETURN e;
END;
$$;

CREATE OR REPLACE FUNCTION assign_welcome_guest(
  p_event UUID,
  p_display_number INT,
  p_name TEXT,
  p_company TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_tag_id BIGINT;
  v_guest_id BIGINT;
BEGIN
  IF coalesce(btrim(p_name), '') = '' THEN
    RAISE EXCEPTION 'Guest name is required';
  END IF;

  SELECT wet.id INTO v_event_tag_id
  FROM welcome_event_tags wet
  JOIN welcome_events we ON we.id = wet.event_id
  WHERE wet.event_id = p_event
    AND wet.display_number = p_display_number
    AND wet.status = 'available'
    AND we.status = 'active'
  FOR UPDATE;

  IF v_event_tag_id IS NULL THEN
    RAISE EXCEPTION 'RFID tag is unavailable, already assigned, or the event is closed';
  END IF;

  INSERT INTO welcome_guests(event_id, event_tag_id, name, company)
  VALUES (p_event, v_event_tag_id, btrim(p_name), nullif(btrim(p_company), ''))
  RETURNING id INTO v_guest_id;

  UPDATE welcome_event_tags
  SET status = 'assigned', assigned_at = now()
  WHERE id = v_event_tag_id;

  RETURN v_guest_id;
END;
$$;

-- Invoked by the welcome-rfid-relay with a service-role connection.
-- A tag can trigger one welcome per event; reader repeats are idempotent.
CREATE OR REPLACE FUNCTION record_welcome_scan(
  p_reader TEXT,
  p_epc TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event welcome_events%ROWTYPE;
  v_tag_id BIGINT;
  v_event_tag welcome_event_tags%ROWTYPE;
  v_guest welcome_guests%ROWTYPE;
  v_scan_id BIGINT;
BEGIN
  SELECT * INTO v_event
  FROM welcome_events
  WHERE reader_id = btrim(p_reader) AND status = 'active';

  IF v_event.id IS NULL THEN
    RAISE EXCEPTION 'No active welcome event for this RFID reader';
  END IF;

  SELECT id INTO v_tag_id
  FROM beers
  WHERE upper(epc) = upper(btrim(p_epc));

  IF v_tag_id IS NULL THEN
    RAISE EXCEPTION 'RFID tag is not in the tag catalogue';
  END IF;

  SELECT * INTO v_event_tag
  FROM welcome_event_tags
  WHERE event_id = v_event.id AND tag_id = v_tag_id
  FOR UPDATE;

  IF v_event_tag.id IS NULL THEN
    RAISE EXCEPTION 'RFID tag is not allocated to the active welcome event';
  END IF;

  SELECT * INTO v_guest
  FROM welcome_guests
  WHERE event_tag_id = v_event_tag.id;

  IF v_guest.id IS NULL THEN
    RAISE EXCEPTION 'RFID tag is not assigned to a guest';
  END IF;

  INSERT INTO welcome_scans(event_id, event_tag_id, guest_id, epc, reader_id, guest_name, guest_company)
  VALUES (v_event.id, v_event_tag.id, v_guest.id, upper(btrim(p_epc)), btrim(p_reader), v_guest.name, v_guest.company)
  ON CONFLICT (event_tag_id) DO NOTHING
  RETURNING id INTO v_scan_id;

  IF v_scan_id IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'duplicate',
      'event_id', v_event.id,
      'guest_name', v_guest.name,
      'guest_company', v_guest.company
    );
  END IF;

  UPDATE welcome_event_tags
  SET status = 'welcomed', welcomed_at = now()
  WHERE id = v_event_tag.id;

  UPDATE welcome_guests
  SET welcomed_at = now(), last_seen_at = now()
  WHERE id = v_guest.id;

  RETURN jsonb_build_object(
    'status', 'recorded',
    'scan_id', v_scan_id,
    'event_id', v_event.id,
    'guest_name', v_guest.name,
    'guest_company', v_guest.company
  );
END;
$$;

CREATE OR REPLACE FUNCTION close_welcome_event(p_event UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  released INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM welcome_events WHERE id = p_event AND status = 'active') THEN
    RAISE EXCEPTION 'Active welcome event was not found';
  END IF;

  UPDATE welcome_event_tags
  SET status = 'released', released_at = now()
  WHERE event_id = p_event AND status = 'available';
  GET DIAGNOSTICS released = ROW_COUNT;

  UPDATE welcome_events
  SET status = 'closed', closed_at = now()
  WHERE id = p_event;

  RETURN jsonb_build_object('event_id', p_event, 'released_unassigned_tags', released);
END;
$$;

GRANT SELECT ON welcome_tag_batches, welcome_locations, welcome_events, welcome_event_tags, welcome_guests, welcome_scans TO anon, authenticated;
GRANT EXECUTE ON FUNCTION create_welcome_event(TEXT, TEXT, UUID, TEXT, INT, INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION assign_welcome_guest(UUID, INT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION close_welcome_event(UUID) TO anon, authenticated;

ALTER TABLE welcome_events REPLICA IDENTITY FULL;
ALTER TABLE welcome_event_tags REPLICA IDENTITY FULL;
ALTER TABLE welcome_scans REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE welcome_events;
ALTER PUBLICATION supabase_realtime ADD TABLE welcome_event_tags;
ALTER PUBLICATION supabase_realtime ADD TABLE welcome_scans;
NOTIFY pgrst, 'reload schema';
COMMIT;
