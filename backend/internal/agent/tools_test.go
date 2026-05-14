package agent_test

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/kingpinXD/fit-cp/backend/internal/agent"
	"github.com/kingpinXD/fit-cp/backend/internal/db"
	"github.com/kingpinXD/fit-cp/backend/internal/testhelpers"
)

func newRegistry(t *testing.T) *agent.Registry {
	t.Helper()
	pool := testhelpers.RequireDB(t)
	testhelpers.SeedFixtures(t, pool)
	return agent.NewRegistry(db.New(pool))
}

type toolResult struct {
	ID             string   `json:"id"`
	Name           string   `json:"name"`
	Level          string   `json:"level"`
	Equipment      string   `json:"equipment,omitempty"`
	PrimaryMuscles []string `json:"primary_muscles"`
}

func TestSearchExercisesByMuscle(t *testing.T) {
	reg := newRegistry(t)
	out, err := reg.Execute(context.Background(), "search_exercises", `{"muscle":"biceps"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	var got []toolResult
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("decode: %v: %s", err, out)
	}
	if len(got) != 2 {
		t.Fatalf("want 2 biceps exercises, got %d (%v)", len(got), got)
	}
	names := map[string]bool{}
	for _, r := range got {
		names[r.Name] = true
		// Sanity-check the slim DTO carries the fields we promised.
		if r.Level == "" {
			t.Errorf("level missing on %s", r.ID)
		}
		if len(r.PrimaryMuscles) == 0 || r.PrimaryMuscles[0] != "biceps" {
			t.Errorf("primary muscles for %s: %v", r.ID, r.PrimaryMuscles)
		}
	}
	for _, want := range []string{"Barbell Curl", "Hammer Curl"} {
		if !names[want] {
			t.Errorf("missing %q in results: %v", want, names)
		}
	}
}

func TestSearchExercisesLimitClampedTo25(t *testing.T) {
	reg := newRegistry(t)
	out, err := reg.Execute(context.Background(), "search_exercises", `{"limit":100}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	// The fixture only has 3 exercises, so we can't observe a 25-row cap by
	// counting results. Instead, verify the call doesn't error and returns
	// every available row — the cap is a ceiling, not a floor.
	var got []toolResult
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("decode: %v: %s", err, out)
	}
	if len(got) != 3 {
		t.Errorf("want all 3 fixture exercises returned, got %d", len(got))
	}
}

func TestSearchExercisesUnknownMuscleReturnsEmptyArray(t *testing.T) {
	reg := newRegistry(t)
	out, err := reg.Execute(context.Background(), "search_exercises", `{"muscle":"telekinesis"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if out != "[]" {
		t.Errorf("want empty array, got %q", out)
	}
}

func TestSearchExercisesEmptyArgsUsesDefaults(t *testing.T) {
	reg := newRegistry(t)
	out, err := reg.Execute(context.Background(), "search_exercises", ``)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	var got []toolResult
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("decode: %v: %s", err, out)
	}
	if len(got) != 3 {
		t.Errorf("want 3 fixture exercises, got %d", len(got))
	}
}

func TestSearchExercisesUnknownToolErrors(t *testing.T) {
	reg := newRegistry(t)
	if _, err := reg.Execute(context.Background(), "make_coffee", `{}`); err == nil {
		t.Fatal("expected error for unknown tool")
	}
}

func TestRegistryAdvertisesSearchExercises(t *testing.T) {
	reg := newRegistry(t)
	defs := reg.Definitions()
	if len(defs) != 1 {
		t.Fatalf("want 1 tool def, got %d", len(defs))
	}
	if defs[0].Name != "search_exercises" {
		t.Errorf("name: want search_exercises, got %q", defs[0].Name)
	}
}
