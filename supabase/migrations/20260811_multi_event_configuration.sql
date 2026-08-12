-- Reusable multi-location event configuration.
-- Product type is owned by the inventory batch: batch 1 and 2 are coffee.
BEGIN;

CREATE TABLE IF NOT EXISTS cup_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  product_mode TEXT NOT NULL CHECK (product_mode IN ('coffee','beer')),
  display_start INT NOT NULL DEFAULT 1,
  display_end INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO cup_batches(code,name,product_mode,display_start,display_end) VALUES
 ('coffee-batch-1','Kaffe – batch 1','coffee',1,2062),
 ('coffee-batch-2','Kaffe – batch 2','coffee',1,500)
ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, product_mode=EXCLUDED.product_mode,
 display_start=EXCLUDED.display_start, display_end=EXCLUDED.display_end;

ALTER TABLE beers ADD COLUMN IF NOT EXISTS batch_id UUID REFERENCES cup_batches(id),
 ADD COLUMN IF NOT EXISTS display_number INT;
UPDATE beers b SET batch_id=cb.id, display_number=CASE WHEN cb.code='coffee-batch-2' THEN b.bottle_num-4095 ELSE b.bottle_num END
FROM cup_batches cb WHERE cb.code=CASE WHEN b.bottle_num BETWEEN 4096 AND 4595 THEN 'coffee-batch-2' ELSE 'coffee-batch-1' END;
ALTER TABLE beers ALTER COLUMN batch_id SET NOT NULL;
ALTER TABLE beers ALTER COLUMN display_number SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS beers_batch_display_number_uniq ON beers(batch_id,display_number);

CREATE TABLE IF NOT EXISTS event_locations (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT NOT NULL UNIQUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS event_sessions (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT NOT NULL,
 location_id UUID NOT NULL REFERENCES event_locations(id), batch_id UUID NOT NULL REFERENCES cup_batches(id),
 reader_id TEXT NOT NULL DEFAULT 'advanreader', series_start INT NOT NULL, series_end INT NOT NULL,
 target_cups INT GENERATED ALWAYS AS (series_end-series_start+1) STORED,
 status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','closed')),
 started_at TIMESTAMPTZ NOT NULL DEFAULT now(), closed_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS event_one_active_reader_uniq ON event_sessions(reader_id) WHERE status='active';
CREATE TABLE IF NOT EXISTS event_cups (
 id BIGSERIAL PRIMARY KEY, event_id UUID NOT NULL REFERENCES event_sessions(id), cup_id BIGINT NOT NULL REFERENCES beers(id),
 display_number INT NOT NULL, status TEXT NOT NULL DEFAULT 'allocated' CHECK(status IN ('allocated','registered','recycled','released')),
 allocated_at TIMESTAMPTZ NOT NULL DEFAULT now(), registered_at TIMESTAMPTZ, recycled_at TIMESTAMPTZ, released_at TIMESTAMPTZ,
 UNIQUE(event_id,cup_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS event_cups_reserved_uniq ON event_cups(cup_id) WHERE status IN ('allocated','registered','recycled');
CREATE INDEX IF NOT EXISTS event_cups_event_idx ON event_cups(event_id,status);

ALTER TABLE registrations ADD COLUMN IF NOT EXISTS event_id UUID REFERENCES event_sessions(id), ADD COLUMN IF NOT EXISTS event_cup_id BIGINT REFERENCES event_cups(id);
ALTER TABLE rfid_events ADD COLUMN IF NOT EXISTS event_id UUID REFERENCES event_sessions(id), ADD COLUMN IF NOT EXISTS event_cup_id BIGINT REFERENCES event_cups(id);
ALTER TABLE rfid_feedback ADD COLUMN IF NOT EXISTS event_id UUID REFERENCES event_sessions(id);

CREATE OR REPLACE FUNCTION create_event_session(p_name TEXT,p_location TEXT,p_batch UUID,p_reader TEXT,p_start INT,p_end INT)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE l UUID; e UUID; wanted INT; available INT;
BEGIN
 IF coalesce(btrim(p_name),'')='' OR coalesce(btrim(p_location),'')='' OR coalesce(btrim(p_reader),'')='' OR p_start<1 OR p_end<p_start THEN RAISE EXCEPTION 'Invalid event details'; END IF;
 IF NOT EXISTS(SELECT 1 FROM cup_batches WHERE id=p_batch) THEN RAISE EXCEPTION 'Batch was not found'; END IF;
 IF EXISTS(SELECT 1 FROM event_sessions WHERE reader_id=btrim(p_reader) AND status='active') THEN RAISE EXCEPTION 'RFID reader already has an active event'; END IF;
 wanted:=p_end-p_start+1;
 SELECT count(*) INTO available FROM beers b WHERE b.batch_id=p_batch AND b.display_number BETWEEN p_start AND p_end AND NOT EXISTS(SELECT 1 FROM event_cups ec WHERE ec.cup_id=b.id AND ec.status IN ('allocated','registered','recycled'));
 IF available<>wanted THEN RAISE EXCEPTION 'Only % of % requested cups are available',available,wanted; END IF;
 INSERT INTO event_locations(name) VALUES(btrim(p_location)) ON CONFLICT(name) DO UPDATE SET name=EXCLUDED.name RETURNING id INTO l;
 INSERT INTO event_sessions(name,location_id,batch_id,reader_id,series_start,series_end) VALUES(btrim(p_name),l,p_batch,btrim(p_reader),p_start,p_end) RETURNING id INTO e;
 INSERT INTO event_cups(event_id,cup_id,display_number) SELECT e,id,display_number FROM beers WHERE batch_id=p_batch AND display_number BETWEEN p_start AND p_end;
 RETURN e;
END $$;

CREATE OR REPLACE FUNCTION close_event_session(p_event UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE released INT;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM event_sessions WHERE id=p_event AND status='active') THEN RAISE EXCEPTION 'Active event was not found'; END IF;
 UPDATE event_cups SET status='released',released_at=now() WHERE event_id=p_event AND status='allocated'; GET DIAGNOSTICS released=ROW_COUNT;
 UPDATE event_sessions SET status='closed',closed_at=now() WHERE id=p_event;
 RETURN jsonb_build_object('event_id',p_event,'released_unused_cups',released);
END $$;

GRANT SELECT ON cup_batches,event_locations,event_sessions,event_cups TO anon,authenticated;
GRANT EXECUTE ON FUNCTION create_event_session(TEXT,TEXT,UUID,TEXT,INT,INT),close_event_session(UUID) TO anon,authenticated;
ALTER TABLE event_sessions REPLICA IDENTITY FULL;
ALTER TABLE event_cups REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE event_sessions;
ALTER PUBLICATION supabase_realtime ADD TABLE event_cups;
NOTIFY pgrst,'reload schema';
COMMIT;
