-- name: UpsertExerciseVariant :one
-- Returns true when a new row was inserted, false when an existing variant was updated.
INSERT INTO exercise_variants (exercise_id, variant_name, description, source)
VALUES ($1, $2, $3, $4)
ON CONFLICT (exercise_id, variant_name) DO UPDATE
  SET description = EXCLUDED.description,
      source      = EXCLUDED.source
RETURNING (xmax = 0) AS inserted;

-- name: ListVariantsForExercise :many
SELECT id, exercise_id, variant_name, description, source, created_at
FROM exercise_variants
WHERE exercise_id = $1
ORDER BY variant_name;

-- name: SearchExerciseByFuzzyName :many
-- Trigram similarity against the catalog. Returns top N matches above the operator threshold.
SELECT id, name, similarity(name, sqlc.arg('q')::text) AS sim
FROM exercises
WHERE name % sqlc.arg('q')::text
ORDER BY sim DESC, name
LIMIT sqlc.arg('lim');

-- name: CountExerciseVariants :one
SELECT COUNT(*) FROM exercise_variants;
