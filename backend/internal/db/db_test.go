package db_test

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgtype"

	"github.com/kingpinXD/fit-cp/backend/internal/db"
	"github.com/kingpinXD/fit-cp/backend/internal/testhelpers"
)

func TestListExercisesByMuscle(t *testing.T) {
	pool := testhelpers.RequireDB(t)
	testhelpers.SeedFixtures(t, pool)
	q := db.New(pool)

	got, err := q.ListExercises(context.Background(), db.ListExercisesParams{
		Muscle: pgtype.Text{String: "biceps", Valid: true},
		Off:    0,
		Lim:    50,
	})
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("want 2 biceps exercises, got %d: %+v", len(got), got)
	}
	if got[0].ID != "Barbell_Curl" || got[1].ID != "Hammer_Curl" {
		t.Errorf("unexpected order/contents: %s, %s", got[0].ID, got[1].ID)
	}
}

func TestGetMusclesForExercise(t *testing.T) {
	pool := testhelpers.RequireDB(t)
	testhelpers.SeedFixtures(t, pool)
	q := db.New(pool)

	rows, err := q.GetMusclesForExercise(context.Background(), "Barbell_Curl")
	if err != nil {
		t.Fatalf("get muscles: %v", err)
	}
	if len(rows) != 2 {
		t.Fatalf("want 2 muscles, got %d", len(rows))
	}
}
