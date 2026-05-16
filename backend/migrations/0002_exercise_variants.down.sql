DROP INDEX IF EXISTS idx_exercises_name_trgm;
DROP INDEX IF EXISTS idx_exercise_variants_source;
DROP INDEX IF EXISTS idx_exercise_variants_name_trgm;
DROP TABLE IF EXISTS exercise_variants;
-- pg_trgm extension kept; other features may depend on it.
