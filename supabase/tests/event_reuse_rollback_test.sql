-- Rollback-only proof of the GS1 scenario. No data persists after this script.
BEGIN;

CREATE TEMP TABLE test_event_ids (
  first_event UUID,
  second_event UUID
) ON COMMIT DROP;

INSERT INTO test_event_ids(first_event)
SELECT create_event_session(
  'Rollback test 1', 'Testlokasjon',
  (SELECT id FROM cup_batches WHERE code = 'coffee-batch-1'),
  'test-reader-rollback-1', 50, 249
);

-- Mark 50 of the 200 allocated cups as used.
UPDATE event_cups
SET status = 'registered', registered_at = NOW()
WHERE id IN (
  SELECT id FROM event_cups
  WHERE event_id = (SELECT first_event FROM test_event_ids LIMIT 1)
  ORDER BY display_number
  LIMIT 50
);

SELECT close_event_session((SELECT first_event FROM test_event_ids LIMIT 1)) AS close_summary;

-- The released cups 100–249 are available for a later event.
UPDATE test_event_ids
SET second_event = create_event_session(
  'Rollback test 2', 'Testlokasjon',
  (SELECT id FROM cup_batches WHERE code = 'coffee-batch-1'),
  'test-reader-rollback-2', 100, 249
);

SELECT status, COUNT(*) AS cups
FROM event_cups
WHERE event_id = (SELECT first_event FROM test_event_ids LIMIT 1)
GROUP BY status
ORDER BY status;

SELECT COUNT(*) AS reusable_cups_in_second_event
FROM event_cups
WHERE event_id = (SELECT second_event FROM test_event_ids LIMIT 1);

ROLLBACK;
