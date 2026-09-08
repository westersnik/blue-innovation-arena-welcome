-- Import: Invig X ÅKP GIAI-96 RFID tags 4596–4695.
-- Source: InvigXAKP-GIAI-encoding-100tags-EN.xlsx
-- Verified before import: 100 unique GIAI-96 EPCs, 7-digit company prefix 7073539.
-- The printed label number is batch-local (1–100); bottle_num remains globally unique.
BEGIN;

ALTER TABLE beers
  ADD COLUMN IF NOT EXISTS display_number INT;

UPDATE beers
SET display_number = bottle_num
WHERE display_number IS NULL;

ALTER TABLE beers
  ALTER COLUMN display_number SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS beers_batch_display_number_uniq
  ON beers(welcome_batch_code, display_number);

INSERT INTO welcome_tag_batches (code, name, display_start, display_end)
VALUES ('invig-akp-giai-4596-4695', 'Invig X ÅKP GIAI 4596–4695', 1, 100)
ON CONFLICT (code) DO UPDATE
  SET name = EXCLUDED.name,
      display_start = EXCLUDED.display_start,
      display_end = EXCLUDED.display_end;

INSERT INTO beers (bottle_num, display_number, giai, epc, url, welcome_batch_code)
VALUES
  (301, 1, '70735394596', '3415AFBC0C000000000011F4', 'https://id.invig.no/8004/70735394596', 'invig-akp-giai-4596-4695'),
  (302, 2, '70735394597', '3415AFBC0C000000000011F5', 'https://id.invig.no/8004/70735394597', 'invig-akp-giai-4596-4695'),
  (303, 3, '70735394598', '3415AFBC0C000000000011F6', 'https://id.invig.no/8004/70735394598', 'invig-akp-giai-4596-4695'),
  (304, 4, '70735394599', '3415AFBC0C000000000011F7', 'https://id.invig.no/8004/70735394599', 'invig-akp-giai-4596-4695'),
  (305, 5, '70735394600', '3415AFBC0C000000000011F8', 'https://id.invig.no/8004/70735394600', 'invig-akp-giai-4596-4695'),
  (306, 6, '70735394601', '3415AFBC0C000000000011F9', 'https://id.invig.no/8004/70735394601', 'invig-akp-giai-4596-4695'),
  (307, 7, '70735394602', '3415AFBC0C000000000011FA', 'https://id.invig.no/8004/70735394602', 'invig-akp-giai-4596-4695'),
  (308, 8, '70735394603', '3415AFBC0C000000000011FB', 'https://id.invig.no/8004/70735394603', 'invig-akp-giai-4596-4695'),
  (309, 9, '70735394604', '3415AFBC0C000000000011FC', 'https://id.invig.no/8004/70735394604', 'invig-akp-giai-4596-4695'),
  (310, 10, '70735394605', '3415AFBC0C000000000011FD', 'https://id.invig.no/8004/70735394605', 'invig-akp-giai-4596-4695'),
  (311, 11, '70735394606', '3415AFBC0C000000000011FE', 'https://id.invig.no/8004/70735394606', 'invig-akp-giai-4596-4695'),
  (312, 12, '70735394607', '3415AFBC0C000000000011FF', 'https://id.invig.no/8004/70735394607', 'invig-akp-giai-4596-4695'),
  (313, 13, '70735394608', '3415AFBC0C00000000001200', 'https://id.invig.no/8004/70735394608', 'invig-akp-giai-4596-4695'),
  (314, 14, '70735394609', '3415AFBC0C00000000001201', 'https://id.invig.no/8004/70735394609', 'invig-akp-giai-4596-4695'),
  (315, 15, '70735394610', '3415AFBC0C00000000001202', 'https://id.invig.no/8004/70735394610', 'invig-akp-giai-4596-4695'),
  (316, 16, '70735394611', '3415AFBC0C00000000001203', 'https://id.invig.no/8004/70735394611', 'invig-akp-giai-4596-4695'),
  (317, 17, '70735394612', '3415AFBC0C00000000001204', 'https://id.invig.no/8004/70735394612', 'invig-akp-giai-4596-4695'),
  (318, 18, '70735394613', '3415AFBC0C00000000001205', 'https://id.invig.no/8004/70735394613', 'invig-akp-giai-4596-4695'),
  (319, 19, '70735394614', '3415AFBC0C00000000001206', 'https://id.invig.no/8004/70735394614', 'invig-akp-giai-4596-4695'),
  (320, 20, '70735394615', '3415AFBC0C00000000001207', 'https://id.invig.no/8004/70735394615', 'invig-akp-giai-4596-4695'),
  (321, 21, '70735394616', '3415AFBC0C00000000001208', 'https://id.invig.no/8004/70735394616', 'invig-akp-giai-4596-4695'),
  (322, 22, '70735394617', '3415AFBC0C00000000001209', 'https://id.invig.no/8004/70735394617', 'invig-akp-giai-4596-4695'),
  (323, 23, '70735394618', '3415AFBC0C0000000000120A', 'https://id.invig.no/8004/70735394618', 'invig-akp-giai-4596-4695'),
  (324, 24, '70735394619', '3415AFBC0C0000000000120B', 'https://id.invig.no/8004/70735394619', 'invig-akp-giai-4596-4695'),
  (325, 25, '70735394620', '3415AFBC0C0000000000120C', 'https://id.invig.no/8004/70735394620', 'invig-akp-giai-4596-4695'),
  (326, 26, '70735394621', '3415AFBC0C0000000000120D', 'https://id.invig.no/8004/70735394621', 'invig-akp-giai-4596-4695'),
  (327, 27, '70735394622', '3415AFBC0C0000000000120E', 'https://id.invig.no/8004/70735394622', 'invig-akp-giai-4596-4695'),
  (328, 28, '70735394623', '3415AFBC0C0000000000120F', 'https://id.invig.no/8004/70735394623', 'invig-akp-giai-4596-4695'),
  (329, 29, '70735394624', '3415AFBC0C00000000001210', 'https://id.invig.no/8004/70735394624', 'invig-akp-giai-4596-4695'),
  (330, 30, '70735394625', '3415AFBC0C00000000001211', 'https://id.invig.no/8004/70735394625', 'invig-akp-giai-4596-4695'),
  (331, 31, '70735394626', '3415AFBC0C00000000001212', 'https://id.invig.no/8004/70735394626', 'invig-akp-giai-4596-4695'),
  (332, 32, '70735394627', '3415AFBC0C00000000001213', 'https://id.invig.no/8004/70735394627', 'invig-akp-giai-4596-4695'),
  (333, 33, '70735394628', '3415AFBC0C00000000001214', 'https://id.invig.no/8004/70735394628', 'invig-akp-giai-4596-4695'),
  (334, 34, '70735394629', '3415AFBC0C00000000001215', 'https://id.invig.no/8004/70735394629', 'invig-akp-giai-4596-4695'),
  (335, 35, '70735394630', '3415AFBC0C00000000001216', 'https://id.invig.no/8004/70735394630', 'invig-akp-giai-4596-4695'),
  (336, 36, '70735394631', '3415AFBC0C00000000001217', 'https://id.invig.no/8004/70735394631', 'invig-akp-giai-4596-4695'),
  (337, 37, '70735394632', '3415AFBC0C00000000001218', 'https://id.invig.no/8004/70735394632', 'invig-akp-giai-4596-4695'),
  (338, 38, '70735394633', '3415AFBC0C00000000001219', 'https://id.invig.no/8004/70735394633', 'invig-akp-giai-4596-4695'),
  (339, 39, '70735394634', '3415AFBC0C0000000000121A', 'https://id.invig.no/8004/70735394634', 'invig-akp-giai-4596-4695'),
  (340, 40, '70735394635', '3415AFBC0C0000000000121B', 'https://id.invig.no/8004/70735394635', 'invig-akp-giai-4596-4695'),
  (341, 41, '70735394636', '3415AFBC0C0000000000121C', 'https://id.invig.no/8004/70735394636', 'invig-akp-giai-4596-4695'),
  (342, 42, '70735394637', '3415AFBC0C0000000000121D', 'https://id.invig.no/8004/70735394637', 'invig-akp-giai-4596-4695'),
  (343, 43, '70735394638', '3415AFBC0C0000000000121E', 'https://id.invig.no/8004/70735394638', 'invig-akp-giai-4596-4695'),
  (344, 44, '70735394639', '3415AFBC0C0000000000121F', 'https://id.invig.no/8004/70735394639', 'invig-akp-giai-4596-4695'),
  (345, 45, '70735394640', '3415AFBC0C00000000001220', 'https://id.invig.no/8004/70735394640', 'invig-akp-giai-4596-4695'),
  (346, 46, '70735394641', '3415AFBC0C00000000001221', 'https://id.invig.no/8004/70735394641', 'invig-akp-giai-4596-4695'),
  (347, 47, '70735394642', '3415AFBC0C00000000001222', 'https://id.invig.no/8004/70735394642', 'invig-akp-giai-4596-4695'),
  (348, 48, '70735394643', '3415AFBC0C00000000001223', 'https://id.invig.no/8004/70735394643', 'invig-akp-giai-4596-4695'),
  (349, 49, '70735394644', '3415AFBC0C00000000001224', 'https://id.invig.no/8004/70735394644', 'invig-akp-giai-4596-4695'),
  (350, 50, '70735394645', '3415AFBC0C00000000001225', 'https://id.invig.no/8004/70735394645', 'invig-akp-giai-4596-4695'),
  (351, 51, '70735394646', '3415AFBC0C00000000001226', 'https://id.invig.no/8004/70735394646', 'invig-akp-giai-4596-4695'),
  (352, 52, '70735394647', '3415AFBC0C00000000001227', 'https://id.invig.no/8004/70735394647', 'invig-akp-giai-4596-4695'),
  (353, 53, '70735394648', '3415AFBC0C00000000001228', 'https://id.invig.no/8004/70735394648', 'invig-akp-giai-4596-4695'),
  (354, 54, '70735394649', '3415AFBC0C00000000001229', 'https://id.invig.no/8004/70735394649', 'invig-akp-giai-4596-4695'),
  (355, 55, '70735394650', '3415AFBC0C0000000000122A', 'https://id.invig.no/8004/70735394650', 'invig-akp-giai-4596-4695'),
  (356, 56, '70735394651', '3415AFBC0C0000000000122B', 'https://id.invig.no/8004/70735394651', 'invig-akp-giai-4596-4695'),
  (357, 57, '70735394652', '3415AFBC0C0000000000122C', 'https://id.invig.no/8004/70735394652', 'invig-akp-giai-4596-4695'),
  (358, 58, '70735394653', '3415AFBC0C0000000000122D', 'https://id.invig.no/8004/70735394653', 'invig-akp-giai-4596-4695'),
  (359, 59, '70735394654', '3415AFBC0C0000000000122E', 'https://id.invig.no/8004/70735394654', 'invig-akp-giai-4596-4695'),
  (360, 60, '70735394655', '3415AFBC0C0000000000122F', 'https://id.invig.no/8004/70735394655', 'invig-akp-giai-4596-4695'),
  (361, 61, '70735394656', '3415AFBC0C00000000001230', 'https://id.invig.no/8004/70735394656', 'invig-akp-giai-4596-4695'),
  (362, 62, '70735394657', '3415AFBC0C00000000001231', 'https://id.invig.no/8004/70735394657', 'invig-akp-giai-4596-4695'),
  (363, 63, '70735394658', '3415AFBC0C00000000001232', 'https://id.invig.no/8004/70735394658', 'invig-akp-giai-4596-4695'),
  (364, 64, '70735394659', '3415AFBC0C00000000001233', 'https://id.invig.no/8004/70735394659', 'invig-akp-giai-4596-4695'),
  (365, 65, '70735394660', '3415AFBC0C00000000001234', 'https://id.invig.no/8004/70735394660', 'invig-akp-giai-4596-4695'),
  (366, 66, '70735394661', '3415AFBC0C00000000001235', 'https://id.invig.no/8004/70735394661', 'invig-akp-giai-4596-4695'),
  (367, 67, '70735394662', '3415AFBC0C00000000001236', 'https://id.invig.no/8004/70735394662', 'invig-akp-giai-4596-4695'),
  (368, 68, '70735394663', '3415AFBC0C00000000001237', 'https://id.invig.no/8004/70735394663', 'invig-akp-giai-4596-4695'),
  (369, 69, '70735394664', '3415AFBC0C00000000001238', 'https://id.invig.no/8004/70735394664', 'invig-akp-giai-4596-4695'),
  (370, 70, '70735394665', '3415AFBC0C00000000001239', 'https://id.invig.no/8004/70735394665', 'invig-akp-giai-4596-4695'),
  (371, 71, '70735394666', '3415AFBC0C0000000000123A', 'https://id.invig.no/8004/70735394666', 'invig-akp-giai-4596-4695'),
  (372, 72, '70735394667', '3415AFBC0C0000000000123B', 'https://id.invig.no/8004/70735394667', 'invig-akp-giai-4596-4695'),
  (373, 73, '70735394668', '3415AFBC0C0000000000123C', 'https://id.invig.no/8004/70735394668', 'invig-akp-giai-4596-4695'),
  (374, 74, '70735394669', '3415AFBC0C0000000000123D', 'https://id.invig.no/8004/70735394669', 'invig-akp-giai-4596-4695'),
  (375, 75, '70735394670', '3415AFBC0C0000000000123E', 'https://id.invig.no/8004/70735394670', 'invig-akp-giai-4596-4695'),
  (376, 76, '70735394671', '3415AFBC0C0000000000123F', 'https://id.invig.no/8004/70735394671', 'invig-akp-giai-4596-4695'),
  (377, 77, '70735394672', '3415AFBC0C00000000001240', 'https://id.invig.no/8004/70735394672', 'invig-akp-giai-4596-4695'),
  (378, 78, '70735394673', '3415AFBC0C00000000001241', 'https://id.invig.no/8004/70735394673', 'invig-akp-giai-4596-4695'),
  (379, 79, '70735394674', '3415AFBC0C00000000001242', 'https://id.invig.no/8004/70735394674', 'invig-akp-giai-4596-4695'),
  (380, 80, '70735394675', '3415AFBC0C00000000001243', 'https://id.invig.no/8004/70735394675', 'invig-akp-giai-4596-4695'),
  (381, 81, '70735394676', '3415AFBC0C00000000001244', 'https://id.invig.no/8004/70735394676', 'invig-akp-giai-4596-4695'),
  (382, 82, '70735394677', '3415AFBC0C00000000001245', 'https://id.invig.no/8004/70735394677', 'invig-akp-giai-4596-4695'),
  (383, 83, '70735394678', '3415AFBC0C00000000001246', 'https://id.invig.no/8004/70735394678', 'invig-akp-giai-4596-4695'),
  (384, 84, '70735394679', '3415AFBC0C00000000001247', 'https://id.invig.no/8004/70735394679', 'invig-akp-giai-4596-4695'),
  (385, 85, '70735394680', '3415AFBC0C00000000001248', 'https://id.invig.no/8004/70735394680', 'invig-akp-giai-4596-4695'),
  (386, 86, '70735394681', '3415AFBC0C00000000001249', 'https://id.invig.no/8004/70735394681', 'invig-akp-giai-4596-4695'),
  (387, 87, '70735394682', '3415AFBC0C0000000000124A', 'https://id.invig.no/8004/70735394682', 'invig-akp-giai-4596-4695'),
  (388, 88, '70735394683', '3415AFBC0C0000000000124B', 'https://id.invig.no/8004/70735394683', 'invig-akp-giai-4596-4695'),
  (389, 89, '70735394684', '3415AFBC0C0000000000124C', 'https://id.invig.no/8004/70735394684', 'invig-akp-giai-4596-4695'),
  (390, 90, '70735394685', '3415AFBC0C0000000000124D', 'https://id.invig.no/8004/70735394685', 'invig-akp-giai-4596-4695'),
  (391, 91, '70735394686', '3415AFBC0C0000000000124E', 'https://id.invig.no/8004/70735394686', 'invig-akp-giai-4596-4695'),
  (392, 92, '70735394687', '3415AFBC0C0000000000124F', 'https://id.invig.no/8004/70735394687', 'invig-akp-giai-4596-4695'),
  (393, 93, '70735394688', '3415AFBC0C00000000001250', 'https://id.invig.no/8004/70735394688', 'invig-akp-giai-4596-4695'),
  (394, 94, '70735394689', '3415AFBC0C00000000001251', 'https://id.invig.no/8004/70735394689', 'invig-akp-giai-4596-4695'),
  (395, 95, '70735394690', '3415AFBC0C00000000001252', 'https://id.invig.no/8004/70735394690', 'invig-akp-giai-4596-4695'),
  (396, 96, '70735394691', '3415AFBC0C00000000001253', 'https://id.invig.no/8004/70735394691', 'invig-akp-giai-4596-4695'),
  (397, 97, '70735394692', '3415AFBC0C00000000001254', 'https://id.invig.no/8004/70735394692', 'invig-akp-giai-4596-4695'),
  (398, 98, '70735394693', '3415AFBC0C00000000001255', 'https://id.invig.no/8004/70735394693', 'invig-akp-giai-4596-4695'),
  (399, 99, '70735394694', '3415AFBC0C00000000001256', 'https://id.invig.no/8004/70735394694', 'invig-akp-giai-4596-4695'),
  (400, 100, '70735394695', '3415AFBC0C00000000001257', 'https://id.invig.no/8004/70735394695', 'invig-akp-giai-4596-4695');

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
  WHERE b.welcome_batch_code = wb.code
    AND b.display_number BETWEEN p_start AND p_end
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
  WHERE b.welcome_batch_code = wb.code
    AND b.display_number BETWEEN p_start AND p_end;

  RETURN e;
END;
$$;

COMMIT;
