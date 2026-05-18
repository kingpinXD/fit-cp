# Coach integration handoff

For the Flutter agent picking up the `CoachScreen` build. Captured 2026-05-18 against `backend-phase1a` @ commit `e403d6a`.

This is the entry-point doc. It tells you what to build, where it slots, the wire contract, and where to look when you need depth. Pair with [`COACH_PROGRAMME_SCHEMA.md`](./COACH_PROGRAMME_SCHEMA.md) (programme JSON contract) and [`AGENT_ARCHITECTURE.md`](./AGENT_ARCHITECTURE.md) (server-side internals).

## What you're building

A "Coach" path on the start-programme screen. User taps **COACH**, chats with an AI that asks about their goals/equipment/injuries, and ends with a 12-week programme saved to local Drift exactly like an imported XLSX or a bundled programme.

The backend is **live, working, and tested end-to-end** at `https://fit-backend-1093127919791.us-central1.run.app`. Two real smoke tests passed (4-day no-injury → Full Body+PPL, 5-day with lower-back injury → PPL+Upper/Lower, no deadlifts). Your job is the Flutter side.

## Where the entry point goes

`lib/features/programme/programme_screen.dart` defines `_ImportVariant` (the no-programme-yet state). It currently has two buttons: `USE EXISTING` and `IMPORT PROGRAMME`. Add a third: `COACH` (style consistent — same height 52, same `BorderRadius(12)`, same width). Tap → push the new `CoachScreen`.

## CoachScreen states

```
┌────────────────────────────────────────────────────────┐
│  IntroState                                            │
│    title + 1-paragraph explainer                       │
│    [Start coach session]  [Cancel]                     │
└────────────────────────────────────────────────────────┘
                           │ Start
                           ▼
┌────────────────────────────────────────────────────────┐
│  ChatState                                             │
│    scrollable bubble list of messages                  │
│    input field + send button                           │
│    POST /v1/agent/chat?mode=coach on every send        │
│    show loading spinner while awaiting response        │
│    detect propose_programme tool result in trail       │
└────────────────────────────────────────────────────────┘
                           │ when status:"ok" in tool result
                           ▼
┌────────────────────────────────────────────────────────┐
│  PreviewState                                          │
│    render the 12-week programme as a table             │
│    summary line: "12 weeks · 4 days/week · …"          │
│    [Save & start]  [Keep chatting]  [Discard]          │
└────────────────────────────────────────────────────────┘
                           │ Save & start
                           ▼
                  navigate to main screen,
                  the new programme is the active one
```

`Keep chatting` keeps the same message history and lets the user say things like "swap the deadlift for a Romanian deadlift" — agent will call `propose_programme` again with the edit. `Discard` clears state, back to Intro.

## API contract

### Endpoint

`POST https://fit-backend-1093127919791.us-central1.run.app/v1/agent/chat`

Headers:
- `Content-Type: application/json`
- `Authorization: Bearer <firebase-id-token>` — same as `/v1/exercises`

### Request body

```jsonc
{
  "mode": "coach",                           // required to enable Coach mode
  "messages": [
    { "role": "user",      "content": "I want a 4-day hypertrophy programme..." },
    { "role": "assistant", "content": "...", "tool_calls": [...] },
    { "role": "tool",      "tool_call_id": "...", "content": "..." },
    { "role": "user",      "content": "Make day 3 easier" }
  ]
}
```

**Stateless.** Send the full message history every turn. Server has no session.

### Response body

```jsonc
{
  "reply": "Final assistant text shown to the user.",
  "messages": [
    /* full updated trail, including the system prompt prepended by the server */
    /* You append this back into your local history and post it on the next turn */
  ]
}
```

### Detecting "the programme is ready"

The agent calls a `propose_programme` tool when it's done. The result lands in the trail as a `role: "tool"` message whose `content` is itself a JSON-encoded object:

```dart
Map<String, dynamic>? extractProposedProgramme(List<Map<String, dynamic>> messages) {
  for (final msg in messages.reversed) {
    if (msg['role'] != 'tool') continue;
    final content = msg['content'];
    if (content is! String) continue;
    try {
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      if (parsed['status'] == 'ok' && parsed['programme'] is Map<String, dynamic>) {
        return parsed['programme'] as Map<String, dynamic>;
      }
    } catch (_) {
      continue;
    }
  }
  return null;
}
```

If `extractProposedProgramme(response['messages'])` returns non-null, switch to `PreviewState`. Otherwise stay in `ChatState` and show the `reply` as the assistant's next bubble.

### Importing the programme

The `programme` map is shape-compatible with the existing `ProgrammeJsonParser`. Save path:

```dart
final programme = extractProposedProgramme(response['messages']);
if (programme != null) {
  final programmeJson = jsonEncode(programme);
  final companions = ProgrammeJsonParser.parse(programmeJson);

  // Insert + bind through the existing programme notifier — same path as XLSX import
  await ref.read(programmeRepositoryProvider).saveProgramme(
    name: programme['name'] as String,
    rows: companions,
  );
  await ref.read(programmeNotifierProvider.notifier).switchProgramme(
    programme['name'] as String,
  );
  Navigator.of(context).pop();
}
```

(Adjust `saveProgramme` to whatever the existing repository method is — match the path `import_helper.applyImport` uses today.)

## Error handling

| Server response | Cause | Suggested UX |
|---|---|---|
| `401` `{"error":{"code":"unauthorized"}}` | Token expired or missing | Refresh Firebase token, retry once |
| `400` `{"error":{"code":"invalid_mode"}}` | `mode` not "coach"/"chat" | Bug — fix the client |
| `400` `{"error":{"code":"invalid_request"}}` | Empty `messages`, includes `system` role, etc. | Bug — fix the client |
| `500` `{"error":{"code":"agent_error"}}` | OpenAI failed / loop blew up | Toast "Coach is having trouble. Try again in a moment." |
| `500` `{"error":{"code":"agent_max_iterations"}}` | Model couldn't converge on a valid programme in 10 iterations | Toast "Couldn't generate a programme. Try rephrasing." |
| `200` with no `propose_programme` tool result yet | Agent is still gathering info | Stay in chat, show `reply` as the next bubble |
| `200` with last tool result `status: "invalid"` | Validator rejected the model's most recent attempt, model didn't get a chance to correct | Rare — usually the model self-corrects within the same request. If seen, treat like `agent_error` |
| `200` with `propose_programme` tool result `status: "ok"` | Programme ready | Transition to `PreviewState` |

## Local development

Start the backend locally:

```bash
cd backend
make docker-up                # Postgres on :5432
make migrate-up               # schema
make seed                     # 873 exercises
OPENAI_API_KEY=sk-proj-... AUTH_DISABLED=true make run
```

`AUTH_DISABLED=true` bypasses Firebase verification — useful for Flutter dev without signed-in users. Point your Flutter base URL at `http://10.0.2.2:8080` (Android emulator → host) or `http://localhost:8080` (desktop).

Quick sanity check the local server works:

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"mode":"coach","messages":[{"role":"user","content":"4-day hypertrophy programme, intermediate, full gym, no injuries. Generate now."}]}' \
  http://localhost:8080/v1/agent/chat | jq .reply
```

Expect: a final assistant reply + a complete 12-week programme inside the `tool` result. ~1-3 minutes wall time.

## Things to know going in

- **Wall time is 1-3 minutes per generate.** Show a clear loading state with a timer. The OpenAI roundtrips + ~5-15 tool calls + 12-week JSON output add up.
- **Token-cost-wise it's still cheap.** Each Coach run is well under a cent at `gpt-4o-mini` rates.
- **No streaming yet.** Wait for the full response. Streaming is a future enhancement.
- **The model uses canonical catalog vocabulary** (`muscle: "chest"`, `equipment: "barbell"`, `level: "intermediate"`). If users say "give me more arm work", the model maps mentally — you don't need to translate.
- **Day labels are validator-enforced**: 1-3 days = Full Body, 4 = FB+PPL, 5 = PPL+UL, 6 = PPL×2. Same labels across all 3 blocks.
- **Exercises may vary between blocks**, prescriptions always vary.
- **Injury mention** triggers exercise exclusion (model-driven) but RPE cap and equipment preference are prompt-only and unreliable today. If the user says "I have a bad back" and the programme still has heavy deadlifts at RPE 9, that's a known soft-rule miss — not a Flutter bug.

## Sample prompts for testing

```
"4-day per week hypertrophy programme. Intermediate, full gym, no injuries. Build it."
→ Full Body + Push + Pull + Legs

"5-day intermediate hypertrophy, full gym, lower-back injury, no deadlifts or RDLs."
→ Push + Pull + Legs + Upper + Lower, no deadlift/RDL exercises

"3 days a week, beginner, dumbbells only, want to build muscle."
→ Full Body A + Full Body B + Full Body C, dumbbell-friendly selections

"6 days strength + hypertrophy, intermediate, full gym."
→ Push + Pull + Legs + Push + Pull + Legs

"Tweak: change Lat Pulldown to Cable Row across all blocks."
→ Agent calls propose_programme again with the edit
```

## Open issues to bubble back to backend

Surface anything that needs server changes back to the backend agent:

1. RPE cap for injuries isn't enforced (prompt-only, model ignores it)
2. Equipment preference for injuries isn't enforced (same)
3. Variant catalog is populated locally but empty in prod — variants aren't wired into `search_exercises` yet, but if you ever want to display "Pause Squat" instead of "Squat", that data exists
4. Stream-mode support — Flutter UX would benefit from incremental token streaming when you're ready to invest

## Reference

| Topic | Doc |
|---|---|
| Server-side agent design | [`AGENT_ARCHITECTURE.md`](./AGENT_ARCHITECTURE.md) |
| Programme JSON wire format (every field, validation rules, expansion semantics) | [`COACH_PROGRAMME_SCHEMA.md`](./COACH_PROGRAMME_SCHEMA.md) |
| Why the catalog looks the way it does | [`PROGRAMME_DATA_INVESTIGATION.md`](./PROGRAMME_DATA_INVESTIGATION.md) |
| Anuma SDK gap analysis (when we eventually swap providers) | [`ANUMA_OPENAI_GAPS.md`](./ANUMA_OPENAI_GAPS.md) |
| Provider / framework landscape | [`AGENT_FRAMEWORKS.md`](./AGENT_FRAMEWORKS.md) |

## Status snapshot

- **Backend live:** `https://fit-backend-1093127919791.us-central1.run.app`, revision `fit-backend-00019-hn5` family
- **Branch:** `backend-phase1a` on `origin`
- **Auth:** Firebase ID tokens on `/v1/*`
- **Both smoke tests pass** (4-day no-injury, 5-day with injury)
- **Validator catches** all structural rule violations including the split table; LLM self-corrects within 1-2 retries
- **Open soft-rule misses:** RPE cap, equipment preference under injury — not blocking
