// Package testhelpers centralizes integration-test setup so individual test
// files cannot accidentally TRUNCATE a non-local database.
//
// Tests read TEST_DATABASE_URL — a deliberately different variable from the
// runtime DATABASE_URL — so a shell pointing at production can't trip the
// suite into wiping the catalog. As a second layer, RequireDB parses the URL
// and refuses to proceed unless the host is a known local one.
package testhelpers

import (
	"context"
	"net/url"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kingpinXD/fit-cp/backend/internal/db"
)

const testDBEnv = "TEST_DATABASE_URL"

// allowedHosts is the closed set of hostnames that integration tests are
// permitted to point at. Anything else and RequireDB hard-fails before any
// destructive operation runs.
var allowedHosts = map[string]bool{
	"localhost":          true,
	"127.0.0.1":          true,
	"::1":                true,
	"postgres":           true,
	"host.docker.internal": true,
}

// RequireDB returns a connected pool when TEST_DATABASE_URL is set and points
// at a local host; otherwise it skips the test (no env) or fails it (non-local).
// The pool is closed automatically via t.Cleanup.
func RequireDB(t *testing.T) *pgxpool.Pool {
	t.Helper()
	raw := os.Getenv(testDBEnv)
	if raw == "" {
		t.Skipf("%s not set; skipping integration test", testDBEnv)
	}
	u, err := url.Parse(raw)
	if err != nil {
		t.Fatalf("parse %s: %v", testDBEnv, err)
	}
	host := u.Hostname()
	if !allowedHosts[host] {
		t.Fatalf("refusing to run destructive tests against non-local host %q (set %s to a localhost/docker connection)", host, testDBEnv)
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, raw)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	if err := pool.Ping(ctx); err != nil {
		t.Fatalf("ping: %v", err)
	}
	t.Cleanup(pool.Close)
	return pool
}

// ResetExercises wipes the catalog. Only safe to call after RequireDB has
// validated the target host; pass in the pool RequireDB returned.
func ResetExercises(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	if _, err := pool.Exec(context.Background(), "TRUNCATE exercises CASCADE"); err != nil {
		t.Fatalf("truncate: %v", err)
	}
}

// SeedFixtures inserts a deterministic 3-exercise / 4-muscle fixture set shared
// by all integration tests. It calls ResetExercises first, so any prior rows
// are cleared.
func SeedFixtures(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	ResetExercises(t, pool)
	ctx := context.Background()
	q := db.New(pool)

	for _, f := range fixtureExercises() {
		if err := q.UpsertExercise(ctx, f); err != nil {
			t.Fatalf("upsert %s: %v", f.ID, err)
		}
	}
	for _, m := range fixtureMuscles() {
		if err := q.InsertMuscle(ctx, m); err != nil {
			t.Fatalf("insert muscle %s/%s: %v", m.ExerciseID, m.Muscle, err)
		}
	}
}

func fixtureExercises() []db.UpsertExerciseParams {
	return []db.UpsertExerciseParams{
		{ID: "Barbell_Curl", Name: "Barbell Curl",
			Force: text("pull"), Level: "intermediate",
			Mechanic: text("isolation"), Equipment: text("barbell"), Category: "strength",
			Instructions: []string{"step 1"}, ImageUrls: []string{"https://example/barbell_curl/0.jpg"}},
		{ID: "Hammer_Curl", Name: "Hammer Curl",
			Force: text("pull"), Level: "beginner",
			Mechanic: text("isolation"), Equipment: text("dumbbell"), Category: "strength",
			Instructions: []string{"step 1"}, ImageUrls: []string{"https://example/hammer_curl/0.jpg"}},
		{ID: "Squat", Name: "Squat",
			Force: text("push"), Level: "intermediate",
			Mechanic: text("compound"), Equipment: text("barbell"), Category: "strength",
			Instructions: []string{"step 1"}, ImageUrls: []string{"https://example/squat/0.jpg"}},
	}
}

func fixtureMuscles() []db.InsertMuscleParams {
	return []db.InsertMuscleParams{
		{ExerciseID: "Barbell_Curl", Muscle: "biceps", Role: "primary"},
		{ExerciseID: "Barbell_Curl", Muscle: "forearms", Role: "secondary"},
		{ExerciseID: "Hammer_Curl", Muscle: "biceps", Role: "primary"},
		{ExerciseID: "Squat", Muscle: "quadriceps", Role: "primary"},
	}
}

func text(s string) pgtype.Text {
	return pgtype.Text{String: s, Valid: true}
}
