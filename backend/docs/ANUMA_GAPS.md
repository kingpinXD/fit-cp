# Anuma platform gaps for fit-cp Phase 2 agent

Captured 2026-05-13 from a code investigation of `anuma-sdk` and `ai-portal`. Investigation premise: "if fit-cp's Go agent is written against Anthropic's Messages API, what does Anuma need to change so we can swap the API key + base URL and have it work?"

## TL;DR

Anuma's `/api/v1/chat/completions` is **OpenAI-shaped**, not Anthropic-shaped. So the original framing is wrong — we shouldn't write fit-cp against Anthropic's SDK and expect a key-swap to land on Anuma. The actually-easy path is the inverse: write fit-cp against the **OpenAI Go SDK**, leave the model selection in the request body, and Anuma's gateway routes to whichever provider hosts that model (Anthropic via Bifrost, OpenAI, Gemini, Fireworks). Then the swap really is base URL + API key.

Anuma supports `X-API-Key` service-to-service auth today, so no user-OAuth shenanigans. That part is good.

## What works on day one

With zero changes to anuma-sdk / ai-portal:

- fit-cp Go service uses the OpenAI Go SDK
- Base URL is configurable (`OPENAI_BASE_URL` env)
- Tools defined in OpenAI shape (`{type: "function", function: {name, description, parameters}}`)
- Tool loop runs inside fit-cp's Go process — it queries Postgres, formulates `tool_result`, sends next request
- `X-API-Key` header for auth
- Streaming over SSE in OpenAI's format

## Evidence

| Question | Answer | Source |
|---|---|---|
| Is there a `/chat/completions` endpoint? | Yes, `/api/v1/chat/completions` | `ai-portal/internal/api/router.go:238` |
| Tool format on the wire | OpenAI shape (`tools[].type == "function"`, `tool_calls[]` in response) | `ai-portal/pkg/llmapi/requests.go` |
| Service-to-service auth | `X-API-Key` header verified against app store | `ai-portal/.../auth.go:71-100` |
| Underlying providers | Anthropic, OpenAI, Google, Fireworks | Bifrost gateway, per `ARCHITECTURE.md:16` |
| Streaming | SSE, `data: {...}\n\n` chunks (OpenAI shape) | `ai-portal/.../stream.go:336` |
| anuma-sdk language | TypeScript only, no Go client | `anuma-sdk/` package layout |
| Tool execution model | Loop runs client-side wherever SDK is imported; tools are JS functions or `onToolCall` callback | `anuma-sdk/.../toolLoop.ts` |

## Gap list

Sorted by impact on fit-cp specifically.

### G1 — Anthropic-compatible stream event types (`ai-portal`)

**Severity for fit-cp: Low.** Only matters if we'd written fit-cp against Anthropic's SDK first. With OpenAI Go SDK against Anuma, it's a non-issue.

Anthropic streams emit structured event types: `message_start`, `content_block_start`, `content_block_delta`, `content_block_stop`, `message_delta`, `message_stop`. Anuma streams OpenAI-style deltas. A client that parses Anthropic events would break.

Suggested PR title: *"Optional Anthropic-compatible stream mode on /chat/completions (Accept: application/vnd.anthropic+stream)"*

### G2 — Remote tool callback support (`anuma-sdk`)

**Severity for fit-cp: None right now.** fit-cp owns the loop; tools execute in-process. Only matters if we later want Anuma to *run* the loop and call back into fit-cp.

`runToolLoop` currently expects tools to be: (a) JS functions in the SDK process (`executor`), or (b) handled by the `onToolCall` callback synchronously. There's no "register a tool, Anuma POSTs to this URL with the call payload, awaits a JSON result" path.

Suggested PR title: *"Add webhook-style remote tool callback to runToolLoop"*

### G3 — Hosted agent endpoint (`anuma-sdk` + `ai-portal`)

**Severity for fit-cp: None right now.** Same reason as G2.

There's no `POST /agents/{name}/run` style endpoint where Anuma runs the loop server-side and returns the final answer (or streams turns). Caller has to drive `/chat/completions` in a loop.

PR #444's "server-owned tool loop" turned out to be a different thing — `runToolLoop` is client-side. My earlier mental model was wrong; updated.

Suggested PR title: *"Hosted agent runner endpoint (proposal)"*

### G4 — Surface Anthropic-specific features (`ai-portal`)

**Severity for fit-cp: Medium if we want extended thinking for programme reasoning. Otherwise none.**

Anuma routes to Anthropic but doesn't pass through: extended thinking blocks, vision (image inputs), batch API, PDF document upload, fine-grained logprobs, computer-use, parallel tool use. These have to be called direct against Anthropic.

Suggested PR title: *"Pass-through Anthropic thinking + vision through /chat/completions"*

### G5 — Go client / OpenAPI spec (`anuma-sdk`)

**Severity for fit-cp: None.** OpenAI Go SDK works as-is against Anuma's endpoint.

A Go client would be nice for first-class typing, but stock `openai-go` with a custom `WithBaseURL` is fine.

Suggested PR title: *"Publish OpenAPI spec for /api/v1/* so consumers can codegen any language"*

### G6 — Responses API support in `runToolLoop` (`anuma-sdk`)

**Severity for fit-cp: None.** Don't need it.

`runToolLoop` only supports the Chat Completions endpoint shape. Anthropic's newer Responses API and OpenAI's Responses API have different shapes. ai-portal has a `/api/v1/responses` endpoint but the SDK helper doesn't drive it.

Suggested PR title: *"runToolLoop variant for Responses API"*

## Open questions for Tanmay

1. **Bifrost provider routing** — when a request comes in with `model: "claude-sonnet-4-6"`, does Bifrost route to Anthropic? Is there a docs page or config file listing the model → provider map?
2. **Streaming compatibility tested?** — has anyone actually consumed `/api/v1/chat/completions` streaming from a Go HTTP client with tool calls in the loop? Or is fit-cp the first?
3. **Rate limits, quotas, observability** — what does an Anuma API key get you that direct provider keys don't? (Logging? Cost attribution? Rate limit aggregation across providers?)

## Recommendation

Ship fit-cp Phase 2 using **OpenAI Go SDK + configurable base URL**. Dev points at OpenAI direct; prod points at Anuma. The model field selects the underlying provider. None of the gaps above block this path.

Revisit if/when extended-thinking or hosted-agent capabilities become real requirements.
