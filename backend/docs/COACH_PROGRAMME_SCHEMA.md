# Coach programme schema

Captured 2026-05-17. The contract between the Coach agent's `propose_programme` tool and the Flutter import pipeline. Pair with [`AGENT_ARCHITECTURE.md`](./AGENT_ARCHITECTURE.md).

## Goal

`propose_programme` produces JSON that the Flutter `ProgrammeJsonParser` (`lib/data/parsers/programme_json_parser.dart`) can swallow directly — same shape the bundled `assets/programmes/essentials_*.json` files use. After validation + normalization + block expansion, the JSON is a drop-in replacement for an imported programme.

## Two shapes — input and output

The LLM emits a compact **block** shape. The backend validates and expands it to a verbose **week** shape that matches the bundled JSON.

### LLM tool input — the block shape

```jsonc
{
  "name": "Coach: 4-day Push/Pull/Upper/Lower",
  "blocks": [
    {
      "block_number": 1,
      "weeks": [1, 2, 3, 4],
      "days": [
        {
          "day": "Push",
          "exercises": [
            {
              "exercise_id": "Barbell_Bench_Press_-_Medium_Grip",
              "name": "Barbell Bench Press - Medium Grip",
              "sets": 3,
              "reps": "8-10",
              "warmupSets": "2",
              "rpe": "7-8",
              "rest": "~3 min",
              "notes": "Moderate volume; control eccentric"
              // sub1, sub2, videoUrl, sub1VideoUrl, sub2VideoUrl optional
              // order optional — backend fills from array position
            }
          ]
        }
      ]
    },
    { "block_number": 2, "weeks": [5,6,7,8],   "days": [...] },
    { "block_number": 3, "weeks": [9,10,11,12], "days": [...] }
  ]
}
```

**Constraints the LLM must satisfy:**
- `blocks.length == 3`
- `blocks[i].weeks.length == 4`
- Union of all weeks across blocks is exactly `[1..12]` (no gaps, no dupes)
- Same exercise selection in every block per day (only prescriptions change between blocks)
- Day labels are meaningful (Push/Pull/Legs/Upper/Lower/Chest/Back/Shoulders/Arms/Full Body A/B/C). The validator rejects regex `(?i)^\s*(day|workout|session)\s*\d+\s*$`.
- Every `exercise_id` exists in the `exercises` catalog.

### Tool output — the expanded week shape

After validation + normalization + expansion, the handler returns:

```jsonc
{
  "status": "ok",
  "programme": {
    "name": "Coach: 4-day Push/Pull/Upper/Lower",
    "weeks": [
      {
        "week": 1,
        "days": [
          {
            "day": "Push",
            "exercises": [
              {
                "exercise_id": "Barbell_Bench_Press_-_Medium_Grip",
                "name": "Barbell Bench Press - Medium Grip",   // overwritten from catalog
                "order": 1,                                      // filled from array position
                "sets": 3,
                "reps": "8-10",
                "warmupSets": "2",
                "rpe": "7-8",
                "rest": "~3 min",
                "notes": "Moderate volume; control eccentric",
                "sub1": "",
                "sub2": "",
                "videoUrl": "",
                "sub1VideoUrl": "",
                "sub2VideoUrl": ""
              }
            ]
          }
        ]
      },
      { "week": 2,  "days": [...block-1 days, byte-identical to week 1...] },
      { "week": 3,  "days": [...block-1 days...] },
      { "week": 4,  "days": [...block-1 days...] },
      { "week": 5,  "days": [...block-2 days...] },
      // ...
      { "week": 12, "days": [...block-3 days...] }
    ]
  }
}
```

**Invariants the output guarantees:**
- `weeks.length == 12`, week numbers sorted ascending, exactly `[1..12]`.
- Within a block: weeks have byte-identical `days` arrays.
- Across blocks: same exercise ids per day; only prescriptions (`sets`/`reps`/`rpe` etc.) vary.
- Every exercise has all 14 fields present, even if empty string (`sub1`, `videoUrl`, etc.).
- `name` always equals the catalog's `exercises.name` (LLM-supplied name is overwritten).
- `order` is 1-based per day, contiguous.
- `exercise_id` is included for backend traceability; Flutter's parser ignores it.

### Error responses

```jsonc
// missing exercises
{
  "status": "invalid",
  "missing": ["Bogus_Exercise_Id"],
  "errors": ["exercises not found in catalog"]
}

// structural problems (caught before catalog check)
{
  "status": "invalid",
  "errors": [
    "blocks must have exactly 3 entries (got 2)",
    "block 1 weeks must have 4 entries"
  ]
}

// generic day label
{
  "status": "invalid",
  "errors": ["day name 'Day 1' is generic; use a meaningful label like Push/Pull/Legs/Upper/Lower"]
}
```

The LLM sees these as the tool result and self-corrects on the next turn.

## Field reference

Every exercise in the output:

| Field | Type | Meaning | Default if unset by LLM |
|---|---|---|---|
| `exercise_id` | string | Catalog row id; backend validates this | (required) |
| `name` | string | Display name | Overwritten from catalog row |
| `order` | int | 1-based position within the day | Filled from array index |
| `sets` | int | Working set count | (required) |
| `reps` | string | Rep range or count, e.g. `"8-10"` | (required) |
| `warmupSets` | string | Free-text, e.g. `"2"`, `"2-3"` | `""` |
| `rpe` | string | RPE/RIR target, e.g. `"7-8"` | `""` |
| `rest` | string | Rest period, e.g. `"~3 min"` | `""` |
| `notes` | string | Coach cues | `""` |
| `sub1` | string | Alternative exercise name (display) | `""` |
| `sub2` | string | Alternative exercise name (display) | `""` |
| `videoUrl` | string | Form-cue video for the main exercise | `""` |
| `sub1VideoUrl` | string | Video for `sub1` | `""` |
| `sub2VideoUrl` | string | Video for `sub2` | `""` |

String types throughout (not numbers) match the existing `Exercises` Drift table columns (everything but `weekNumber`, `sets`, `orderIndex` is text).

## Flutter integration contract

```dart
// 1. CoachScreen posts each user turn to /v1/agent/chat?mode=coach.
// 2. After every response, walk the trail looking for the propose_programme tool result.

bool _isProposeResult(Map<String, dynamic> message) =>
    message['role'] == 'tool' &&
    message['content'] is String &&
    (jsonDecode(message['content']) as Map)['status'] == 'ok';

// 3. When found, the .content is itself a JSON-encoded string:
final result = jsonDecode(toolMessage['content']) as Map<String, dynamic>;
if (result['status'] == 'ok') {
  final programmeJson = jsonEncode(result['programme']);
  // 4. Hand straight to the existing parser
  final companions = ProgrammeJsonParser.parse(programmeJson);
  // 5. Insert via the existing programme notifier
}
```

The Flutter parser already handles every key in the output. No parser changes required.

## Validation pipeline (server side)

```
1. JSON parse
2. Structural validation
   - exactly 3 blocks
   - each block.weeks.length == 4, ints
   - union of weeks == {1..12}
   - days.length >= 1, exercises.length >= 1
   - day labels not generic (regex check)
   - exercise required fields present
3. Catalog membership (batch: ExerciseExistsByIDs)
4. Normalization
   - name ← catalog row's name
   - empty strings fill optional fields
   - order ← array position if zero
5. Expansion
   - for each block, for each week in block.weeks:
       emit {week: N, days: <deep-copy of block.days>}
   - sort by week ascending
6. Return {status:"ok", programme:{name, weeks:[12]}}
```

Steps 2 and 3 short-circuit on failure. Step 5 cannot fail once 2 and 3 pass.

## Token cost (for reference)

The block shape is ~3× more compact than emitting 12 distinct weeks would be. With same-exercise-across-blocks, the per-block exercise list is the heaviest part; prescription deltas between blocks add maybe ~30% per block. Empirically for a 4-day × 5-exercise programme: input ~1500 tokens (block shape), expanded output ~4500 tokens — but the expanded output is server-side only, never travels through the LLM.

## Future evolution

- **Per-block `phase_focus` field.** Currently the system prompt names the blocks (accumulation/intensification/peak) but the JSON has no place for that. If a future UI wants to surface "Block 2: Intensification" in the day header, add an optional `phase` field to each `week` in the output. Flutter parser ignores unknown keys safely.
- **Deload weeks.** Real periodization usually has a deload at week 4 / 8 / 12. The current design treats all four weeks in a block as identical. If that becomes a UX request, the cleanest add is a `deload` boolean on the last week of each block + a separate prescription block for it.
- **Variant references.** Once `exercise_variants` is wired into `search_exercises`, the tool can emit a `variant_id` alongside `exercise_id` so the display name reflects the JN-style prose ("Pause Bench Press" vs "Bench Press").
