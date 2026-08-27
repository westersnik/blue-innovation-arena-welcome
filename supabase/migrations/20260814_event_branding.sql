-- Event branding: a logo can be selected for each Event Welcome screen.
BEGIN;

ALTER TABLE welcome_events
  ADD COLUMN IF NOT EXISTS logo_url TEXT;

CREATE OR REPLACE FUNCTION set_welcome_event_logo(
  p_event UUID,
  p_logo_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_url TEXT := nullif(btrim(p_logo_url), '');
BEGIN
  IF normalized_url IS NOT NULL
     AND normalized_url !~ '^(https://|assets/logos/)' THEN
    RAISE EXCEPTION 'Logo URL must use HTTPS or a bundled assets/logos path';
  END IF;

  UPDATE welcome_events
  SET logo_url = normalized_url
  WHERE id = p_event;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Welcome event was not found';
  END IF;

  RETURN jsonb_build_object('event_id', p_event, 'logo_url', normalized_url);
END;
$$;

GRANT EXECUTE ON FUNCTION set_welcome_event_logo(UUID, TEXT) TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
