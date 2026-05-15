# Agent architecture

Captured 2026-05-14. Describes the agent loop that powers `POST /v1/agent/chat`. Pair with [`AGENT_FRAMEWORKS.md`](./AGENT_FRAMEWORKS.md) for the wider landscape that informed these decisions.

## Goal

Let a user prompt produce a useful fitness response by giving an LLM access to the exercise catalog as a tool. Stateless on the server, swappable to a different LLM provider later, dead simple to add tools to.

## Package layout

```
backend/internal/
├── agent/
│   ├── client.go           # LLMClient interface, OpenAI impl, Message types,
│   │                       # role + finish-reason constants, system prompt
│   ├── client_test.go      # stubClient + canned-response helpers used by all tests
│   ├── loop.go             # Run(): the tool-use loop itself
│   ├── loop_test.go        # loop behaviour against stubClient
│   ├── tools.go            # tool Registry + searchExercises handler
│   ├── tools_test.go       # tool behaviour against the real seeded Postgres
│   └── handler.go          # POST /v1/agent/chat handler (input parse → Run → JSON out)
└── httpio/
    ├── errors.go           # WriteJSON, WriteError — shared by httpx and agent
    └── requestid.go        # X-Request-Id header + context helpers
```

`httpio` is a leaf package that depends on nothing internal. Both `httpx` and `agent` import it, which is why the previous import cycle (httpx ↔ agent through shared error helpers) is gone.

## How a request flows

```
client
  │  POST /v1/agent/chat
  │  Authorization: Bearer <firebase-id-token>
  │  body: { "messages": [ {"role":"user","content":"..."} ], "model": "gpt-4o-mini" }
  ▼
[ RecoverMiddleware → RequestIDMiddleware → LoggerMiddleware → AuthMW ]
  ▼
agent.Handler.Chat
  │  validate (non-empty, no client-supplied system messages, size)
  │  hand off to:
  ▼
agent.Run(ctx, client, registry, request)
  │
  │  prepend system message
  │
  │  ┌─────────── iteration 0 ──────────────────────────────────────┐
  │  │  client.Chat(messages, tools)                                │
  │  │  ┌──────────────────────────────────────────────────────────┐│
  │  │  │ openaiClient translates Message → SDK type, calls API,   ││
  │  │  │ translates SDK response → Message + finish_reason        ││
  │  │  └──────────────────────────────────────────────────────────┘│
  │  │  if finish_reason == "stop": return Reply, full Messages    │
  │  │  if finish_reason == "tool_calls":                          │
  │  │     errgroup.Go(...) one goroutine per tool_call             │
  │  │     each runs registry.Execute(name, args) → JSON string     │
  │  │     errors → genericToolErrorJSON (raw err logged via slog)  │
  │  │     append one tool-role Message per call, in original order │
  │  └─────────── iteration 1 ──────────────────────────────────────┘
  │  ...
  │  hard cap at 10 iterations → ErrMaxIterations
  │
  ▼
handler writes:
  {
    "reply": "...final assistant text...",
    "messages": [ ...complete trail incl. system+user+assistant+tool turns... ]
  }
```

## The loop itself (loop.go)

```go
for i := 0; i < maxIterations; i++ {
    resp := client.Chat(ctx, ChatRequest{model, messages, tools})
    messages = append(messages, resp.Message)

    if resp.FinishReason == FinishReasonStop || len(resp.Message.ToolCalls) == 0 {
        return Response{Messages: messages, Reply: resp.Message.Content}
    }

    // dispatch all tool_calls in parallel, preserve order
    results := make([]Message, len(resp.Message.ToolCalls))
    g, gctx := errgroup.WithContext(ctx)
    for idx, tc := range resp.Message.ToolCalls {
        g.Go(func() error {
            out, err := registry.Execute(gctx, tc.Function.Name, tc.Function.Arguments)
            if err != nil {
                slog.Error("tool failed", "tool", tc.Function.Name, "err", err, "request_id", ...)
                out = genericToolErrorJSON
            }
            results[idx] = Message{Role: RoleTool, ToolCallID: tc.ID, Content: out}
            return nil
        })
    }
    g.Wait()
    messages = append(messages, results...)
}
return ErrMaxIterations
```

Why these specific choices:

- **Goroutines never return errors.** Each tool's error is captured into its own `results[idx]` as the generic JSON shape. This means errgroup never cancels sibling goroutines mid-flight — one slow/broken tool doesn't take down the others.
- **Slice indexed by position.** Tool call order matters: the model may reference results positionally (`"the second result has..."`). Concurrent writes to disjoint slice indices are safe; no mutex needed.
- **`ctx` threads end-to-end.** HTTP request cancellation propagates into the OpenAI call and into every Postgres query in flight.
- **maxIterations = 10.** Real flows finish in 1–3 turns. Ten is loose enough for legitimate edge cases (e.g., model dispatching a few tools in sequence) and tight enough that a misbehaving model cannot rack up a hundred OpenAI calls.

## LLMClient interface

```go
type LLMClient interface {
    Chat(ctx context.Context, req ChatRequest) (ChatResponse, error)
}
```

The package's `Message`, `ToolCall`, `FunctionCall`, `ChatRequest`, `ChatResponse` are **agent-package types**, not OpenAI SDK types. The OpenAI implementation translates back and forth inside `openaiClient.Chat`. The translation is real overhead (~130 lines) but it's the only thing standing between fit-cp and an OpenAI SDK breaking change. It's also exactly the seam where an Anthropic or Anuma implementation would land — same `Chat` method, different translation.

The role names and finish reasons that appear on the wire are centralized:

```go
const (
    RoleSystem    = "system"
    RoleUser      = "user"
    RoleAssistant = "assistant"
    RoleTool      = "tool"

    FinishReasonStop      = "stop"
    FinishReasonToolCalls = "tool_calls"
)
```

These happen to match OpenAI's spelling. If we add an Anthropic implementation, its translator maps Anthropic's content blocks into these same identifiers — the loop stays unchanged.

## Adding a new tool

1. **Implement a handler** with signature `func(ctx context.Context, args json.RawMessage) (string, error)`. The args is raw JSON; unmarshal into a struct shaped to your tool's parameters. Return JSON the model should see.

   ```go
   func generateProgrammeTool(q *db.Queries) ToolHandler {
       return func(ctx context.Context, raw json.RawMessage) (string, error) {
           var args struct {
               Days       int    `json:"days"`
               Experience string `json:"experience"`
           }
           if err := json.Unmarshal(raw, &args); err != nil {
               return "", err
           }
           // ... build programme, marshal, return
       }
   }
   ```

2. **Define the schema** the model sees:

   ```go
   ToolDef{
       Name:        "generate_programme",
       Description: "Generate a workout split given days/week and experience level.",
       Parameters: map[string]any{
           "type": "object",
           "properties": map[string]any{
               "days":       map[string]any{"type": "integer", "minimum": 1, "maximum": 7},
               "experience": map[string]any{"type": "string", "enum": []string{"beginner", "intermediate", "expert"}},
           },
           "required": []string{"days", "experience"},
       },
   }
   ```

3. **Register both** in `NewRegistry`:

   ```go
   r.Register(generateProgrammeDef(), generateProgrammeTool(queries))
   ```

4. **Tool handlers must be concurrent-safe.** The loop may dispatch several at once. If your handler touches shared mutable state (a counter, a cache, anything not the pgx pool), wrap with a mutex or rethink the design. The pgx pool itself is safe — that's why the existing `search_exercises` needs no synchronization.

## Adding a new LLM provider

1. Implement `LLMClient`:

   ```go
   type anthropicClient struct { /* ... */ }
   func (c *anthropicClient) Chat(ctx context.Context, req ChatRequest) (ChatResponse, error) {
       // translate ChatRequest.Messages → Anthropic content blocks
       // call anthropic-sdk-go
       // translate response.content blocks → ChatResponse.Message
       // translate stop_reason → FinishReason*
   }
   ```

2. Wire it in `cmd/server/main.go` behind a config flag (e.g. `LLM_PROVIDER=anthropic`). Don't introduce a runtime registry of providers; one impl per deployment is enough.

3. The loop, the tool registry, and the handler don't change.

## Prompt caching

OpenAI's automatic prompt cache hits when the **prefix** of consecutive requests is ≥1024 tokens and identical byte-for-byte. The agent is structured to maximise hits:

- `systemPrompt` is a `const string` — exact same bytes every request.
- Tool definitions are built once at startup in `NewRegistry`, not per-request.
- The first conversation turn (`user` message) varies, but the system prompt + tools that precede it don't.

This is "free" caching — no configuration, no headers, just prefix stability. Cached tokens are billed at ~10% the normal input rate.

We don't yet cache **tool results** at the application layer. That's a future optimization for things like taxonomy queries that change rarely. Not worth the cache-invalidation complexity for v1.

## Concurrency model

| Layer | Concurrency | Safety contract |
|---|---|---|
| HTTP handler | one goroutine per request (stdlib) | Stateless — no fields on `API` mutate after `NewAPI` |
| `Run` loop | one goroutine per request | Locals only; no shared state with sibling requests |
| Tool dispatch (within one loop iteration) | one goroutine per `tool_call` via errgroup | Handlers MUST be safe to call concurrently |
| OpenAI SDK | internal HTTP connection pool | Reused across requests |
| pgx pool | as configured | Concurrent reads are fine; writes serialize at the row level |

The handler doesn't hold any mutable state past startup. The OpenAI client and tool registry are constructed once in `main.go` and passed in.

## Deliberately out of scope (v1)

- **Streaming.** The endpoint returns the full response in one shot. SSE adds enough complexity in Go that it's worth its own change.
- **Conversation persistence.** Client passes the full message list each turn. No server-side session table. Lets us deploy fresh code without migrating "live" conversations.
- **Multiple tools.** Just `search_exercises`. Programme generation, exercise swaps, and progress tracking are future tools.
- **Token / cost logging.** Per the user, skipping the observability layer at v1. OpenAI's dashboard + a hard spend limit on the key is the safety net.
- **Multi-provider runtime swap.** Build-time choice only. No `LLM_PROVIDER` env var yet because there's nothing to swap to.
- **Anthropic / Anuma implementations.** Interface is shaped for them, but no code yet.
- **Tool result caching.** Free OpenAI prompt caching covers the prefix; per-tool result caching is later optimization.

## Open questions for the next iteration

1. **How structured should programme output be?** A free-text reply is fine for chat ("here are 3 exercises..."), but for "generate a 4-day split" the client probably wants a typed JSON object. Options: a `generate_programme` tool whose JSON return shape *is* the programme, OR `response_format: json_schema` on the final assistant turn. Worth deciding before building the second tool.
2. **Where does conversation memory live when we add it?** Likely a Postgres table keyed by `(user_uid, conversation_id)`. Worth designing the schema before users get attached to the stateless shape.
3. **Streaming UX in Flutter.** Once we add streaming, Flutter needs an SSE-compatible HTTP client. `fetch_client` + `EventSource` package on Dart side — there's prior art.
4. **Tool budget.** Beyond `maxIterations`, should we cap per-request total tokens or wall-clock time? Cloud Run already caps at 30s per the deploy script; that's a soft floor.

## Pointers

- Code: `backend/internal/agent/` and `backend/internal/httpio/`
- Wire helpers: [`httpio/errors.go`](../internal/httpio/errors.go)
- Tests: same dirs, `*_test.go`
- Related docs: [`ANUMA_GAPS.md`](./ANUMA_GAPS.md), [`ANUMA_OPENAI_GAPS.md`](./ANUMA_OPENAI_GAPS.md), [`AGENT_FRAMEWORKS.md`](./AGENT_FRAMEWORKS.md)
