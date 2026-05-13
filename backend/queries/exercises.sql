-- name: ListExercises :many
SELECT e.id, e.name, e.force, e.level, e.mechanic, e.equipment,
       e.category, e.instructions, e.image_urls,
       e.created_at, e.updated_at
FROM exercises e
WHERE
  (sqlc.narg('muscle')::text    IS NULL OR EXISTS (
     SELECT 1 FROM exercise_muscles em
     WHERE em.exercise_id = e.id AND em.muscle = sqlc.narg('muscle')::text))
  AND (sqlc.narg('equipment')::text IS NULL OR e.equipment = sqlc.narg('equipment')::text)
  AND (sqlc.narg('level')::text     IS NULL OR e.level     = sqlc.narg('level')::text)
  AND (sqlc.narg('q')::text         IS NULL OR e.name ILIKE '%' || sqlc.narg('q')::text || '%')
ORDER BY e.name
LIMIT  sqlc.arg('lim')
OFFSET sqlc.arg('off');

-- name: CountExercises :one
SELECT COUNT(*) FROM exercises e
WHERE
  (sqlc.narg('muscle')::text    IS NULL OR EXISTS (
     SELECT 1 FROM exercise_muscles em
     WHERE em.exercise_id = e.id AND em.muscle = sqlc.narg('muscle')::text))
  AND (sqlc.narg('equipment')::text IS NULL OR e.equipment = sqlc.narg('equipment')::text)
  AND (sqlc.narg('level')::text     IS NULL OR e.level     = sqlc.narg('level')::text)
  AND (sqlc.narg('q')::text         IS NULL OR e.name ILIKE '%' || sqlc.narg('q')::text || '%');

-- name: GetExerciseByID :one
SELECT id, name, force, level, mechanic, equipment,
       category, instructions, image_urls,
       created_at, updated_at
FROM exercises
WHERE id = $1;

-- name: GetMusclesForExercise :many
SELECT muscle, role
FROM exercise_muscles
WHERE exercise_id = $1
ORDER BY role, muscle;

-- name: GetMusclesForExercises :many
SELECT exercise_id, muscle, role
FROM exercise_muscles
WHERE exercise_id = ANY($1::text[])
ORDER BY exercise_id, role, muscle;

-- name: UpsertExercise :exec
INSERT INTO exercises (id, name, force, level, mechanic, equipment, category, instructions, image_urls)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
ON CONFLICT (id) DO UPDATE SET
  name         = EXCLUDED.name,
  force        = EXCLUDED.force,
  level        = EXCLUDED.level,
  mechanic     = EXCLUDED.mechanic,
  equipment    = EXCLUDED.equipment,
  category     = EXCLUDED.category,
  instructions = EXCLUDED.instructions,
  image_urls   = EXCLUDED.image_urls,
  updated_at   = now();

-- name: ExerciseExists :one
SELECT EXISTS(SELECT 1 FROM exercises WHERE id = $1);

-- name: DeleteMusclesForExercise :exec
DELETE FROM exercise_muscles WHERE exercise_id = $1;

-- name: InsertMuscle :exec
INSERT INTO exercise_muscles (exercise_id, muscle, role)
VALUES ($1, $2, $3)
ON CONFLICT DO NOTHING;
