-- ============================================================
-- GS1 Nordic Summit 2025 – Supabase Schema
-- Paste this entire file into the Supabase SQL Editor and run it.
-- Dashboard → SQL Editor → New query → paste → Run
-- ============================================================

-- 1. registrations: QR-scan registrations from mobile users
CREATE TABLE IF NOT EXISTS registrations (
  id            BIGSERIAL PRIMARY KEY,
  phone         TEXT NOT NULL,
  name          TEXT NOT NULL,
  company       TEXT,
  giai          TEXT NOT NULL,
  registered_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_reg_phone_giai ON registrations(phone, giai);
CREATE INDEX IF NOT EXISTS idx_reg_phone ON registrations(phone);
CREATE INDEX IF NOT EXISTS idx_reg_giai  ON registrations(giai);

-- 2. rfid_events: RFID pant events from Keonn AdvanReader
CREATE TABLE IF NOT EXISTS rfid_events (
  id          BIGSERIAL PRIMARY KEY,
  epc         TEXT NOT NULL,
  giai        TEXT,
  reader_id   TEXT DEFAULT 'advanreader-01',
  recycled_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_rfid_epc  ON rfid_events(epc);
CREATE INDEX IF NOT EXISTS idx_rfid_giai ON rfid_events(giai);

-- 3. milestones: Celebration milestones for the display screen
CREATE TABLE IF NOT EXISTS milestones (
  id           BIGSERIAL PRIMARY KEY,
  bottle_count INT NOT NULL UNIQUE,
  label        TEXT NOT NULL,
  emoji        TEXT NOT NULL,
  message      TEXT NOT NULL,
  celebrated   BOOLEAN DEFAULT FALSE
);
INSERT INTO milestones (bottle_count, label, emoji, message) VALUES
  (10,  'First 10!',     '🎉', 'Amazing start! The first 10 bottles have been recycled!'),
  (50,  'Halfway hero!', '🏆', '50 bottles recycled – you are sustainability champions!'),
  (100, 'Century!',      '🥂', '100 bottles recycled! A century of green action!'),
  (200, 'Two hundred!',  '🌿', '200 bottles recycled – an incredible effort!'),
  (300, 'Full house!',   '🎊', 'ALL 300 bottles recycled! GS1 Nordic Summit is the greenest event ever!')
ON CONFLICT (bottle_count) DO NOTHING;

-- 4. Enable Row Level Security
ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfid_events   ENABLE ROW LEVEL SECURITY;
ALTER TABLE milestones    ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies
-- NOTE: PostgreSQL does not support IF NOT EXISTS on CREATE POLICY.
-- Use DO $$ blocks to check before creating.
DO $$
BEGIN
  -- registrations: allow anyone to read
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'registrations' AND policyname = 'anon_read_registrations'
  ) THEN
    CREATE POLICY anon_read_registrations ON registrations FOR SELECT USING (true);
  END IF;

  -- registrations: allow anyone to insert (mobile QR scan page)
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'registrations' AND policyname = 'anon_insert_registrations'
  ) THEN
    CREATE POLICY anon_insert_registrations ON registrations FOR INSERT WITH CHECK (true);
  END IF;

  -- rfid_events: allow anyone to read
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'rfid_events' AND policyname = 'anon_read_rfid_events'
  ) THEN
    CREATE POLICY anon_read_rfid_events ON rfid_events FOR SELECT USING (true);
  END IF;

  -- rfid_events: allow service_role to insert (Keonn endpoint via backend)
  -- service_role bypasses RLS by default, so no explicit policy needed.

  -- milestones: allow anyone to read
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'milestones' AND policyname = 'anon_read_milestones'
  ) THEN
    CREATE POLICY anon_read_milestones ON milestones FOR SELECT USING (true);
  END IF;
END $$;

-- 6. Realtime: enable change tracking for all three tables
ALTER TABLE rfid_events   REPLICA IDENTITY FULL;
ALTER TABLE registrations REPLICA IDENTITY FULL;
ALTER TABLE milestones    REPLICA IDENTITY FULL;

-- Add tables to the Supabase realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE rfid_events;
ALTER PUBLICATION supabase_realtime ADD TABLE registrations;
ALTER PUBLICATION supabase_realtime ADD TABLE milestones;

-- 7. Verify – should return 3 rows with count 0
SELECT 'registrations' AS tbl, COUNT(*) FROM registrations
UNION ALL SELECT 'rfid_events',  COUNT(*) FROM rfid_events
UNION ALL SELECT 'milestones',   COUNT(*) FROM milestones;
