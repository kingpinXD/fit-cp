package agent_test

import (
	"context"
	"encoding/json"
	"strings"
	"testing"

	"github.com/kingpinXD/fit-cp/backend/internal/agent"
	"github.com/kingpinXD/fit-cp/backend/internal/db"
	"github.com/kingpinXD/fit-cp/backend/internal/testhelpers"
)

// newCatalogRegistry returns a registry wired to a seeded local DB. Tests
// that need catalog name resolution (the "ok" path and the missing-id path)
// use this.
func newCatalogRegistry(t *testing.T) *agent.Registry {
	t.Helper()
	pool := testhelpers.RequireDB(t)
	testhelpers.SeedFixtures(t, pool)
	return agent.NewRegistry(db.New(pool))
}

// newStructuralRegistry returns a registry wired against a nil DBTX. The
// propose_programme handler short-circuits before touching the DB whenever
// structural validation fails, so these tests can run with no Postgres at
// all — useful in CI and on contributors who don't have docker running.
func newStructuralRegistry() *agent.Registry {
	return agent.NewRegistry(db.New(nil))
}

type toolResult struct {
	ID             string   `json:"id"`
	Name           string   `json:"name"`
	Level          string   `json:"level"`
	Equipment      string   `json:"equipment,omitempty"`
	PrimaryMuscles []string `json:"primary_muscles"`
}

func TestSearchExercisesByMuscle(t *testing.T) {
	reg := newCatalogRegistry(t)
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
	reg := newCatalogRegistry(t)
	out, err := reg.Execute(context.Background(), "search_exercises", `{"limit":100}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	var got []toolResult
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("decode: %v: %s", err, out)
	}
	if len(got) != 3 {
		t.Errorf("want all 3 fixture exercises returned, got %d", len(got))
	}
}

func TestSearchExercisesUnknownMuscleReturnsEmptyArray(t *testing.T) {
	reg := newCatalogRegistry(t)
	out, err := reg.Execute(context.Background(), "search_exercises", `{"muscle":"telekinesis"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	if out != "[]" {
		t.Errorf("want empty array, got %q", out)
	}
}

func TestSearchExercisesEmptyArgsUsesDefaults(t *testing.T) {
	reg := newCatalogRegistry(t)
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
	reg := newStructuralRegistry()
	if _, err := reg.Execute(context.Background(), "make_coffee", `{}`); err == nil {
		t.Fatal("expected error for unknown tool")
	}
}

func TestRegistryAdvertisesBothTools(t *testing.T) {
	reg := newStructuralRegistry()
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

// proposeResult mirrors the result envelope so tests can decode it.
type proposeResult struct {
	Status    string           `json:"status"`
	Missing   []string         `json:"missing"`
	Errors    []string         `json:"errors"`
	Programme *outputProgramme `json:"programme"`
}

type outputProgramme struct {
	Name  string       `json:"name"`
	Weeks []outputWeek `json:"weeks"`
}

type outputWeek struct {
	Week int         `json:"week"`
	Days []outputDay `json:"days"`
}

type outputDay struct {
	Day       string           `json:"day"`
	Exercises []outputExercise `json:"exercises"`
}

type outputExercise struct {
	ExerciseID   string `json:"exercise_id"`
	Name         string `json:"name"`
	Order        int    `json:"order"`
	Sets         int    `json:"sets"`
	Reps         string `json:"reps"`
	WarmupSets   string `json:"warmupSets"`
	RPE          string `json:"rpe"`
	Rest         string `json:"rest"`
	Notes        string `json:"notes"`
	Sub1         string `json:"sub1"`
	Sub2         string `json:"sub2"`
	VideoURL     string `json:"videoUrl"`
	Sub1VideoURL string `json:"sub1VideoUrl"`
	Sub2VideoURL string `json:"sub2VideoUrl"`
}

// validProgrammeJSON builds a programme that uses only seeded fixture ids and
// passes every structural rule (2 days/week = Full Body A + Full Body B).
func validProgrammeJSON() string {
	dayA := `{"day":"Full Body A","exercises":[
        {"exercise_id":"Barbell_Curl","name":"Anything","sets":3,"reps":"8-10","rpe":"7-8","rest":"~2 min"},
        {"exercise_id":"Squat","name":"Whatever","sets":4,"reps":"5","rpe":"7-8"}
    ]}`
	dayB := `{"day":"Full Body B","exercises":[
        {"exercise_id":"Hammer_Curl","name":"Anything","sets":3,"reps":"10-12"}
    ]}`
	dayList := dayA + "," + dayB
	return `{
        "name":"Coach: test",
        "blocks":[
          {"block_number":1,"weeks":[1,2,3,4],"days":[` + dayList + `]},
          {"block_number":2,"weeks":[5,6,7,8],"days":[` + dayList + `]},
          {"block_number":3,"weeks":[9,10,11,12],"days":[` + dayList + `]}
        ]
      }`
}

func decodeResult(t *testing.T, out string) proposeResult {
	t.Helper()
	var got proposeResult
	if err := json.Unmarshal([]byte(out), &got); err != nil {
		t.Fatalf("decode: %v: %s", err, out)
	}
	return got
}

// --- "ok" + catalog-resolution tests (need DB) ---

func TestProposeProgrammeValidExpandsTo12Weeks(t *testing.T) {
	reg := newCatalogRegistry(t)
	out, err := reg.Execute(context.Background(), "propose_programme", validProgrammeJSON())
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (errors=%v missing=%v)", got.Status, got.Errors, got.Missing)
	}
	if got.Programme == nil {
		t.Fatalf("expected programme, got nil")
	}
	if len(got.Programme.Weeks) != 12 {
		t.Fatalf("want 12 weeks, got %d", len(got.Programme.Weeks))
	}
	for i, w := range got.Programme.Weeks {
		if w.Week != i+1 {
			t.Errorf("week[%d].week: want %d, got %d", i, i+1, w.Week)
		}
		if len(w.Days) != 2 {
			t.Errorf("week %d days: want 2, got %d", w.Week, len(w.Days))
		}
	}
	first := got.Programme.Weeks[0].Days[0].Exercises[0]
	if first.Name != "Barbell Curl" {
		t.Errorf("week 1 day 1 ex 1: want catalog name 'Barbell Curl', got %q", first.Name)
	}
}

func TestProposeProgrammeBlockExpansionPreservesDaysWithinBlock(t *testing.T) {
	reg := newCatalogRegistry(t)
	out, err := reg.Execute(context.Background(), "propose_programme", validProgrammeJSON())
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (%v)", got.Status, got.Errors)
	}
	w1 := got.Programme.Weeks[0].Days
	for i := 1; i < 4; i++ {
		if !daysEqual(w1, got.Programme.Weeks[i].Days) {
			t.Errorf("week %d days differ from week 1", i+1)
		}
	}
	w5 := got.Programme.Weeks[4].Days
	for i := 5; i < 8; i++ {
		if !daysEqual(w5, got.Programme.Weeks[i].Days) {
			t.Errorf("week %d days differ from week 5", i+1)
		}
	}
	w9 := got.Programme.Weeks[8].Days
	for i := 9; i < 12; i++ {
		if !daysEqual(w9, got.Programme.Weeks[i].Days) {
			t.Errorf("week %d days differ from week 9", i+1)
		}
	}
}

func TestProposeProgrammeUnknownExerciseID(t *testing.T) {
	reg := newCatalogRegistry(t)
	dayJSON := `{"day":"Full Body","exercises":[
        {"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"},
        {"exercise_id":"ghost_lift","name":"Ghost","sets":3,"reps":"8"}
    ]}`
	payload := allBlocksWithDay(dayJSON)
	out, err := reg.Execute(context.Background(), "propose_programme", payload)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if len(got.Missing) != 1 || got.Missing[0] != "ghost_lift" {
		t.Errorf("missing: want [ghost_lift], got %v", got.Missing)
	}
}

func TestProposeProgrammeMultipleUnknownIDs(t *testing.T) {
	reg := newCatalogRegistry(t)
	payload := `{"name":"x","blocks":[
        {"block_number":1,"weeks":[1,2,3,4],"days":[
          {"day":"Full Body","exercises":[
            {"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"},
            {"exercise_id":"made_up_1","name":"Y","sets":3,"reps":"8"}
          ]}
        ]},
        {"block_number":2,"weeks":[5,6,7,8],"days":[
          {"day":"Full Body","exercises":[
            {"exercise_id":"Squat","name":"x","sets":3,"reps":"8"},
            {"exercise_id":"made_up_2","name":"Z","sets":3,"reps":"8"}
          ]}
        ]},
        {"block_number":3,"weeks":[9,10,11,12],"days":[
          {"day":"Full Body","exercises":[
            {"exercise_id":"Hammer_Curl","name":"x","sets":3,"reps":"8"}
          ]}
        ]}
    ]}`
	out, err := reg.Execute(context.Background(), "propose_programme", payload)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
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

func TestProposeProgrammeOrderFilledFromPosition(t *testing.T) {
	reg := newCatalogRegistry(t)
	dayJSON := `{"day":"Full Body","exercises":[
        {"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"},
        {"exercise_id":"Hammer_Curl","name":"y","sets":3,"reps":"8"},
        {"exercise_id":"Squat","name":"z","sets":3,"reps":"8"}
    ]}`
	out, err := reg.Execute(context.Background(), "propose_programme", allBlocksWithDay(dayJSON))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (%v)", got.Status, got.Errors)
	}
	exs := got.Programme.Weeks[0].Days[0].Exercises
	for i, e := range exs {
		if e.Order != i+1 {
			t.Errorf("ex[%d].order: want %d, got %d", i, i+1, e.Order)
		}
	}
}

func TestProposeProgrammeDefaultEmptyStringsPresent(t *testing.T) {
	reg := newCatalogRegistry(t)
	out, err := reg.Execute(context.Background(), "propose_programme", validProgrammeJSON())
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	body, err := json.Marshal(decodeResult(t, out).Programme.Weeks[0].Days[0].Exercises[1])
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	for _, want := range []string{
		`"warmupSets"`, `"rpe"`, `"rest"`, `"notes"`,
		`"sub1"`, `"sub2"`, `"videoUrl"`, `"sub1VideoUrl"`, `"sub2VideoUrl"`,
	} {
		if !strings.Contains(string(body), want) {
			t.Errorf("encoded exercise missing key %s in %s", want, body)
		}
	}
}

func TestProposeProgrammeCatalogNameOverwritesLLMName(t *testing.T) {
	reg := newCatalogRegistry(t)
	dayJSON := `{"day":"Full Body","exercises":[
        {"exercise_id":"Barbell_Curl","name":"Bench Press (the LLM is wrong)","sets":3,"reps":"8"}
    ]}`
	out, err := reg.Execute(context.Background(), "propose_programme", allBlocksWithDay(dayJSON))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (%v)", got.Status, got.Errors)
	}
	for wi, w := range got.Programme.Weeks {
		for di, d := range w.Days {
			for ei, e := range d.Exercises {
				if e.Name != "Barbell Curl" {
					t.Errorf("week %d day %d ex %d: want catalog name 'Barbell Curl', got %q", wi+1, di+1, ei+1, e.Name)
				}
			}
		}
	}
}

// --- structural tests (short-circuit before DB, no Postgres needed) ---

func TestProposeProgrammeWrongBlockCount(t *testing.T) {
	reg := newStructuralRegistry()
	payload := `{"name":"x","blocks":[
        {"block_number":1,"weeks":[1,2,3,4],"days":[{"day":"Push","exercises":[{"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"}]}]},
        {"block_number":2,"weeks":[5,6,7,8],"days":[{"day":"Push","exercises":[{"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"}]}]}
    ]}`
	out, err := reg.Execute(context.Background(), "propose_programme", payload)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if !containsSubstr(got.Errors, "3 entries") {
		t.Errorf("expected error mentioning '3 entries', got %v", got.Errors)
	}
}

func TestProposeProgrammeWeekGap(t *testing.T) {
	reg := newStructuralRegistry()
	dayJSON := `{"day":"Push","exercises":[{"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"}]}`
	payload := `{"name":"x","blocks":[
        {"block_number":1,"weeks":[1,2,3,4],"days":[` + dayJSON + `]},
        {"block_number":2,"weeks":[5,6,7,8],"days":[` + dayJSON + `]},
        {"block_number":3,"weeks":[9,10,11,13],"days":[` + dayJSON + `]}
    ]}`
	out, err := reg.Execute(context.Background(), "propose_programme", payload)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if !containsSubstr(got.Errors, "weeks 1-12") {
		t.Errorf("expected weeks-coverage error, got %v", got.Errors)
	}
}

func TestProposeProgrammeDuplicateWeeks(t *testing.T) {
	reg := newStructuralRegistry()
	dayJSON := `{"day":"Push","exercises":[{"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"}]}`
	payload := `{"name":"x","blocks":[
        {"block_number":1,"weeks":[1,2,3,4],"days":[` + dayJSON + `]},
        {"block_number":2,"weeks":[4,5,6,7],"days":[` + dayJSON + `]},
        {"block_number":3,"weeks":[9,10,11,12],"days":[` + dayJSON + `]}
    ]}`
	out, err := reg.Execute(context.Background(), "propose_programme", payload)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if !containsSubstr(got.Errors, "duplicated") {
		t.Errorf("expected duplicate-weeks error, got %v", got.Errors)
	}
}

func TestProposeProgrammeGenericDayLabelRejected(t *testing.T) {
	cases := []string{"Day 1", "day 2", "DAY 3", "Workout 1", "Session 3", " Day 4 "}
	reg := newStructuralRegistry()
	for _, label := range cases {
		t.Run(label, func(t *testing.T) {
			dayJSON := `{"day":` + jsonQuote(label) + `,"exercises":[{"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"}]}`
			out, err := reg.Execute(context.Background(), "propose_programme", allBlocksWithDay(dayJSON))
			if err != nil {
				t.Fatalf("Execute: %v", err)
			}
			got := decodeResult(t, out)
			if got.Status != "invalid" {
				t.Fatalf("label %q: want invalid, got %q", label, got.Status)
			}
			if !containsSubstr(got.Errors, "generic") {
				t.Errorf("label %q: expected 'generic' in errors, got %v", label, got.Errors)
			}
		})
	}
}

func TestProposeProgrammeEmptyDaysOrExercises(t *testing.T) {
	reg := newStructuralRegistry()
	cases := map[string]string{
		"empty blocks": `{"name":"x","blocks":[]}`,
		"no days":      blocksWithEmptyDays(),
		"empty day":    blocksWithEmptyExercises(),
		"blank object": `{}`,
	}
	for name, payload := range cases {
		t.Run(name, func(t *testing.T) {
			out, err := reg.Execute(context.Background(), "propose_programme", payload)
			if err != nil {
				t.Fatalf("Execute: %v", err)
			}
			got := decodeResult(t, out)
			if got.Status != "invalid" {
				t.Errorf("status: want invalid, got %q", got.Status)
			}
			if len(got.Errors) == 0 {
				t.Errorf("expected an error message, got empty")
			}
		})
	}
}

func TestProposeProgrammeMismatchedDayCounts(t *testing.T) {
	reg := newStructuralRegistry()
	dayJSON := `{"day":"Push","exercises":[{"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"}]}`
	pullDayJSON := `{"day":"Pull","exercises":[{"exercise_id":"Hammer_Curl","name":"x","sets":3,"reps":"8"}]}`
	legsDayJSON := `{"day":"Legs","exercises":[{"exercise_id":"Squat","name":"x","sets":3,"reps":"8"}]}`
	upperDayJSON := `{"day":"Upper","exercises":[{"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"}]}`
	payload := `{"name":"x","blocks":[
        {"block_number":1,"weeks":[1,2,3,4],"days":[` + dayJSON + `,` + pullDayJSON + `,` + legsDayJSON + `,` + upperDayJSON + `]},
        {"block_number":2,"weeks":[5,6,7,8],"days":[` + dayJSON + `,` + pullDayJSON + `,` + legsDayJSON + `]},
        {"block_number":3,"weeks":[9,10,11,12],"days":[` + dayJSON + `,` + pullDayJSON + `,` + legsDayJSON + `,` + upperDayJSON + `]}
    ]}`
	out, err := reg.Execute(context.Background(), "propose_programme", payload)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if !containsSubstr(got.Errors, "day count must match") {
		t.Errorf("expected 'day count must match' error, got %v", got.Errors)
	}
}

func TestProposeProgrammeMismatchedDayLabels(t *testing.T) {
	reg := newStructuralRegistry()
	pushJSON := `{"day":"Push","exercises":[{"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"}]}`
	pullJSON := `{"day":"Pull","exercises":[{"exercise_id":"Hammer_Curl","name":"x","sets":3,"reps":"8"}]}`
	legsJSON := `{"day":"Legs","exercises":[{"exercise_id":"Squat","name":"x","sets":3,"reps":"8"}]}`
	upperJSON := `{"day":"Upper","exercises":[{"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"}]}`
	payload := `{"name":"x","blocks":[
        {"block_number":1,"weeks":[1,2,3,4],"days":[` + pushJSON + `,` + pullJSON + `,` + legsJSON + `,` + upperJSON + `]},
        {"block_number":2,"weeks":[5,6,7,8],"days":[` + pushJSON + `,` + pullJSON + `,` + upperJSON + `,` + legsJSON + `]},
        {"block_number":3,"weeks":[9,10,11,12],"days":[` + pushJSON + `,` + pullJSON + `,` + legsJSON + `,` + upperJSON + `]}
    ]}`
	out, err := reg.Execute(context.Background(), "propose_programme", payload)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if !containsSubstr(got.Errors, "block 2 day 3") {
		t.Errorf("expected 'block 2 day 3' error, got %v", got.Errors)
	}
	if !containsSubstr(got.Errors, "day labels must match") {
		t.Errorf("expected 'day labels must match' error, got %v", got.Errors)
	}
}

func TestProposeProgrammeSameDaysDifferentExercisesPerBlock(t *testing.T) {
	reg := newCatalogRegistry(t)
	payload := `{"name":"x","blocks":[
        {"block_number":1,"weeks":[1,2,3,4],"days":[
          {"day":"Full Body","exercises":[{"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"}]}
        ]},
        {"block_number":2,"weeks":[5,6,7,8],"days":[
          {"day":"Full Body","exercises":[{"exercise_id":"Hammer_Curl","name":"x","sets":3,"reps":"8"}]}
        ]},
        {"block_number":3,"weeks":[9,10,11,12],"days":[
          {"day":"Full Body","exercises":[{"exercise_id":"Squat","name":"x","sets":3,"reps":"8"}]}
        ]}
    ]}`
	out, err := reg.Execute(context.Background(), "propose_programme", payload)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (errors=%v missing=%v)", got.Status, got.Errors, got.Missing)
	}
	if got.Programme.Weeks[0].Days[0].Exercises[0].Name != "Barbell Curl" {
		t.Errorf("block 1 ex: want 'Barbell Curl', got %q", got.Programme.Weeks[0].Days[0].Exercises[0].Name)
	}
	if got.Programme.Weeks[4].Days[0].Exercises[0].Name != "Hammer Curl" {
		t.Errorf("block 2 ex: want 'Hammer Curl', got %q", got.Programme.Weeks[4].Days[0].Exercises[0].Name)
	}
	if got.Programme.Weeks[8].Days[0].Exercises[0].Name != "Squat" {
		t.Errorf("block 3 ex: want 'Squat', got %q", got.Programme.Weeks[8].Days[0].Exercises[0].Name)
	}
}

func TestProposeProgrammeSameDayLabelsSameExercisesAcrossBlocks(t *testing.T) {
	reg := newCatalogRegistry(t)
	out, err := reg.Execute(context.Background(), "propose_programme", validProgrammeJSON())
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (errors=%v)", got.Status, got.Errors)
	}
}

func TestProposeProgrammeInvalidJSONShape(t *testing.T) {
	reg := newStructuralRegistry()
	out, err := reg.Execute(context.Background(), "propose_programme", `{"blocks":"not an array"}`)
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if !containsSubstr(got.Errors, "invalid request shape") {
		t.Errorf("expected 'invalid request shape', got %v", got.Errors)
	}
}

// --- day-label split table enforcement (structural, no DB needed) ---

// blocksWithDayList builds a 3-block payload where every block has the same
// day list (each day uses Barbell_Curl as a single exercise so we always
// pass the "at least one exercise" rule). Order of labels in the slice is
// preserved across all 3 blocks so validateSameDayStructure stays happy.
func blocksWithDayList(labels []string) string {
	day := func(label string) string {
		return `{"day":` + jsonQuote(label) + `,"exercises":[{"exercise_id":"Barbell_Curl","name":"x","sets":3,"reps":"8"}]}`
	}
	days := make([]string, 0, len(labels))
	for _, l := range labels {
		days = append(days, day(l))
	}
	dayList := strings.Join(days, ",")
	return `{"name":"x","blocks":[
        {"block_number":1,"weeks":[1,2,3,4],"days":[` + dayList + `]},
        {"block_number":2,"weeks":[5,6,7,8],"days":[` + dayList + `]},
        {"block_number":3,"weeks":[9,10,11,12],"days":[` + dayList + `]}
    ]}`
}

// hasSplitError returns true when at least one error mentions the split-table
// failure. Used by the "reject" cases below.
func hasSplitError(errs []string) bool {
	return containsSubstr(errs, "do not match the required split")
}

func TestSplit4DayFullBodyPlusPPLAccepted(t *testing.T) {
	reg := newCatalogRegistry(t)
	out, err := reg.Execute(context.Background(), "propose_programme",
		blocksWithDayList([]string{"Full Body", "Push", "Pull", "Legs"}))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (errors=%v missing=%v)", got.Status, got.Errors, got.Missing)
	}
}

func TestSplit4DayAllFullBodyRejected(t *testing.T) {
	reg := newStructuralRegistry()
	out, err := reg.Execute(context.Background(), "propose_programme",
		blocksWithDayList([]string{"Full Body", "Full Body", "Full Body", "Full Body"}))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if !containsSubstr(got.Errors, "do not match the required split for 4 days/week") {
		t.Errorf("expected 'do not match the required split for 4 days/week' error, got %v", got.Errors)
	}
}

func TestSplit4DayUpperLowerRejected(t *testing.T) {
	reg := newStructuralRegistry()
	out, err := reg.Execute(context.Background(), "propose_programme",
		blocksWithDayList([]string{"Upper", "Lower", "Upper", "Lower"}))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if !hasSplitError(got.Errors) {
		t.Errorf("expected split-mismatch error, got %v", got.Errors)
	}
}

func TestSplit5DayPPLPlusULAccepted(t *testing.T) {
	reg := newCatalogRegistry(t)
	out, err := reg.Execute(context.Background(), "propose_programme",
		blocksWithDayList([]string{"Push", "Pull", "Legs", "Upper", "Lower"}))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (errors=%v missing=%v)", got.Status, got.Errors, got.Missing)
	}
}

func TestSplit5DayPPLRepeatedRejected(t *testing.T) {
	reg := newStructuralRegistry()
	out, err := reg.Execute(context.Background(), "propose_programme",
		blocksWithDayList([]string{"Push", "Pull", "Legs", "Push", "Pull"}))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if !hasSplitError(got.Errors) {
		t.Errorf("expected split-mismatch error, got %v", got.Errors)
	}
}

func TestSplit6DayPPLRepeatedAccepted(t *testing.T) {
	reg := newCatalogRegistry(t)
	out, err := reg.Execute(context.Background(), "propose_programme",
		blocksWithDayList([]string{"Push", "Pull", "Legs", "Push", "Pull", "Legs"}))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (errors=%v missing=%v)", got.Status, got.Errors, got.Missing)
	}
}

func TestSplit6DayULRejected(t *testing.T) {
	reg := newStructuralRegistry()
	out, err := reg.Execute(context.Background(), "propose_programme",
		blocksWithDayList([]string{"Upper", "Lower", "Upper", "Lower", "Upper", "Lower"}))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if !hasSplitError(got.Errors) {
		t.Errorf("expected split-mismatch error, got %v", got.Errors)
	}
}

func TestSplit3DayFullBodyVariantsAccepted(t *testing.T) {
	reg := newCatalogRegistry(t)
	out, err := reg.Execute(context.Background(), "propose_programme",
		blocksWithDayList([]string{"Full Body A", "Full Body B", "Full Body C"}))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (errors=%v missing=%v)", got.Status, got.Errors, got.Missing)
	}
}

func TestSplit3DayMixedRejected(t *testing.T) {
	reg := newStructuralRegistry()
	out, err := reg.Execute(context.Background(), "propose_programme",
		blocksWithDayList([]string{"Full Body A", "Push", "Pull"}))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "invalid" {
		t.Fatalf("status: want invalid, got %q", got.Status)
	}
	if !hasSplitError(got.Errors) {
		t.Errorf("expected split-mismatch error, got %v", got.Errors)
	}
}

func TestSplit7DayPermissive(t *testing.T) {
	reg := newCatalogRegistry(t)
	// 7 labels — any meaningful split (still has to pass the no-generic-label
	// rule). Validator does not enforce a multiset at 7+.
	out, err := reg.Execute(context.Background(), "propose_programme",
		blocksWithDayList([]string{"Push", "Pull", "Legs", "Upper", "Lower", "Chest", "Back"}))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (errors=%v missing=%v)", got.Status, got.Errors, got.Missing)
	}
}

func TestSplitCaseInsensitive(t *testing.T) {
	reg := newCatalogRegistry(t)
	out, err := reg.Execute(context.Background(), "propose_programme",
		blocksWithDayList([]string{"full body", "PUSH", "Pull", "legs"}))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (errors=%v missing=%v)", got.Status, got.Errors, got.Missing)
	}
}

func TestSplitOrderIndependent(t *testing.T) {
	reg := newCatalogRegistry(t)
	out, err := reg.Execute(context.Background(), "propose_programme",
		blocksWithDayList([]string{"Push", "Legs", "Full Body", "Pull"}))
	if err != nil {
		t.Fatalf("Execute: %v", err)
	}
	got := decodeResult(t, out)
	if got.Status != "ok" {
		t.Fatalf("status: want ok, got %q (errors=%v missing=%v)", got.Status, got.Errors, got.Missing)
	}
}

// --- helpers ---

func allBlocksWithDay(dayJSON string) string {
	return `{"name":"x","blocks":[
        {"block_number":1,"weeks":[1,2,3,4],"days":[` + dayJSON + `]},
        {"block_number":2,"weeks":[5,6,7,8],"days":[` + dayJSON + `]},
        {"block_number":3,"weeks":[9,10,11,12],"days":[` + dayJSON + `]}
    ]}`
}

func blocksWithEmptyDays() string {
	return `{"name":"x","blocks":[
        {"block_number":1,"weeks":[1,2,3,4],"days":[]},
        {"block_number":2,"weeks":[5,6,7,8],"days":[]},
        {"block_number":3,"weeks":[9,10,11,12],"days":[]}
    ]}`
}

func blocksWithEmptyExercises() string {
	dayJSON := `{"day":"Push","exercises":[]}`
	return allBlocksWithDay(dayJSON)
}

func jsonQuote(s string) string {
	b, _ := json.Marshal(s)
	return string(b)
}

func containsSubstr(errs []string, needle string) bool {
	for _, e := range errs {
		if strings.Contains(e, needle) {
			return true
		}
	}
	return false
}

func daysEqual(a, b []outputDay) bool {
	if len(a) != len(b) {
		return false
	}
	ab, _ := json.Marshal(a)
	bb, _ := json.Marshal(b)
	return string(ab) == string(bb)
}
