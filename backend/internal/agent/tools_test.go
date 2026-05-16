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

func TestRegistryAdvertisesBothTools(t *testing.T) {
	reg := newRegistry(t)
	defs := reg.Definitions()
	if len(defs) != 2 {
		t.Fatalf("want 2 tool defs, got %d", len(defs))
	}
	names := map[string]bool{}
	for _, d := range defs {
		names[d.Name] = true
	}
	for _, want := range []string{"search_exercises", "propose_programme"} {
		if !names[want] {
			t.Errorf("missing tool def %q in %v", want, names)
		}
	}
}

type proposeResult struct {
	Status    string          `json:"status"`
	Missing   []string        `json:"missing"`
	Error     string          `json:"error"`
	Programme json.RawMessage `json:"programme"`
}

// validProgramme builds a programme payload using only seeded fixture ids.
func validProgrammeJSON() string {
	return `{
        "name": "Coach: test",
        "weeks": [
          {"week_number": 1, "days": [
            {"day_name": "A", "exercises": [
              {"exercise_id": "Barbell_Curl", "exercise_name": "Barbell Curl", "sets": 3, "reps": "8-10"},
              {"exercise_id": "Squat",        "exercise_name": "Squat",        "sets": 4, "reps": "5"}
            ]}
          ]}
        ]
      }`
}

func TestProposeProgrammeAllValidReturnsOK(t *testing.T) {
	reg := newRegistry(t)
	out, err := reg.Execute(context.Background(), "propose_programme", validProgrammeJSON())
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	var got proposeResult
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("decode: %v: %s", err, out)
	}
	if got.Status != "ok" {
		t.Errorf("status: want ok, got %q (missing=%v, err=%q)", got.Status, got.Missing, got.Error)
	}
	if len(got.Programme) == 0 {
		t.Errorf("expected echoed programme, got empty")
	}
}

func TestProposeProgrammeOneUnknownIDReturnsInvalid(t *testing.T) {
	reg := newRegistry(t)
	payload := `{
        "name": "Coach: bad",
        "weeks": [
          {"week_number": 1, "days": [
            {"day_name": "A", "exercises": [
              {"exercise_id": "Barbell_Curl", "exercise_name": "Barbell Curl", "sets": 3, "reps": "8"},
              {"exercise_id": "ghost_lift",   "exercise_name": "Ghost Lift",   "sets": 3, "reps": "8"}
            ]}
          ]}
        ]
      }`
	out, err := reg.Execute(context.Background(), "propose_programme", payload)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	var got proposeResult
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("decode: %v: %s", err, out)
	}
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if len(got.Missing) != 1 || got.Missing[0] != "ghost_lift" {
		t.Errorf("missing: want [ghost_lift], got %v", got.Missing)
	}
}

func TestProposeProgrammeMultipleUnknownIDs(t *testing.T) {
	reg := newRegistry(t)
	payload := `{
        "name": "Coach: mostly_bad",
        "weeks": [
          {"week_number": 1, "days": [
            {"day_name": "A", "exercises": [
              {"exercise_id": "Barbell_Curl", "exercise_name": "Barbell Curl", "sets": 3, "reps": "8"},
              {"exercise_id": "made_up_1",    "exercise_name": "X",            "sets": 3, "reps": "8"}
            ]},
            {"day_name": "B", "exercises": [
              {"exercise_id": "Squat",     "exercise_name": "Squat", "sets": 3, "reps": "8"},
              {"exercise_id": "made_up_2", "exercise_name": "Y",     "sets": 3, "reps": "8"}
            ]}
          ]}
        ]
      }`
	out, err := reg.Execute(context.Background(), "propose_programme", payload)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	var got proposeResult
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("decode: %v: %s", err, out)
	}
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	missing := map[string]bool{}
	for _, id := range got.Missing {
		missing[id] = true
	}
	if len(missing) != 2 || !missing["made_up_1"] || !missing["made_up_2"] {
		t.Errorf("missing: want made_up_1+made_up_2, got %v", got.Missing)
	}
}

func TestProposeProgrammeEmptyReturnsInvalid(t *testing.T) {
	reg := newRegistry(t)
	cases := map[string]string{
		"no weeks":     `{"name":"empty","weeks":[]}`,
		"empty day":    `{"name":"empty","weeks":[{"week_number":1,"days":[{"day_name":"A","exercises":[]}]}]}`,
		"no days":      `{"name":"empty","weeks":[{"week_number":1,"days":[]}]}`,
		"blank object": `{}`,
	}
	for name, payload := range cases {
		t.Run(name, func(t *testing.T) {
			out, err := reg.Execute(context.Background(), "propose_programme", payload)
			if err != nil {
				t.Fatalf("Execute: %v", err)
			}
			var got proposeResult
			if err := json.Unmarshal([]byte(out), &got); err != nil {
				t.Fatalf("decode: %v: %s", err, out)
			}
			if got.Status != "invalid" {
				t.Errorf("status: want invalid, got %q", got.Status)
			}
			if got.Error == "" {
				t.Errorf("expected an error message, got empty")
			}
		})
	}
}
