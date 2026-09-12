ALTER TABLE matches DROP COLUMN IF EXISTS first_prize;
ALTER TABLE matches DROP COLUMN IF EXISTS second_prize;
ALTER TABLE matches DROP COLUMN IF EXISTS third_prize;
ALTER TABLE matches ADD COLUMN IF EXISTS position_prizes JSONB DEFAULT '[]'::jsonb;
