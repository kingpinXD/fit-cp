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
type ToolHandler func(ctx context.Context, args json.RawMessage) (string, error)

// Registry pairs tool schemas with their Go handlers.
type Registry struct {
	defs     []ToolDef
	handlers map[string]ToolHandler
}

// NewRegistry returns a Registry seeded with every built-in tool wired to the
// given Queries. Today there is only one tool; if more come, register them
// here.
func NewRegistry(q *db.Queries) *Registry {
	r := &Registry{handlers: map[string]ToolHandler{}}
	r.register(searchExercisesTool(q))
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
