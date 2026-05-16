CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE exercise_variants (
  id           bigserial PRIMARY KEY,
  exercise_id  text NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  variant_name text NOT NULL,
  description  text,
  source       text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (exercise_id, variant_name)
);

CREATE INDEX idx_exercise_variants_name_trgm ON exercise_variants USING gin (variant_name gin_trgm_ops);
CREATE INDEX idx_exercise_variants_source    ON exercise_variants(source);
CREATE INDEX idx_exercises_name_trgm         ON exercises          USING gin (name         gin_trgm_ops);
