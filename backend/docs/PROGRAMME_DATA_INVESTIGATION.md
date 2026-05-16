# Programme data investigation (Jeff Nippard library)

Captured 2026-05-16 from a code investigation of `~/Downloads/Excersise List` — Jeff Nippard's complete published programme library. Pairs with [`AGENT_ARCHITECTURE.md`](./AGENT_ARCHITECTURE.md); informs the Coach feature design and the question of how much catalog/programme data to ingest into the backend.

## Inventory

- **21 XLSX** programme spreadsheets (the structured data)
- **57 PDF** programme manuals + technique guides (prose — out of scope for ingestion)
- 9 top-level categories: Essentials, High-Frequency Full Body, PPL (Ultimate System), Powerbuilding (3 versions), Pure Bodybuilding (Phase 1 + 2), Upper/Lower, Body-Part specialization, Women's, Powerlifting/Strength

## XLSX shape (consistent across files)

All 21 XLSX files follow roughly the same template:

| Column | Example values |
|---|---|
| Week | `Week 1` … `Week N` (or implicit) |
| Day / Workout | `Upper`, `Lower`, `Legs #1`, `Push`, `Pull`, `Lower Focused Full Body` |
| Exercise | `Flat DB Press (Heavy)`, `Pause Squat (Back off)`, `A1: EZ Bar Skull Crusher` |
| Warmup Sets | `2`, `3` |
| Working Sets | `3`, `4-5` |
| Reps | `4-6`, `8-10`, `12-15 (dropset)` |
| Load | numeric, `85% 1RM`, blank for user-relative |
| RPE | `7`, `8`, `9` |
| Rest | `~3 min`, `~1.5 min` |
| Substitution 1 / 2 | `Machine Chest Press`, `Weighted Dip` |
| Notes | form cues, dropset instructions, mind-muscle prompts |

Some files use multiple sheets per phase (PPL Ultimate System has 3 phases × 1 sheet each).

## Naming patterns

Roughly four families, all reducible to a canonical base name + modifiers:

1. **Simple** — `Back Squat`, `Bench Press`, `Lat Pulldown`
2. **Modifier prefix** — `Pause Squat`, `Incline DB Press`, `Machine Chest Press`
3. **Modifier suffix** — `(Heavy)`, `(Back off)`, `(Failure Set)`, `(AMRAP)`, `(Top Set)`
4. **Pairing notation** — `A1:` / `A2:` for supersets; `[or front squat]` bracket alternatives

## Exercise vocabulary findings

- **~200-250 unique exercise names** after deduplicating modifier suffixes
- **~80% overlap** with the existing free-exercise-db catalog (873 exercises) — back squat, bench press, deadlift, common rows/curls/presses all present
- **~20% gap** — specialised strength variants (Pause Squat, Pin Squat, Reset Deadlift), machine-specific (Kelso Shrug, Omni-Grip Pulldown), unusual isolations (N1-Style Cross-Body Triceps Extension, Bayesian Cable Curl, Egyptian Lateral Raise)

## The central problem: naming canonicalization

The existing catalog uses machine slugs like `Barbell_Bench_Press_-_Medium_Grip`. The XLSX files use human prose like `Flat DB Press (Heavy)`. There's no automated reliable mapping between the two. Options:

- **Fuzzy match + manual curation** — embedding-based or trigram similarity, with a human review pass
- **Lookup table** — explicit `prose_name → catalog_id` map maintained as a JSON file
- **Variant-as-row** — model the prose names as `exercise_variants` rows that reference a canonical `exercises.id`

The variant approach is cleanest because it preserves the prose names (which the user already recognises from JN's programmes) while still resolving to the canonical catalog entry.

## Proposed minimal schema (catalog enrichment, no programme templates yet)

```sql
CREATE TABLE exercise_variants (
  id           bigserial PRIMARY KEY,
  exercise_id  text NOT NULL REFERENCES exercises(id),
  variant_name text NOT NULL,
  description  text,
  source       text,  -- 'jeff_nippard_essentials', 'jeff_nippard_ppl', ...
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (exercise_id, variant_name)
);

CREATE INDEX idx_exercise_variants_name ON exercise_variants USING gin (variant_name gin_trgm_ops);
```

That's the only change needed for v1 Coach. The model can call `search_exercises` for canonical exercises, and we expose top-N variants per exercise alongside the result if useful.

## Programme templates (deferred)

The fuller schema in the investigation proposal — `programmes`, `programme_phases`, `programme_weeks`, `programme_days`, `programme_exercises` — is the eventual destination. It captures the *structure* of how JN sequences exercises, which the Coach agent could reference as a knowledge base.

**Skipping it for v1** because:

1. The LLM can compose competent programmes from scratch using just `search_exercises`, without templates
2. The full ingest is non-trivial (~2-3 days of work — parser + canonicalization + manual review)
3. We don't yet know what users actually want from Coach — premature to optimise the data model around guesses
4. Schema for programme templates is much easier to design *after* we see real Coach output and which structures we wish the agent referenced

When we revisit (probably Phase 3 of agent work):
- Decide whether to store templates relationally (the proposed schema) or as JSON blobs keyed by slug
- Decide whether progression is explicit (week-by-week values) or rule-based ("week N: +1 rep from week N-1")
- Decide canonicalization strategy (fuzzy match + curation vs strict lookup)

## Open questions (for future iterations)

1. **Where do video URLs live?** XLSX cells contain embedded hyperlinks. If we ever ingest, we'd want these in an `exercise_resources` table keyed by `exercise_id` + optional `variant_id`.
2. **Load prescription parsing.** Loads mix raw numbers, `%1RM`, and RPE in one column. A real ingest needs `load_type` + `load_value` (or just preserve as text and let the agent reason).
3. **Alternative-exercises notation.** Bracket alternatives (`[or box squat]`) and superset pairs (`A1` / `A2`) need representation if we ingest programme templates.

## Risk: keeping the catalog clean

If we add `exercise_variants` rows mined from JN's vocabulary, we're embedding one coach's naming opinions into the catalog. Risks:
- Variants like "Pause Squat" may belong to a specialised methodology that isn't right for casual users
- Source attribution (`source = 'jeff_nippard_*'`) lets us filter, but we have to remember to do it

For v1, scoped ingestion of variants from the Essentials and PPL programmes is enough — those are the most user-applicable. Skip the specialised body-part programs unless a specific use case demands them.
