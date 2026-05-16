package main

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

// catalog is an in-memory map of lowercase name -> exercise id for exact-match lookup.
// We build this once at startup so 99% of canonicalizations stay in process.
type catalog struct {
	byLowerName map[string]string
}

func loadCatalog(ctx context.Context, pool *pgxpool.Pool) (*catalog, error) {
	rows, err := pool.Query(ctx, `SELECT id, name FROM exercises`)
	if err != nil {
		return nil, fmt.Errorf("load catalog: %w", err)
	}
	defer rows.Close()

	c := &catalog{byLowerName: make(map[string]string, 1024)}
	for rows.Next() {
		var id, name string
		if err := rows.Scan(&id, &name); err != nil {
			return nil, err
		}
		c.byLowerName[strings.ToLower(name)] = id
	}
	return c, rows.Err()
}

// matchKind tags how a name resolved to a catalog row.
type matchKind int

const (
	matchNone matchKind = iota
	matchExact
	matchFuzzy
)

type match struct {
	kind        matchKind
	exerciseID  string
	matchedName string
	similarity  float32

	topCandidate string
	topSim       float32
}

// canonicalize tries an exact (case-insensitive) match first, then falls back
// to a trigram fuzzy search. We also try a JN-abbreviation-expanded form so
// "DB Bench Press" can land on "Dumbbell Bench Press".
//
// A fuzzy candidate is accepted when its similarity clears the threshold AND
// either (a) it's a clear winner (gap to #2 >= 0.1) or (b) the top is so good
// (>= 0.7) that the closest runner-up is most likely just a sibling variant.
func (c *catalog) canonicalize(ctx context.Context, pool *pgxpool.Pool, name string, threshold float32) (match, error) {
	if id, ok := c.byLowerName[strings.ToLower(name)]; ok {
		return match{kind: matchExact, exerciseID: id, matchedName: name, similarity: 1.0}, nil
	}
	expanded := expandAbbreviations(name)
	if expanded != name {
		if id, ok := c.byLowerName[strings.ToLower(expanded)]; ok {
			return match{kind: matchExact, exerciseID: id, matchedName: expanded, similarity: 1.0}, nil
		}
	}

	best, err := bestFuzzy(ctx, pool, name)
	if err != nil {
		return match{}, err
	}
	if expanded != name {
		alt, err := bestFuzzy(ctx, pool, expanded)
		if err != nil {
			return match{}, err
		}
		if len(alt) > 0 && (len(best) == 0 || alt[0].sim > best[0].sim) {
			best = alt
		}
	}
	if len(best) == 0 {
		return match{kind: matchNone}, nil
	}
	top := best[0]
	m := match{kind: matchNone, topCandidate: top.name, topSim: top.sim}
	if top.sim < threshold {
		return m, nil
	}
	gapOK := len(best) < 2 || top.sim-best[1].sim >= 0.1
	if !gapOK && top.sim < 0.7 {
		return m, nil
	}
	m.kind = matchFuzzy
	m.exerciseID = top.id
	m.matchedName = top.name
	m.similarity = top.sim
	return m, nil
}

type candidate struct {
	id   string
	name string
	sim  float32
}

func bestFuzzy(ctx context.Context, pool *pgxpool.Pool, name string) ([]candidate, error) {
	rows, err := pool.Query(ctx,
		`SELECT id, name, similarity(name, $1::text) AS sim
		   FROM exercises
		  WHERE name % $1::text
		  ORDER BY sim DESC, name
		  LIMIT 3`,
		name,
	)
	if err != nil {
		return nil, fmt.Errorf("fuzzy search %q: %w", name, err)
	}
	defer rows.Close()
	var out []candidate
	for rows.Next() {
		var x candidate
		if err := rows.Scan(&x.id, &x.name, &x.sim); err != nil {
			return nil, err
		}
		out = append(out, x)
	}
	return out, rows.Err()
}

// expandAbbreviations rewrites the JN shorthand the catalog doesn't use.
// Only whole-word substitutions; partial-token matches would corrupt names.
var abbrev = map[string]string{
	"DB":  "Dumbbell",
	"BB":  "Barbell",
	"EZ":  "EZ-Bar",
	"RDL": "Romanian Deadlift",
	"OHP": "Overhead Press",
}

func expandAbbreviations(s string) string {
	parts := strings.Fields(s)
	for i, p := range parts {
		if rep, ok := abbrev[strings.ToUpper(p)]; ok {
			parts[i] = rep
		}
	}
	return strings.Join(parts, " ")
}
