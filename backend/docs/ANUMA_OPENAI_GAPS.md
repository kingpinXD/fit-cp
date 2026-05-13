# Anuma vs OpenAI gap analysis for fit-cp Phase 2 agent

Captured 2026-05-13 from a code investigation of `ai-portal` and `anuma-sdk`. Pair with [`ANUMA_GAPS.md`](./ANUMA_GAPS.md) — that one framed the comparison against Anthropic and concluded "Anuma is OpenAI-shaped, use OpenAI as the reference instead." This doc drills into that reference.

Investigation premise: *if fit-cp's Go agent uses the OpenAI Go SDK (`openai/openai-go`) pointed at `api.openai.com`, what specifically blocks swapping the base URL + API key to make it talk to Anuma?*

## TL;DR

~85% of the wire matches. **Three blockers stand between today and a one-line config swap**, plus a handful of advanced-feature gaps that fit-cp Phase 2 doesn't need. The blockers are small in scope but real — the stock OpenAI SDK will fail to authenticate, will send unrecognized model names, and will hit the wrong URL path.

The blockers can be fixed two ways: a small shim in fit-cp (~30 lines of Go transport middleware), or three focused PRs to `ai-portal`. The upstream PRs are the right long-term fix; the shim is the right short-term unblocker.

## Compatibility scorecard

| Aspect | OpenAI | Anuma | Drop-in? |
|---|---|---|---|
| **Auth header** | `Authorization: Bearer sk-…` | `X-API-Key` only (Bearer reserved for Privy JWT) | ❌ Blocker |
| **Chat endpoint path** | `/v1/chat/completions` | `/api/v1/chat/completions` | ❌ Blocker |
| **Model format** | bare (`gpt-4o`) | `provider/model` (`openai/gpt-4o`) | ❌ Blocker |
| Messages, text + image_url + file blocks | ✅ | ✅ (superset — also supports `input_file`) | ✅ |
| Tool definition shape | `{type:"function",function:{...}}` | same | ✅ |
| `tool_choice` (`auto`/`none`/`required`/named) | ✅ | ✅ | ✅ |
| Streaming SSE format | `data: <json>\n\n` + `[DONE]` | same | ✅ |
| Streaming deltas under `choices[0].delta` | ✅ | ✅ | ✅ |
| Response shape (`id`, `object`, `choices[]`, `usage`) | ✅ | ✅ (additive extras) | ✅ |
| `/models` listing | `/v1/models` | `/api/v1/models` | ✅ (path diff) |
| Embeddings | `/v1/embeddings` | `/api/v1/embeddings` | ✅ (path diff) |
| `response_format` (JSON mode / structured outputs) | ✅ | ❌ | ⚠️ Minor |
| `parallel_tool_calls` | ✅ | ❌ | ⚠️ Minor |
| `stream_options.include_usage` | ✅ | ❌ | ⚠️ Minor |
| `reasoning_effort` on Chat Completions | ✅ (o-series) | ⚠️ only on Responses API | ⚠️ Minor |
| `max_completion_tokens` | ✅ | ❌ (only `max_tokens`) | ⚠️ Minor |
| `seed` | ✅ | ❌ | ⚠️ Minor |
| `logprobs` / `top_logprobs` | ✅ | ❌ | ⚠️ Minor |
| `metadata` / `store` (request attribution) | ✅ | ❌ | ⚠️ Minor |
| Assistants API | `/v1/assistants` | ❌ | ⚠️ Anuma never had it |
| Responses API | `/v1/responses` | ✅ at `/api/v1/responses` (Anuma extra) | ✅ |

## Critical gaps (blockers for one-line swap)

### G1 — Auth header parity (`ai-portal`)
OpenAI SDK sets `Authorization: Bearer sk-…`. The portal's auth middleware (`internal/api/middlewares/auth.go:21-196`) accepts `X-API-Key` for API-key auth; `Authorization: Bearer` is reserved for Privy JWTs. An API key sent as Bearer will be misrouted into JWT validation and fail.

**Fix shape:** detect when the Bearer token has the API-key prefix (whatever Anuma uses — e.g. `anuma_…`) and route it through API-key validation instead of JWT. Keep `X-API-Key` working for back-compat.

**Suggested PR title:** *"Accept Bearer-shaped API keys as alias for X-API-Key (OpenAI SDK drop-in)"*

### G2 — Model name namespace (`ai-portal`)
OpenAI SDK sends `model: "gpt-4o"`. Anuma requires `model: "openai/gpt-4o"` (`pkg/llmapi/requests.go:18-23`). Bare names get rejected.

**Fix shape:** if the model name has no `/`, look it up in Bifrost's model registry and prepend the canonical provider. Falls back to current behaviour for fully-qualified names.

**Suggested PR title:** *"Resolve bare model names against Bifrost registry"*

### G3 — Chat completions URL path (`ai-portal`)
OpenAI SDK hits `/v1/chat/completions`. Anuma serves `/api/v1/chat/completions` (`internal/api/router.go:238`). The `/api` prefix breaks SDK defaults.

**Fix shape:** mount the same handlers under `/v1/*` as aliases. Two-line change in the router. Doesn't break existing consumers — both paths coexist.

**Suggested PR title:** *"Mount /v1/* aliases for OpenAI SDK path compatibility"*

## Minor gaps (won't block fit-cp Phase 2)

| # | Gap | When it matters |
|---|---|---|
| G4 | `response_format` (JSON mode / `json_schema`) | When you want guaranteed valid JSON without prompt-engineering it. fit-cp's programme generation could use this; not a blocker because we can validate post-hoc. |
| G5 | `parallel_tool_calls` flag | If we expect the model to call `search_exercises` for multiple muscle groups in one turn. Defaults are fine. |
| G6 | `stream_options.include_usage` | Per-request token attribution while streaming. Cost-tracking nice-to-have. |
| G7 | `reasoning_effort` on Chat Completions | Currently only on `/responses`. If we want o-series thinking on `/chat/completions`, this needs adding. |
| G8 | `max_completion_tokens` (o-series-only field name) | o3/o4 models reject `max_tokens`. Workaround: use Responses API. |
| G9 | `seed` | Reproducibility for evals. Phase 3 concern. |
| G10 | `logprobs` / `top_logprobs` | Debug / eval only. |

## What does swap cleanly today

If you write fit-cp's agent against the OpenAI Go SDK using these features only, the wire bytes that Anuma cares about are compatible:

- `messages[]` including multimodal blocks
- `tools[]` and `tool_choice`
- Streaming over SSE with deltas + `[DONE]`
- Standard response shape
- `/models` and `/embeddings`

The catch is auth + path + model namespace — the three blockers above.

## Two paths to actually deploying against Anuma

### Path A — fit-cp-side shim (no Anuma changes)

Wrap the OpenAI Go SDK's HTTP client with ~30 lines of transport middleware that, when `OPENAI_BASE_URL` points at Anuma:

1. Copies `Authorization: Bearer <key>` into `X-API-Key: <key>` (or strips Bearer entirely)
2. Rewrites request path: `/v1/...` → `/api/v1/...`
3. Rewrites the JSON body's `model` field: `"gpt-4o"` → `"openai/gpt-4o"` (with a small allowlist or convention)

Pros: zero coordination with Anuma team, ships in an afternoon. Cons: brittle if Anuma changes anything; locks fit-cp into knowing Anuma exists.

### Path B — three focused PRs to `ai-portal`

G1 + G2 + G3 above. Each is small (<100 lines), each is back-compat-safe. Once merged, fit-cp's config is literally `OPENAI_BASE_URL=https://ai-portal.anuma.ai`, no other changes.

Pros: any future client (not just fit-cp) gets the drop-in. Cleaner long-term. Cons: needs Anuma team buy-in and a release.

**Recommended:** start fit-cp Phase 2 against OpenAI direct with the OpenAI Go SDK; ship the agent. In parallel, raise G1–G3 with the Anuma team. When those land, swap the base URL and delete any fit-cp-side shim. Don't bother with Path A unless we hit a deadline that needs Anuma before the PRs ship.

## Open questions

1. **Bifrost model registry shape** — for G2, can the registry resolve `gpt-4o` → `openai/gpt-4o` directly? Or does Anuma intentionally keep prefixes mandatory for cost-attribution reasons?
2. **Privy JWT vs API-key Bearer collision** — for G1, what does an Anuma API key look like? If it has a distinctive prefix (e.g. `anuma_`), the auth middleware can disambiguate from Privy JWTs cheaply. If both look like opaque tokens, disambiguation is harder.
3. **`response_format` (G4) underlying support** — Bifrost routes to Anthropic/OpenAI/Gemini. All three support some form of structured output. Is the gap in the portal layer not exposing it, or in Bifrost not translating it across providers?

## Recommendation

Same as the Anthropic-comparison doc: scaffold fit-cp Phase 2 against the OpenAI Go SDK. Use OpenAI direct for development. The path to Anuma is three small PRs away. Don't build any shim until those PRs miss a deadline.
