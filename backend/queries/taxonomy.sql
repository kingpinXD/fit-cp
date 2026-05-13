-- name: ListMuscles :many
SELECT DISTINCT muscle FROM exercise_muscles ORDER BY muscle;

-- name: ListEquipment :many
SELECT DISTINCT equipment FROM exercises WHERE equipment IS NOT NULL ORDER BY equipment;

-- name: ListLevels :many
SELECT DISTINCT level FROM exercises ORDER BY level;

-- name: ListCategories :many
SELECT DISTINCT category FROM exercises ORDER BY category;
