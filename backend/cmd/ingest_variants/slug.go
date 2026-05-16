package main

import (
	"path/filepath"
	"regexp"
	"strings"
)

var nonSlug = regexp.MustCompile(`[^a-z0-9]+`)

// sourceSlug derives a stable identifier from an xlsx path.
//
//	".../The Essentials Program 4x.xlsx"                    -> jn_essentials_4x
//	".../ULTIMATE PPL .../The_Ultimate_Push_Pull_Legs_System_-_5x.xlsx" -> jn_ppl_5x
//	".../Edited PPL 5x.xlsx"                                -> jn_ppl_edited_5x
func sourceSlug(path string) string {
	base := strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
	lower := strings.ToLower(base)
	slug := nonSlug.ReplaceAllString(lower, "_")
	slug = strings.Trim(slug, "_")

	slug = strings.ReplaceAll(slug, "the_essentials_program", "essentials")
	slug = strings.ReplaceAll(slug, "essentials_program", "essentials")
	slug = strings.ReplaceAll(slug, "the_ultimate_push_pull_legs_system", "ppl")
	slug = strings.ReplaceAll(slug, "push_pull_legs", "ppl")
	slug = strings.ReplaceAll(slug, "edited_ppl", "ppl_edited")

	slug = nonSlug.ReplaceAllString(slug, "_")
	slug = strings.Trim(slug, "_")
	if slug == "" {
		slug = "jn"
	}
	return "jn_" + slug
}
