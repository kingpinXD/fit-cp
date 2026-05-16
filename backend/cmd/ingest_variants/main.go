package main

import (
	"bufio"
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/kingpinXD/fit-cp/backend/internal/db"
)

// inputRoots are the only directories the CLI will scan. Anything else is ignored
// even if a future caller passes a different path.
var inputRoots = []string{
	"/Users/tanmay/Downloads/Excersise List/The Essentials Program",
	"/Users/tanmay/Downloads/Excersise List/PPL Programs",
}

type config struct {
	dbURL           string
	dryRun          bool
	threshold       float64
	reportUnmatched string
	roots           []string
}

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stderr, nil))
	slog.SetDefault(logger)

	cfg, err := parseFlags()
	if err != nil {
		logger.Error("flags", "err", err)
		os.Exit(2)
	}
	if err := run(cfg); err != nil {
		logger.Error("ingest failed", "err", err)
		os.Exit(1)
	}
}

func parseFlags() (config, error) {
	var c config
	flag.StringVar(&c.dbURL, "db", os.Getenv("DATABASE_URL"), "Postgres connection string (defaults to $DATABASE_URL)")
	flag.BoolVar(&c.dryRun, "dry-run", false, "parse and report without writing variants")
	flag.Float64Var(&c.threshold, "threshold", 0.4, "trigram similarity threshold for fuzzy matches")
	flag.StringVar(&c.reportUnmatched, "report-unmatched", "", "path to write unmatched names; default is stderr")
	flag.Parse()

	if c.dbURL == "" {
		return c, errors.New("--db or $DATABASE_URL is required")
	}
	c.roots = inputRoots
	return c, nil
}

func run(cfg config) error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()

	files, err := discoverXLSX(cfg.roots)
	if err != nil {
		return fmt.Errorf("discover: %w", err)
	}
	if len(files) == 0 {
		return errors.New("no xlsx files found under input roots")
	}
	slog.Info("discovered files", "count", len(files))

	pool, err := pgxpool.New(ctx, cfg.dbURL)
	if err != nil {
		return fmt.Errorf("connect: %w", err)
	}
	defer pool.Close()

	cat, err := loadCatalog(ctx, pool)
	if err != nil {
		return err
	}
	slog.Info("loaded catalog", "rows", len(cat.byLowerName))

	w, closeReport, err := openReport(cfg.reportUnmatched)
	if err != nil {
		return fmt.Errorf("open report: %w", err)
	}
	defer closeReport()

	stats := runStats{}
	for _, path := range files {
		if err := processFile(ctx, pool, cat, cfg, path, w, &stats); err != nil {
			return fmt.Errorf("process %s: %w", filepath.Base(path), err)
		}
	}
	stats.print(len(files), cfg.dryRun)
	return nil
}

// runStats collects counters surfaced in the end-of-run summary.
type runStats struct {
	rawHits      int
	uniqueNames  int
	exact        int
	fuzzy        int
	unmatched    int
	inserted     int
	updated      int
	seenVariants map[string]struct{} // (source|name) keys for dedupe within a run
}

func (s *runStats) markSeen(source, name string) bool {
	if s.seenVariants == nil {
		s.seenVariants = make(map[string]struct{}, 1024)
	}
	k := source + "|" + name
	if _, ok := s.seenVariants[k]; ok {
		return false
	}
	s.seenVariants[k] = struct{}{}
	return true
}

func (s *runStats) print(fileCount int, dryRun bool) {
	matched := s.exact + s.fuzzy
	pctExact, pctFuzzy := 0.0, 0.0
	if matched > 0 {
		pctExact = 100 * float64(s.exact) / float64(matched)
		pctFuzzy = 100 * float64(s.fuzzy) / float64(matched)
	}
	verb := "Inserted"
	if dryRun {
		verb = "Would insert"
	}
	fmt.Printf("\nParsed %d files, %d raw hits, %d unique prose names.\n", fileCount, s.rawHits, s.uniqueNames)
	fmt.Printf("Matched: %d (%.0f%% exact, %.0f%% fuzzy)\n", matched, pctExact, pctFuzzy)
	fmt.Printf("Unmatched: %d (see unmatched report)\n", s.unmatched)
	fmt.Printf("%s: %d new variants, %d updated existing.\n", verb, s.inserted, s.updated)
}

// processFile walks one xlsx, normalizes every prose name, canonicalizes it
// against the catalog, and writes either an inserted variant or an unmatched
// report line.
func processFile(ctx context.Context, pool *pgxpool.Pool, cat *catalog, cfg config, path string, report io.Writer, stats *runStats) error {
	source := sourceSlug(path)
	hits, err := parseFile(path)
	if err != nil {
		return err
	}
	stats.rawHits += len(hits)

	q := db.New(pool)
	for _, h := range hits {
		ext, ok := normalize(h.raw)
		if !ok {
			continue
		}
		if !stats.markSeen(source, ext.name) {
			continue
		}
		stats.uniqueNames++

		m, err := cat.canonicalize(ctx, pool, ext.name, float32(cfg.threshold))
		if err != nil {
			return err
		}
		switch m.kind {
		case matchExact:
			stats.exact++
		case matchFuzzy:
			stats.fuzzy++
		default:
			stats.unmatched++
			fmt.Fprintf(report, "[%s] %s -> %s (similarity=%.2f)\n", source, ext.name, m.topCandidate, m.topSim)
			continue
		}

		if cfg.dryRun {
			stats.inserted++ // counted as "would insert" in the summary
			continue
		}
		inserted, err := q.UpsertExerciseVariant(ctx, db.UpsertExerciseVariantParams{
			ExerciseID:  m.exerciseID,
			VariantName: ext.name,
			Description: textOrNull(ext.description),
			Source:      source,
		})
		if err != nil {
			return fmt.Errorf("upsert %q: %w", ext.name, err)
		}
		if inserted {
			stats.inserted++
		} else {
			stats.updated++
		}
	}
	return nil
}

// discoverXLSX walks the input roots and returns all .xlsx files, sorted for
// stable run output.
func discoverXLSX(roots []string) ([]string, error) {
	var out []string
	for _, root := range roots {
		err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() {
				return nil
			}
			if strings.EqualFold(filepath.Ext(path), ".xlsx") && !strings.HasPrefix(d.Name(), "~$") {
				out = append(out, path)
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
	}
	sort.Strings(out)
	return out, nil
}

func openReport(path string) (io.Writer, func(), error) {
	if path == "" {
		return os.Stderr, func() {}, nil
	}
	f, err := os.Create(path)
	if err != nil {
		return nil, nil, err
	}
	bw := bufio.NewWriter(f)
	return bw, func() { _ = bw.Flush(); _ = f.Close() }, nil
}

func textOrNull(s string) pgtype.Text {
	if s == "" {
		return pgtype.Text{}
	}
	return pgtype.Text{String: s, Valid: true}
}
