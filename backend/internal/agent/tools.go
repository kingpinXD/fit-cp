package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"sort"
	"strings"

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

// proposeProgrammeInput mirrors what the LLM emits: top-level name plus three
// mesocycle blocks. The backend expands the blocks into a 12-week programme
// before returning the Flutter-importable shape.
type proposeProgrammeInput struct {
	Name   string                  `json:"name"`
	Blocks []proposeProgrammeBlock `json:"blocks"`
}

type proposeProgrammeBlock struct {
	BlockNumber int                   `json:"block_number"`
	Weeks       []int                 `json:"weeks"`
	Days        []proposeProgrammeDay `json:"days"`
}

type proposeProgrammeDay struct {
	Day       string                     `json:"day"`
	Exercises []proposeProgrammeExercise `json:"exercises"`
}

type proposeProgrammeExercise struct {
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

// outputProgramme is the Flutter-importable shape. Every field on every
// exercise is present (empty string for unset) so the parser sees the same
// keys whether the LLM populated them or not.
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

// proposeProgrammeResult is the stable envelope Flutter detects in the
// message trail. "ok" carries the expanded 12-week programme; "invalid"
// carries errors and/or a missing list for the model to self-correct on the
// next turn.
type proposeProgrammeResult struct {
	Status    string           `json:"status"`
	Missing   []string         `json:"missing,omitempty"`
	Errors    []string         `json:"errors,omitempty"`
	Programme *outputProgramme `json:"programme,omitempty"`
}

const (
	programmeWeekCount     = 12
	programmeBlockCount    = 3
	programmeWeeksPerBlock = 4
)

func proposeProgrammeTool(q *db.Queries) (ToolDef, ToolHandler) {
	def := ToolDef{
		Name:        "propose_programme",
		Description: "Submit a complete workout programme as 3 mesocycle blocks. Backend validates exercise ids and expands the blocks to a 12-week programme before returning.",
		Parameters:  proposeProgrammeSchema(),
	}
	handler := func(ctx context.Context, raw json.RawMessage) (string, error) {
		return runProposeProgramme(ctx, q, raw)
	}
	return def, handler
}

func runProposeProgramme(ctx context.Context, q *db.Queries, raw json.RawMessage) (string, error) {
	in, err := parseProposeProgrammeArgs(raw)
	if err != nil {
		return marshalResult(proposeProgrammeResult{
			Status: "invalid",
			Errors: []string{"invalid request shape"},
		})
	}

	errs := validateStructure(in)
	errs = append(errs, validateSameDayStructure(in.Blocks)...)
	if len(in.Blocks) > 0 {
		errs = append(errs, validateSplitForDayCount(in.Blocks[0].Days)...)
	}
	if len(errs) > 0 {
		return marshalResult(proposeProgrammeResult{Status: "invalid", Errors: errs})
	}

	ids := collectExerciseIDs(in)
	if len(ids) == 0 {
		return marshalResult(proposeProgrammeResult{
			Status: "invalid",
			Errors: []string{"programme has no exercises"},
		})
	}

	missing, names, err := validateCatalog(ctx, q, ids)
	if err != nil {
		return "", fmt.Errorf("validate catalog: %w", err)
	}
	if len(missing) > 0 {
		return marshalResult(proposeProgrammeResult{
			Status:  "invalid",
			Missing: missing,
			Errors:  []string{"exercises not found in catalog"},
		})
	}

	programme := buildOutputProgramme(in, names)
	return marshalResult(proposeProgrammeResult{Status: "ok", Programme: &programme})
}

func parseProposeProgrammeArgs(raw json.RawMessage) (*proposeProgrammeInput, error) {
	in := &proposeProgrammeInput{}
	if len(raw) == 0 {
		return in, nil
	}
	if err := json.Unmarshal(raw, in); err != nil {
		return nil, err
	}
	return in, nil
}

// validateStructure runs every check that does not require a DB lookup. It
// returns all violations rather than stopping at the first, so the model can
// fix the whole shape in one round-trip.
func validateStructure(in *proposeProgrammeInput) []string {
	var errs []string
	if len(in.Blocks) != programmeBlockCount {
		errs = append(errs, fmt.Sprintf("blocks must have exactly %d entries (got %d)", programmeBlockCount, len(in.Blocks)))
	}

	weekSeen := map[int]bool{}
	var dupes []int
	for i, b := range in.Blocks {
		if len(b.Weeks) != programmeWeeksPerBlock {
			errs = append(errs, fmt.Sprintf("block %d must list exactly %d week numbers (got %d)", i+1, programmeWeeksPerBlock, len(b.Weeks)))
		}
		for _, w := range b.Weeks {
			if weekSeen[w] {
				dupes = append(dupes, w)
				continue
			}
			weekSeen[w] = true
		}
		if len(b.Days) == 0 {
			errs = append(errs, fmt.Sprintf("block %d must have at least one day", i+1))
		}
		for di, d := range b.Days {
			if isGenericDayLabel(d.Day) {
				errs = append(errs, fmt.Sprintf("day name %q is generic; use a meaningful label like Push/Pull/Legs/Upper/Lower", d.Day))
			}
			if len(d.Exercises) == 0 {
				errs = append(errs, fmt.Sprintf("block %d day %d (%q) must have at least one exercise", i+1, di+1, d.Day))
			}
			for ei, e := range d.Exercises {
				if e.ExerciseID == "" {
					errs = append(errs, fmt.Sprintf("block %d day %d exercise %d: exercise_id is required", i+1, di+1, ei+1))
				}
				if e.Name == "" {
					errs = append(errs, fmt.Sprintf("block %d day %d exercise %d: name is required", i+1, di+1, ei+1))
				}
				if e.Sets < 1 {
					errs = append(errs, fmt.Sprintf("block %d day %d exercise %d: sets must be >= 1", i+1, di+1, ei+1))
				}
				if e.Reps == "" {
					errs = append(errs, fmt.Sprintf("block %d day %d exercise %d: reps is required", i+1, di+1, ei+1))
				}
			}
		}
	}
	if len(dupes) > 0 {
		errs = append(errs, fmt.Sprintf("weeks duplicated across blocks: %v", dupes))
	}
	if len(in.Blocks) == programmeBlockCount {
		var missing []int
		for w := 1; w <= programmeWeekCount; w++ {
			if !weekSeen[w] {
				missing = append(missing, w)
			}
		}
		if len(missing) > 0 {
			errs = append(errs, fmt.Sprintf("blocks must cover weeks 1-%d exactly; missing %v", programmeWeekCount, missing))
		}
	}
	return errs
}

// genericDayLabel matches "Day 1", "workout 2", "SESSION 3" — anything that
// reads as a placeholder rather than a real split label. Trailing/leading
// whitespace is tolerated.
var genericDayLabel = regexp.MustCompile(`(?i)^\s*(day|workout|session)\s*\d+\s*$`)

func isGenericDayLabel(s string) bool {
	return genericDayLabel.MatchString(s)
}

// validateSameDayStructure enforces that all 3 blocks have identical day counts
// and day labels in the same order. Allows exercise variation within a day
// across blocks while keeping the user's split intact (block 1 Push/Pull/Legs
// must stay Push/Pull/Legs in blocks 2 and 3).
func validateSameDayStructure(blocks []proposeProgrammeBlock) []string {
	var errs []string
	if len(blocks) < 2 {
		return errs
	}
	ref := blocks[0].Days
	for i := 1; i < len(blocks); i++ {
		cur := blocks[i].Days
		if len(cur) != len(ref) {
			errs = append(errs, fmt.Sprintf("block %d has %d days; block 1 has %d — day count must match across blocks", i+1, len(cur), len(ref)))
			continue
		}
		for j := range ref {
			if cur[j].Day != ref[j].Day {
				errs = append(errs, fmt.Sprintf("block %d day %d is %q; block 1's matching day is %q — day labels must match across blocks in the same order", i+1, j+1, cur[j].Day, ref[j].Day))
			}
		}
	}
	return errs
}

// validateSplitForDayCount enforces the day-label pattern per days-per-week.
// Acts on block 1's days only — validateSameDayStructure already guarantees
// blocks 2 and 3 mirror block 1.
func validateSplitForDayCount(days []proposeProgrammeDay) []string {
	n := len(days)
	if n >= 7 || n == 0 {
		return nil
	}
	counts := map[string]int{}
	for _, d := range days {
		token := normalizeDayLabel(d.Day)
		counts[token]++
	}
	expected, ok := splitTemplates[n]
	if !ok {
		return nil
	}
	if !mapsEqual(counts, expected) {
		return []string{splitErrorMessage(n, days, expected)}
	}
	return nil
}

// normalizeDayLabel lowercases + trims, collapsing any "Full Body" variant
// (`Full Body`, `Full Body A/B/C`) to the single token "full body" so the
// multiset check is order- and suffix-independent.
func normalizeDayLabel(raw string) string {
	s := strings.ToLower(strings.TrimSpace(raw))
	if strings.HasPrefix(s, "full body") {
		return "full body"
	}
	return s
}

// splitTemplates is the canonical multiset per days/week. Lowercase keys.
var splitTemplates = map[int]map[string]int{
	1: {"full body": 1},
	2: {"full body": 2},
	3: {"full body": 3},
	4: {"full body": 1, "push": 1, "pull": 1, "legs": 1},
	5: {"push": 1, "pull": 1, "legs": 1, "upper": 1, "lower": 1},
	6: {"push": 2, "pull": 2, "legs": 2},
}

func mapsEqual(a, b map[string]int) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		if b[k] != v {
			return false
		}
	}
	return true
}

func splitErrorMessage(n int, days []proposeProgrammeDay, expected map[string]int) string {
	actual := make([]string, 0, len(days))
	for _, d := range days {
		actual = append(actual, d.Day)
	}
	return fmt.Sprintf(
		"day labels %v do not match the required split for %d days/week — expected the multiset %v (case-insensitive, Full Body variants count as Full Body)",
		actual, n, expected,
	)
}

// validateCatalog returns the unknown ids and a name lookup for the known
// ones in a single round-trip + N point lookups. N is small (distinct
// exercises in a programme, usually 5-15), so per-row queries are fine.
func validateCatalog(ctx context.Context, q *db.Queries, ids []string) (missing []string, names map[string]string, err error) {
	found, err := q.ExerciseExistsByIDs(ctx, ids)
	if err != nil {
		return nil, nil, fmt.Errorf("exercise exists by ids: %w", err)
	}
	missing = diffIDs(ids, found)
	if len(missing) > 0 {
		return missing, nil, nil
	}
	names = make(map[string]string, len(found))
	for _, id := range found {
		row, err := q.GetExerciseByID(ctx, id)
		if err != nil {
			return nil, nil, fmt.Errorf("get exercise %s: %w", id, err)
		}
		names[id] = row.Name
	}
	return nil, names, nil
}

// buildOutputProgramme normalizes every exercise (catalog name + filled
// defaults) and expands the 3-block input into the 12-week wire shape.
func buildOutputProgramme(in *proposeProgrammeInput, names map[string]string) outputProgramme {
	blocksByWeek := make(map[int][]outputDay, programmeWeekCount)
	for _, b := range in.Blocks {
		days := make([]outputDay, 0, len(b.Days))
		for _, d := range b.Days {
			exs := make([]outputExercise, 0, len(d.Exercises))
			for i, e := range d.Exercises {
				exs = append(exs, normalizeExercise(e, names[e.ExerciseID], i+1))
			}
			days = append(days, outputDay{Day: d.Day, Exercises: exs})
		}
		for _, w := range b.Weeks {
			blocksByWeek[w] = days
		}
	}

	weeks := make([]outputWeek, 0, programmeWeekCount)
	for w := 1; w <= programmeWeekCount; w++ {
		weeks = append(weeks, outputWeek{Week: w, Days: blocksByWeek[w]})
	}
	return outputProgramme{Name: in.Name, Weeks: weeks}
}

// normalizeExercise overwrites the model's display name with the catalog
// name, fills the order if missing, and leaves all other defaults at the
// empty string (Go zero-value) so the JSON encoder always emits the key.
func normalizeExercise(in proposeProgrammeExercise, catalogName string, position int) outputExercise {
	order := in.Order
	if order <= 0 {
		order = position
	}
	return outputExercise{
		ExerciseID:   in.ExerciseID,
		Name:         catalogName,
		Order:        order,
		Sets:         in.Sets,
		Reps:         in.Reps,
		WarmupSets:   in.WarmupSets,
		RPE:          in.RPE,
		Rest:         in.Rest,
		Notes:        in.Notes,
		Sub1:         in.Sub1,
		Sub2:         in.Sub2,
		VideoURL:     in.VideoURL,
		Sub1VideoURL: in.Sub1VideoURL,
		Sub2VideoURL: in.Sub2VideoURL,
	}
}

// collectExerciseIDs walks the programme and returns every distinct
// exercise_id in the order they first appear, skipping blanks.
func collectExerciseIDs(p *proposeProgrammeInput) []string {
	seen := map[string]bool{}
	out := make([]string, 0)
	for _, b := range p.Blocks {
		for _, d := range b.Days {
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

// diffIDs returns the ids in want that are not in have, preserving the
// original order so the model sees its emissions back in the same sequence.
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
	sort.Strings(missing)
	return missing
}

func proposeProgrammeSchema() map[string]any {
	exerciseProps := map[string]any{
		"exercise_id":  map[string]any{"type": "string", "description": "Catalog id from search_exercises results"},
		"name":         map[string]any{"type": "string", "description": "Display name; backend overwrites this with the catalog name"},
		"sets":         map[string]any{"type": "integer", "minimum": 1},
		"reps":         map[string]any{"type": "string"},
		"warmupSets":   map[string]any{"type": "string"},
		"rpe":          map[string]any{"type": "string"},
		"rest":         map[string]any{"type": "string"},
		"notes":        map[string]any{"type": "string"},
		"sub1":         map[string]any{"type": "string"},
		"sub2":         map[string]any{"type": "string"},
		"videoUrl":     map[string]any{"type": "string"},
		"sub1VideoUrl": map[string]any{"type": "string"},
		"sub2VideoUrl": map[string]any{"type": "string"},
		"order":        map[string]any{"type": "integer", "minimum": 1, "description": "Auto-filled from position if omitted"},
	}
	dayProps := map[string]any{
		"day": map[string]any{
			"type":        "string",
			"description": "Meaningful split label (Push/Pull/Legs, Upper/Lower, Full Body A, etc.). Never \"Day 1\".",
		},
		"exercises": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type":       "object",
				"properties": exerciseProps,
				"required":   []string{"exercise_id", "name", "sets", "reps"},
			},
		},
	}
	blockProps := map[string]any{
		"block_number": map[string]any{"type": "integer", "minimum": 1, "maximum": programmeBlockCount},
		"weeks": map[string]any{
			"type":        "array",
			"description": "The 4 week numbers this block covers, e.g. [1,2,3,4]",
			"items":       map[string]any{"type": "integer", "minimum": 1, "maximum": programmeWeekCount},
			"minItems":    programmeWeeksPerBlock,
			"maxItems":    programmeWeeksPerBlock,
		},
		"days": map[string]any{
			"type": "array",
			"items": map[string]any{
				"type":       "object",
				"properties": dayProps,
				"required":   []string{"day", "exercises"},
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
			"blocks": map[string]any{
				"type":        "array",
				"description": "Exactly 3 mesocycle blocks covering weeks 1-12 in order.",
				"minItems":    programmeBlockCount,
				"maxItems":    programmeBlockCount,
				"items": map[string]any{
					"type":       "object",
					"properties": blockProps,
					"required":   []string{"block_number", "weeks", "days"},
				},
			},
		},
		"required": []string{"name", "blocks"},
	}
}
