package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kingpinXD/fit-cp/backend/internal/db"
)

const (
	exercisesURL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"
	imageBaseURL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"
)

// source matches the JSON shape from free-exercise-db. Optional string fields use
// pointers so absent vs empty stays distinguishable.
type source struct {
	ID               string   `json:"id"`
	Name             string   `json:"name"`
	Force            *string  `json:"force"`
	Level            string   `json:"level"`
	Mechanic         *string  `json:"mechanic"`
	Equipment        *string  `json:"equipment"`
	Category         string   `json:"category"`
	PrimaryMuscles   []string `json:"primaryMuscles"`
	SecondaryMuscles []string `json:"secondaryMuscles"`
	Instructions     []string `json:"instructions"`
	Images           []string `json:"images"`
}

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	if err := run(); err != nil {
		logger.Error("seed failed", "err", err)
		os.Exit(1)
	}
}

func run() error {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		return errors.New("DATABASE_URL is required")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	rows, err := fetchExercises(ctx)
	if err != nil {
		return fmt.Errorf("fetch: %w", err)
	}
	slog.Info("fetched exercises", "count", len(rows))

	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		return fmt.Errorf("connect: %w", err)
	}
	defer pool.Close()

	created, updated, err := upsertAll(ctx, pool, rows)
	if err != nil {
		return fmt.Errorf("upsert: %w", err)
	}
	fmt.Printf("Loaded %d exercises (%d new, %d updated).\n", len(rows), created, updated)
	return nil
}

func fetchExercises(ctx context.Context) ([]source, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, exercisesURL, nil)
	if err != nil {
		return nil, err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, fmt.Errorf("status %d: %s", resp.StatusCode, body)
	}
	var rows []source
	if err := json.NewDecoder(resp.Body).Decode(&rows); err != nil {
		return nil, err
	}
	return rows, nil
}

// upsertAll runs the full load in a single transaction so a partial failure
// leaves the catalog untouched. ~870 rows fits easily in one tx.
func upsertAll(ctx context.Context, pool *pgxpool.Pool, rows []source) (created, updated int, err error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return 0, 0, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	q := db.New(tx)
	for _, r := range rows {
		exists, err := q.ExerciseExists(ctx, r.ID)
		if err != nil {
			return 0, 0, fmt.Errorf("exists %s: %w", r.ID, err)
		}
		if err := q.UpsertExercise(ctx, toUpsertParams(r)); err != nil {
			return 0, 0, fmt.Errorf("upsert %s: %w", r.ID, err)
		}
		if err := q.DeleteMusclesForExercise(ctx, r.ID); err != nil {
			return 0, 0, fmt.Errorf("delete muscles %s: %w", r.ID, err)
		}
		for _, m := range r.PrimaryMuscles {
			if m == "" {
				continue
			}
			if err := q.InsertMuscle(ctx, db.InsertMuscleParams{ExerciseID: r.ID, Muscle: m, Role: "primary"}); err != nil {
				return 0, 0, fmt.Errorf("insert primary muscle %s/%s: %w", r.ID, m, err)
			}
		}
		for _, m := range r.SecondaryMuscles {
			if m == "" {
				continue
			}
			if err := q.InsertMuscle(ctx, db.InsertMuscleParams{ExerciseID: r.ID, Muscle: m, Role: "secondary"}); err != nil {
				return 0, 0, fmt.Errorf("insert secondary muscle %s/%s: %w", r.ID, m, err)
			}
		}
		if exists {
			updated++
		} else {
			created++
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return 0, 0, err
	}
	return created, updated, nil
}

func toUpsertParams(s source) db.UpsertExerciseParams {
	instructions := s.Instructions
	if instructions == nil {
		instructions = []string{}
	}
	images := make([]string, 0, len(s.Images))
	for _, p := range s.Images {
		if p == "" {
			continue
		}
		images = append(images, imageBaseURL+p)
	}
	return db.UpsertExerciseParams{
		ID:           s.ID,
		Name:         s.Name,
		Force:        nullable(s.Force),
		Level:        s.Level,
		Mechanic:     nullable(s.Mechanic),
		Equipment:    nullable(s.Equipment),
		Category:     s.Category,
		Instructions: instructions,
		ImageUrls:    images,
	}
}

func nullable(p *string) pgtype.Text {
	if p == nil || *p == "" {
		return pgtype.Text{}
	}
	return pgtype.Text{String: *p, Valid: true}
}

