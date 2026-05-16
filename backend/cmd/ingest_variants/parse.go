package main

import (
	"fmt"
	"strings"

	"github.com/xuri/excelize/v2"
)

// rawHit is one prose name pulled from a sheet, along with where it came from.
type rawHit struct {
	raw   string // unnormalized cell text
	sheet string
	row   int
	col   int
}

// parseFile walks every sheet in the workbook and emits raw exercise names from
// the "Exercise" column plus the two "Substitution Option" columns.
func parseFile(path string) ([]rawHit, error) {
	f, err := excelize.OpenFile(path)
	if err != nil {
		return nil, fmt.Errorf("open: %w", err)
	}
	defer f.Close()

	var hits []rawHit
	for _, sheet := range f.GetSheetList() {
		rows, err := f.GetRows(sheet)
		if err != nil {
			return nil, fmt.Errorf("read sheet %q: %w", sheet, err)
		}
		hits = append(hits, extractFromSheet(sheet, rows)...)
	}
	return hits, nil
}

// extractFromSheet finds the header row, then yields raw cells from the
// exercise / substitution columns on every row after it.
func extractFromSheet(sheet string, rows [][]string) []rawHit {
	headerRow, cols := findHeader(rows)
	if headerRow < 0 || len(cols) == 0 {
		return nil
	}
	var hits []rawHit
	for r := headerRow + 1; r < len(rows); r++ {
		for _, c := range cols {
			if c >= len(rows[r]) {
				continue
			}
			cell := rows[r][c]
			if strings.TrimSpace(cell) == "" {
				continue
			}
			hits = append(hits, rawHit{raw: cell, sheet: sheet, row: r + 1, col: c + 1})
		}
	}
	return hits
}

// findHeader scans the first ~20 rows for a row containing the literal cell
// "Exercise" and returns its row index plus the column indices that carry
// exercise names (Exercise + both Substitution Option columns).
func findHeader(rows [][]string) (int, []int) {
	limit := len(rows)
	if limit > 20 {
		limit = 20
	}
	for r := 0; r < limit; r++ {
		var cols []int
		for c, cell := range rows[r] {
			switch strings.TrimSpace(cell) {
			case "Exercise", "Substitution Option 1", "Substitution Option 2":
				cols = append(cols, c)
			}
		}
		if len(cols) > 0 {
			return r, cols
		}
	}
	return -1, nil
}
