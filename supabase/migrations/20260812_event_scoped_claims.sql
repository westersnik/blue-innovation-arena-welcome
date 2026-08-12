-- Event-scoped QR registration. This preserves legacy registrations while
-- ensuring a physical cup can be claimed only once in a configured event.
BEGIN;

CREATE UNIQUE INDEX IF NOT EXISTS registrations_event_cup_uniq
  ON registrations(event_cup_id)
  WHERE event_cup_id IS NOT NULL;

CREATE OR REPLACE FUNCTION claim_event_cup(
  p_event UUID,
  p_giai TEXT,
  p_phone TEXT,
  p_name TEXT,
  p_company TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_cup_id BIGINT;
  v_cup_giai TEXT;
  v_existing_name TEXT;
BEGIN
  SELECT ec.id, b.giai
  INTO v_event_cup_id, v_cup_giai
  FROM event_cups ec
  JOIN beers b ON b.id = ec.cup_id
  JOIN event_sessions e ON e.id = ec.event_id
  WHERE ec.event_id = p_event
    AND b.giai = p_giai
    AND e.status = 'active'
  FOR UPDATE OF ec;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Koppen er ikke tilgjengelig i det aktive arrangementet';
  END IF;

  SELECT name INTO v_existing_name
  FROM registrations
  WHERE event_cup_id = v_event_cup_id
  LIMIT 1;

  IF v_existing_name IS NOT NULL THEN
    RAISE EXCEPTION 'Koppen er allerede registrert på %', v_existing_name;
  END IF;

  IF EXISTS (SELECT 1 FROM rfid_events WHERE event_cup_id = v_event_cup_id) THEN
    RAISE EXCEPTION 'Koppen er allerede resirkulert og kan ikke registreres';
  END IF;

  INSERT INTO registrations(phone, name, company, giai, event_id, event_cup_id)
  VALUES (COALESCE(NULLIF(BTRIM(p_phone), ''), 'ingen-telefon'), BTRIM(p_name), NULLIF(BTRIM(p_company), ''), v_cup_giai, p_event, v_event_cup_id);

  UPDATE event_cups
  SET status = 'registered', registered_at = NOW()
  WHERE id = v_event_cup_id AND status = 'allocated';

  RETURN jsonb_build_object('event_cup_id', v_event_cup_id, 'giai', v_cup_giai);
END;
$$;

GRANT EXECUTE ON FUNCTION claim_event_cup(UUID, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
