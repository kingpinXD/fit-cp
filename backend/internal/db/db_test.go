package db_test

import (
	"context"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kingpinXD/fit-cp/backend/internal/db"
)

// requireDB connects to DATABASE_URL or skips the test. Lets the suite run on
// CI without Postgres while still covering integration locally.
func requireDB(t *testing.T) *pgxpool.Pool {
	t.Helper()
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		t.Skip("DATABASE_URL not set; skipping integration test")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	if err := pool.Ping(ctx); err != nil {
		t.Fatalf("ping: %v", err)
	}
	t.Cleanup(pool.Close)
	return pool
}

// resetTables wipes the schema between tests. CASCADE clears exercise_muscles too.
func resetTables(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	_, err := pool.Exec(context.Background(), "TRUNCATE exercises CASCADE")
	if err != nil {
		t.Fatalf("truncate: %v", err)
	}
}

func text(s string) pgtype.Text {
	return pgtype.Text{String: s, Valid: true}
}

func TestListExercisesByMuscle(t *testing.T) {
	pool := requireDB(t)
	resetTables(t, pool)
	ctx := context.Background()
	q := db.New(pool)

	fixtures := []db.UpsertExerciseParams{
		{ID: "Barbell_Curl", Name: "Barbell Curl", Force: text("pull"), Level: "intermediate",
			Mechanic: text("isolation"), Equipment: text("barbell"), Category: "strength",
			Instructions: []string{"step 1"}, ImageUrls: []string{"https://example/0.jpg"}},
		{ID: "Hammer_Curl", Name: "Hammer Curl", Force: text("pull"), Level: "beginner",
			Mechanic: text("isolation"), Equipment: text("dumbbell"), Category: "strength",
			Instructions: []string{"step 1"}, ImageUrls: []string{"https://example/0.jpg"}},
		{ID: "Squat", Name: "Squat", Force: text("push"), Level: "intermediate",
			Mechanic: text("compound"), Equipment: text("barbell"), Category: "strength",
			Instructions: []string{"step 1"}, ImageUrls: []string{"https://example/0.jpg"}},
	}
	for _, f := range fixtures {
		if err := q.UpsertExercise(ctx, f); err != nil {
			t.Fatalf("upsert %s: %v", f.ID, err)
		}
	}

	muscles := []db.InsertMuscleParams{
		{ExerciseID: "Barbell_Curl", Muscle: "biceps", Role: "primary"},
		{ExerciseID: "Barbell_Curl", Muscle: "forearms", Role: "secondary"},
		{ExerciseID: "Hammer_Curl", Muscle: "biceps", Role: "primary"},
		{ExerciseID: "Squat", Muscle: "quadriceps", Role: "primary"},
	}
	for _, m := range muscles {
		if err := q.InsertMuscle(ctx, m); err != nil {
			t.Fatalf("insert muscle %s/%s: %v", m.ExerciseID, m.Muscle, err)
		}
	}

	got, err := q.ListExercises(ctx, db.ListExercisesParams{
		Muscle: text("biceps"),
		Off:    0,
		Lim:    50,
	})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("want 2 biceps exercises, got %d: %+v", len(got), got)
	}
	names := []string{got[0].ID, got[1].ID}
	if names[0] != "Barbell_Curl" || names[1] != "Hammer_Curl" {
		t.Errorf("unexpected order/contents: %v", names)
	}
}

func TestGetMusclesForExercise(t *testing.T) {
	pool := requireDB(t)
	resetTables(t, pool)
	ctx := context.Background()
	q := db.New(pool)

	if err := q.UpsertExercise(ctx, db.UpsertExerciseParams{
		ID: "Barbell_Curl", Name: "Barbell Curl", Force: text("pull"), Level: "intermediate",
		Mechanic: text("isolation"), Equipment: text("barbell"), Category: "strength",
		Instructions: []string{"step 1"}, ImageUrls: []string{"https://example/0.jpg"},
	}); err != nil {
		t.Fatalf("upsert: %v", err)
	}
	for _, m := range []db.InsertMuscleParams{
		{ExerciseID: "Barbell_Curl", Muscle: "biceps", Role: "primary"},
		{ExerciseID: "Barbell_Curl", Muscle: "forearms", Role: "secondary"},
	} {
		if err := q.InsertMuscle(ctx, m); err != nil {
			t.Fatalf("insert: %v", err)
		}
	}

	rows, err := q.GetMusclesForExercise(ctx, "Barbell_Curl")
	if err != nil {
		t.Fatalf("get muscles: %v", err)
	}
	if len(rows) != 2 {
		t.Fatalf("want 2 muscles, got %d", len(rows))
	}
}
