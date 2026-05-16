package main

import (
	"regexp"
	"strings"
)

// supersetPrefix matches superset markers like "A1: ", "B2: ", "C3:	".
var supersetPrefix = regexp.MustCompile(`^[A-Z]\d:\s+`)

// trailingParen matches a single (...) group at the end of the name, e.g. "(Heavy)".
var trailingParen = regexp.MustCompile(`\s*\([^()]*\)\s*$`)

// extracted result of normalizing a raw cell.
type extracted struct {
	name        string // canonical-ish prose name, modifiers stripped
	description string // text from the first stripped (...) modifier, if any
}

// normalize cleans a single raw exercise cell into a stable prose name plus an
// optional description containing whatever modifier was peeled off the end.
// It returns ok=false for cells that don't carry an exercise name at all
// (empty, header echoes, instruction blobs).
func normalize(raw string) (extracted, bool) {
	s := strings.TrimSpace(raw)
	if s == "" {
		return extracted{}, false
	}
	if !looksLikeExerciseName(s) {
		return extracted{}, false
	}

	s = supersetPrefix.ReplaceAllString(s, "")

	if i := strings.Index(s, "["); i >= 0 {
		s = strings.TrimSpace(s[:i])
	}

	var desc string
	for {
		m := trailingParen.FindString(s)
		if m == "" {
			break
		}
		modifier := strings.TrimSpace(strings.Trim(strings.TrimSpace(m), "()"))
		if desc == "" {
			desc = modifier
		}
		s = strings.TrimSpace(strings.TrimSuffix(s, m))
	}

	s = collapseWhitespace(s)
	if s == "" {
		return extracted{}, false
	}
	return extracted{name: s, description: desc}, true
}

// looksLikeExerciseName filters obvious non-names: pure numbers, very long blobs,
// header words, "rest day" markers. We err on the side of letting things through;
// the canonicalize step will drop anything the catalog can't recognize.
func looksLikeExerciseName(s string) bool {
	if len(s) > 80 {
		return false
	}
	lower := strings.ToLower(s)
	switch lower {
	case "exercise", "warm-up sets", "working sets", "reps", "load", "rpe",
		"rest", "substitution option 1", "substitution option 2", "notes":
		return false
	}
	if strings.HasPrefix(lower, "suggested ") || strings.Contains(lower, "rest day") {
		return false
	}
	hasLetter := false
	for _, r := range s {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') {
			hasLetter = true
			break
		}
	}
	return hasLetter
}

func collapseWhitespace(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	prevSpace := false
	for _, r := range s {
		if r == ' ' || r == '\t' || r == '\n' || r == '\r' {
			if !prevSpace {
				b.WriteByte(' ')
			}
			prevSpace = true
			continue
		}
		b.WriteRune(r)
		prevSpace = false
	}
	return strings.TrimSpace(b.String())
}
