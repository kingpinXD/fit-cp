package httpx

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kingpinXD/fit-cp/backend/internal/db"
	"github.com/kingpinXD/fit-cp/backend/internal/httpio"
)

const (
	defaultLimit = 50
	maxLimit     = 200
)

// API holds the dependencies handlers need. Constructed once at startup.
type API struct {
	Pool    *pgxpool.Pool
	Queries *db.Queries
}

// NewAPI builds the handler set against a pgx pool.
func NewAPI(pool *pgxpool.Pool) *API {
	return &API{Pool: pool, Queries: db.New(pool)}
}

// exerciseDTO is the wire shape returned by /v1/exercises. It embeds primary
// and secondary muscles which sqlc cannot easily express in a single query.
type exerciseDTO struct {
	ID           string    `json:"id"`
	Name         string    `json:"name"`
	Force        *string   `json:"force"`
	Level        string    `json:"level"`
	Mechanic     *string   `json:"mechanic"`
	Equipment    *string   `json:"equipment"`
	Category     string    `json:"category"`
	Instructions []string  `json:"instructions"`
	ImageURLs    []string  `json:"imageUrls"`
	Muscles      muscleDTO `json:"muscles"`
}

type muscleDTO struct {
	Primary   []string `json:"primary"`
	Secondary []string `json:"secondary"`
}

func (api *API) Healthz(w http.ResponseWriter, r *http.Request) {
	dbStatus := "ok"
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := api.Pool.Ping(ctx); err != nil {
		dbStatus = "error"
		slog.Warn("db ping failed", "err", err)
	}
	httpio.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok", "db": dbStatus})
}

func (api *API) ListExercises(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	limit := parseIntDefault(q.Get("limit"), defaultLimit)
	if limit < 1 {
		limit = defaultLimit
	}
	if limit > maxLimit {
		limit = maxLimit
	}
	offset := parseIntDefault(q.Get("offset"), 0)
	if offset < 0 {
		offset = 0
	}

	params := db.ListExercisesParams{
		Muscle:    optText(q.Get("muscle")),
		Equipment: optText(q.Get("equipment")),
		Level:     optText(q.Get("level")),
		Q:         optText(q.Get("q")),
		Off:       int32(offset),
		Lim:       int32(limit),
	}
	rows, err := api.Queries.ListExercises(r.Context(), params)
	if err != nil {
		slog.Error("list exercises", "err", err)
		httpio.WriteError(w, "internal_error", http.StatusInternalServerError, "failed to list exercises")
		return
	}
	total, err := api.Queries.CountExercises(r.Context(), db.CountExercisesParams{
		Muscle:    params.Muscle,
		Equipment: params.Equipment,
		Level:     params.Level,
		Q:         params.Q,
	})
	if err != nil {
		slog.Error("count exercises", "err", err)
		httpio.WriteError(w, "internal_error", http.StatusInternalServerError, "failed to count exercises")
		return
	}

	ids := make([]string, 0, len(rows))
	for _, e := range rows {
		ids = append(ids, e.ID)
	}
	muscles, err := api.Queries.GetMusclesForExercises(r.Context(), ids)
	if err != nil {
		slog.Error("muscles for exercises", "err", err)
		httpio.WriteError(w, "internal_error", http.StatusInternalServerError, "failed to fetch muscles")
		return
	}

	dtos := make([]exerciseDTO, 0, len(rows))
	muscleIndex := groupMuscles(muscles)
	for _, e := range rows {
		dtos = append(dtos, toExerciseDTO(e, muscleIndex[e.ID]))
	}

	httpio.WriteJSON(w, http.StatusOK, map[string]any{
		"exercises": dtos,
		"total":     total,
		"limit":     limit,
		"offset":    offset,
	})
}

func (api *API) GetExercise(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	row, err := api.Queries.GetExerciseByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			httpio.WriteError(w, "not_found", http.StatusNotFound, "exercise not found")
			return
		}
		slog.Error("get exercise", "err", err, "id", id)
		httpio.WriteError(w, "internal_error", http.StatusInternalServerError, "failed to fetch exercise")
		return
	}
	muscles, err := api.Queries.GetMusclesForExercise(r.Context(), id)
	if err != nil {
		slog.Error("get muscles", "err", err, "id", id)
		httpio.WriteError(w, "internal_error", http.StatusInternalServerError, "failed to fetch muscles")
		return
	}
	dto := toExerciseDTO(row, toMuscleRows(id, muscles))
	httpio.WriteJSON(w, http.StatusOK, dto)
}

func (api *API) GetTaxonomy(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	muscles, err := api.Queries.ListMuscles(ctx)
	if err != nil {
		slog.Error("list muscles", "err", err)
		httpio.WriteError(w, "internal_error", http.StatusInternalServerError, "failed to fetch taxonomy")
		return
	}
	equipmentRows, err := api.Queries.ListEquipment(ctx)
	if err != nil {
		slog.Error("list equipment", "err", err)
		httpio.WriteError(w, "internal_error", http.StatusInternalServerError, "failed to fetch taxonomy")
		return
	}
	equipment := make([]string, 0, len(equipmentRows))
	for _, e := range equipmentRows {
		if e.Valid {
			equipment = append(equipment, e.String)
		}
	}
	levels, err := api.Queries.ListLevels(ctx)
	if err != nil {
		slog.Error("list levels", "err", err)
		httpio.WriteError(w, "internal_error", http.StatusInternalServerError, "failed to fetch taxonomy")
		return
	}
	categories, err := api.Queries.ListCategories(ctx)
	if err != nil {
		slog.Error("list categories", "err", err)
		httpio.WriteError(w, "internal_error", http.StatusInternalServerError, "failed to fetch taxonomy")
		return
	}
	httpio.WriteJSON(w, http.StatusOK, map[string][]string{
		"muscles":    muscles,
		"equipment":  equipment,
		"levels":     levels,
		"categories": categories,
	})
}

func parseIntDefault(raw string, def int) int {
	if raw == "" {
		return def
	}
	v, err := strconv.Atoi(raw)
	if err != nil {
		return def
	}
	return v
}

func optText(s string) pgtype.Text {
	if s == "" {
		return pgtype.Text{}
	}
	return pgtype.Text{String: s, Valid: true}
}

func textPtr(t pgtype.Text) *string {
	if !t.Valid {
		return nil
	}
	v := t.String
	return &v
}

func groupMuscles(rows []db.ExerciseMuscle) map[string][]db.ExerciseMuscle {
	out := make(map[string][]db.ExerciseMuscle, len(rows))
	for _, r := range rows {
		out[r.ExerciseID] = append(out[r.ExerciseID], r)
	}
	return out
}

// toMuscleRows adapts the single-exercise muscle rows (which lack exercise_id)
// to the same shape as the batched ones so toExerciseDTO can stay uniform.
func toMuscleRows(exerciseID string, rows []db.GetMusclesForExerciseRow) []db.ExerciseMuscle {
	out := make([]db.ExerciseMuscle, 0, len(rows))
	for _, r := range rows {
		out = append(out, db.ExerciseMuscle{ExerciseID: exerciseID, Muscle: r.Muscle, Role: r.Role})
	}
	return out
}

func toExerciseDTO(e db.Exercise, muscles []db.ExerciseMuscle) exerciseDTO {
	dto := exerciseDTO{
		ID:           e.ID,
		Name:         e.Name,
		Force:        textPtr(e.Force),
		Level:        e.Level,
		Mechanic:     textPtr(e.Mechanic),
		Equipment:    textPtr(e.Equipment),
		Category:     e.Category,
		Instructions: e.Instructions,
		ImageURLs:    e.ImageUrls,
		Muscles:      muscleDTO{Primary: []string{}, Secondary: []string{}},
	}
	for _, m := range muscles {
		if m.Role == "primary" {
			dto.Muscles.Primary = append(dto.Muscles.Primary, m.Muscle)
			continue
		}
		dto.Muscles.Secondary = append(dto.Muscles.Secondary, m.Muscle)
	}
	return dto
}
