package agent

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/jackc/pgx/v5/pgtype"

	"github.com/kingpinXD/fit-cp/backend/internal/db"
)

// ToolHandler executes a single tool. The arguments are the raw JSON the model
// emitted; the result string is the tool message content sent back to the model
// (also expected to be JSON, but the contract is "any string the model can
// read", same as the OpenAI API).
//
// Handler implementations MUST be safe to call concurrently. The loop
// dispatches parallel tool_calls in parallel goroutines, so any shared state
// inside a handler needs its own synchronisation.
type ToolHandler func(ctx context.Context, args json.RawMessage) (string, error)

// Registry pairs tool schemas with their Go handlers.
type Registry struct {
	defs     []ToolDef
	handlers map[string]ToolHandler
}

// NewRegistry returns a Registry seeded with every built-in tool wired to the
// given Queries. ResolveTools decides which of these are exposed per mode.
func NewRegistry(q *db.Queries) *Registry {
	r := &Registry{handlers: map[string]ToolHandler{}}
	r.register(searchExercisesTool(q))
	r.register(proposeProgrammeTool(q))
	return r
}

func (r *Registry) register(def ToolDef, h ToolHandler) {
	r.defs = append(r.defs, def)
	r.handlers[def.Name] = h
}

// Definitions returns the schemas to advertise to the model on every turn.
func (r *Registry) Definitions() []ToolDef {
	return r.defs
}

// SubsetDefs returns the subset of tool definitions whose names match.
// Unknown names are silently skipped — callers (ResolveTools) only ever pass
// names registered at startup, so a miss means the registry wiring is wrong.
func (r *Registry) SubsetDefs(names ...string) []ToolDef {
	wanted := make(map[string]bool, len(names))
	for _, n := range names {
		wanted[n] = true
	}
	out := make([]ToolDef, 0, len(names))
	for _, d := range r.defs {
		if wanted[d.Name] {
			out = append(out, d)
		}
	}
	return out
}

// Execute runs the named tool. Unknown tools return an error so the loop can
// surface the failure back to the model as a tool result.
func (r *Registry) Execute(ctx context.Context, name string, args string) (string, error) {
	h, ok := r.handlers[name]
	if !ok {
		return "", fmt.Errorf("unknown tool %q", name)
	}
	return h(ctx, json.RawMessage(args))
}

const (
	searchExercisesDefaultLimit = 10
	searchExercisesMaxLimit     = 25
)

// searchExercisesArgs is the model-facing parameter shape. JSON tag names
// match the JSON Schema in the tool definition exactly.
type searchExercisesArgs struct {
	Muscle    string `json:"muscle"`
	Equipment string `json:"equipment"`
	Level     string `json:"level"`
	Limit     int    `json:"limit"`
}

// searchExercisesResult is a deliberately slim DTO. Instructions/imageURLs are
// stripped so the tool response stays small in tokens.
type searchExercisesResult struct {
	ID             string   `json:"id"`
	Name           string   `json:"name"`
	Level          string   `json:"level"`
	Equipment      string   `json:"equipment,omitempty"`
	PrimaryMuscles []string `json:"primary_muscles"`
}

func searchExercisesTool(q *db.Queries) (ToolDef, ToolHandler) {
	def := ToolDef{
		Name:        "search_exercises",
		Description: "Search the fit-cp exercise catalog. Returns up to `limit` exercises matching the filters.",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"muscle": map[string]any{
					"type":        "string",
					"description": "Primary muscle group (e.g. biceps, quadriceps, chest)",
				},
				"equipment": map[string]any{
					"type":        "string",
					"description": "Required equipment (barbell, dumbbell, body only, ...)",
				},
				"level": map[string]any{
					"type": "string",
					"enum": []string{"beginner", "intermediate", "expert"},
				},
				"limit": map[string]any{
					"type":        "integer",
					"description": "Max results, defaults to 10, capped at 25",
				},
			},
		},
	}
	handler := func(ctx context.Context, raw json.RawMessage) (string, error) {
		args := searchExercisesArgs{}
		if len(raw) > 0 {
			if err := json.Unmarshal(raw, &args); err != nil {
				return "", fmt.Errorf("parse args: %w", err)
			}
		}
		return runSearchExercises(ctx, q, args)
	}
	return def, handler
}

func runSearchExercises(ctx context.Context, q *db.Queries, args searchExercisesArgs) (string, error) {
	limit := args.Limit
	if limit <= 0 {
		limit = searchExercisesDefaultLimit
	}
	if limit > searchExercisesMaxLimit {
		limit = searchExercisesMaxLimit
	}

	params := db.ListExercisesParams{
		Muscle:    optText(args.Muscle),
		Equipment: optText(args.Equipment),
		Level:     optText(args.Level),
		Off:       0,
		Lim:       int32(limit),
	}
	rows, err := q.ListExercises(ctx, params)
	if err != nil {
		return "", fmt.Errorf("list exercises: %w", err)
	}

	results := make([]searchExercisesResult, 0, len(rows))
	if len(rows) == 0 {
		return marshalResult(results)
	}

	ids := make([]string, 0, len(rows))
	for _, e := range rows {
		ids = append(ids, e.ID)
	}
	muscles, err := q.GetMusclesForExercises(ctx, ids)
	if err != nil {
		return "", fmt.Errorf("muscles for exercises: %w", err)
	}
	primaryByID := map[string][]string{}
	for _, m := range muscles {
		if m.Role != "primary" {
			continue
		}
		primaryByID[m.ExerciseID] = append(primaryByID[m.ExerciseID], m.Muscle)
	}

	for _, e := range rows {
		r := searchExercisesResult{
			ID:             e.ID,
			Name:           e.Name,
			Level:          e.Level,
			PrimaryMuscles: primaryByID[e.ID],
		}
		if e.Equipment.Valid {
			r.Equipment = e.Equipment.String
		}
		if r.PrimaryMuscles == nil {
			r.PrimaryMuscles = []string{}
		}
		results = append(results, r)
	}
	return marshalResult(results)
}

func marshalResult(v any) (string, error) {
	b, err := json.Marshal(v)
	if err != nil {
		return "", fmt.Errorf("marshal tool result: %w", err)
	}
	return string(b), nil
}

func optText(s string) pgtype.Text {
	if s == "" {
		return pgtype.Text{}
	}
	return pgtype.Text{String: s, Valid: true}
}

// proposeProgrammeArgs mirrors the JSON Schema we advertise on the tool, with
// json.RawMessage on the leaf programme so we can echo the model's exact
// payload back unchanged on success.
type proposeProgrammeArgs struct {
	Name  string                 `json:"name"`
	Weeks []proposeProgrammeWeek `json:"weeks"`
}

type proposeProgrammeWeek struct {
	WeekNumber int                   `json:"week_number"`
	Days       []proposeProgrammeDay `json:"days"`
}

type proposeProgrammeDay struct {
	DayName   string                     `json:"day_name"`
	Exercises []proposeProgrammeExercise `json:"exercises"`
}

type proposeProgrammeExercise struct {
	ExerciseID   string `json:"exercise_id"`
	ExerciseName string `json:"exercise_name"`
	Sets         int    `json:"sets"`
	Reps         string `json:"reps"`
	RPE          string `json:"rpe,omitempty"`
	Rest         string `json:"rest,omitempty"`
	WarmupSets   string `json:"warmup_sets,omitempty"`
	Notes        string `json:"notes,omitempty"`
	Sub1         string `json:"sub1,omitempty"`
	Sub2         string `json:"sub2,omitempty"`
}

// proposeProgrammeResult is the stable shape Flutter detects in the message
// trail. "ok" means every exercise id resolved; "invalid" lists the missing
// ids so the model can self-correct on the next turn.
type proposeProgrammeResult struct {
	Status    string          `json:"status"`
	Missing   []string        `json:"missing,omitempty"`
	Error     string          `json:"error,omitempty"`
	Programme json.RawMessage `json:"programme,omitempty"`
}

// proposeProgrammeTool builds the Coach's final-output tool. The handler
// validates every exercise_id exists in the catalog and echoes the programme
// back as JSON on success.
func proposeProgrammeTool(q *db.Queries) (ToolDef, ToolHandler) {
	def := ToolDef{
		Name:        "propose_programme",
		Description: "Submit a complete workout programme. Every exercise must come from search_exercises results. Backend validates exercise ids exist before returning.",
		Parameters:  proposeProgrammeSchema(),
	}
	handler := func(ctx context.Context, raw json.RawMessage) (string, error) {
		return runProposeProgramme(ctx, q, raw)
	}
	return def, handler
}

func runProposeProgramme(ctx context.Context, q *db.Queries, raw json.RawMessage) (string, error) {
	var args proposeProgrammeArgs
	if len(raw) > 0 {
		if err := json.Unmarshal(raw, &args); err != nil {
			return "", fmt.Errorf("parse args: %w", err)
		}
	}

	ids := collectExerciseIDs(args)
	if len(ids) == 0 {
		return marshalResult(proposeProgrammeResult{
			Status:  "invalid",
			Missing: []string{},
			Error:   "programme has no exercises",
		})
	}

	found, err := q.ExerciseExistsByIDs(ctx, ids)
	if err != nil {
		return "", fmt.Errorf("exercise exists by ids: %w", err)
	}
	missing := diffIDs(ids, found)
	if len(missing) > 0 {
		return marshalResult(proposeProgrammeResult{
			Status:  "invalid",
			Missing: missing,
			Error:   "exercises not found in catalog",
		})
	}

	return marshalResult(proposeProgrammeResult{
		Status:    "ok",
		Programme: raw,
	})
}

// collectExerciseIDs walks the programme and returns every distinct
// exercise_id in the order they first appear, skipping blanks.
func collectExerciseIDs(p proposeProgrammeArgs) []string {
	seen := map[string]bool{}
	out := make([]string, 0)
	for _, w := range p.Weeks {
		for _, d := range w.Days {
			for _, e := range d.Exercises {
				if e.ExerciseID == "" || seen[e.ExerciseID] {
					continue
				}
				seen[e.ExerciseID] = true
				out = append(out, e.ExerciseID)
			}
		}
	}
	return out
}

func diffIDs(want, have []string) []string {
	got := make(map[string]bool, len(have))
	for _, id := range have {
		got[id] = true
	}
	missing := make([]string, 0)
	for _, id := range want {
		if !got[id] {
			missing = append(missing, id)
		}
	}
	return missing
}

func proposeProgrammeSchema() map[string]any {
	exerciseProps := map[string]any{
		"exercise_id":   map[string]any{"type": "string"},
		"exercise_name": map[string]any{"type": "string"},
		"sets":          map[string]any{"type": "integer", "minimum": 1},
		"reps":          map[string]any{"type": "string"},
		"rpe":           map[string]any{"type": "string"},
		"rest":          map[string]any{"type": "string"},
		"warmup_sets":   map[string]any{"type": "string"},
		"notes":         map[string]any{"type": "string"},
		"sub1":          map[string]any{"type": "string"},
		"sub2":          map[string]any{"type": "string"},
	}
	dayProps := map[string]any{
		"day_name": map[string]any{"type": "string"},
		"exercises": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type":       "object",
				"properties": exerciseProps,
				"required":   []string{"exercise_id", "exercise_name", "sets", "reps"},
			},
		},
	}
	weekProps := map[string]any{
		"week_number": map[string]any{"type": "integer", "minimum": 1},
		"days": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type":       "object",
				"properties": dayProps,
				"required":   []string{"day_name", "exercises"},
			},
		},
	}
	return map[string]any{
		"type": "object",
		"properties": map[string]any{
			"name": map[string]any{
				"type":        "string",
				"description": "Programme name, e.g. 'Coach: 4-day PPL'",
			},
			"weeks": map[string]any{
				"type": "array",
				"items": map[string]any{
					"type":       "object",
					"properties": weekProps,
					"required":   []string{"week_number", "days"},
				},
			},
		},
		"required": []string{"name", "weeks"},
	}
}
