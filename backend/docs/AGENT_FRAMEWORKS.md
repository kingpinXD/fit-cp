# Agent frameworks + routing landscape

Captured 2026-05-13. Snapshot of what's out there for building LLM agents that call tools, with an eye on what fit-cp Phase 2 should pick. Not a recommendation — a map. Pair with [`ANUMA_GAPS.md`](./ANUMA_GAPS.md).

## The layers

When you build an agent, four distinct layers stack up. Most confusion in this market comes from conflating them.

```
┌───────────────────────────────────────────────────────────────┐
│  Layer 4 — Agent platforms                                    │
│  Managed loop, persistent state, opinionated UX               │
│  (OpenAI Assistants, Bedrock Agents, Vertex Agent Builder)    │
├───────────────────────────────────────────────────────────────┤
│  Layer 3 — Agent frameworks                                   │
│  Code that runs in your process, glues prompts + tools + loop │
│  (LangChain, LlamaIndex, CrewAI, Vercel AI SDK, Eino, …)      │
├───────────────────────────────────────────────────────────────┤
│  Layer 2 — Gateway / router                                   │
│  Unified API across providers, observability, rate limits     │
│  (Bifrost, LiteLLM, OpenRouter, Portkey, Helicone)            │
├───────────────────────────────────────────────────────────────┤
│  Layer 1 — Provider SDKs                                      │
│  Native wire format per vendor                                │
│  (anthropic-sdk-*, openai-*, vertex-ai, bedrock)              │
└───────────────────────────────────────────────────────────────┘
```

fit-cp Phase 2 has to pick at L1 and L2. L3 is optional (write the loop yourself = ~50 lines). L4 is overkill for one agent.

---

## Layer 1 — How you actually build an agent loop, per vendor

### Anthropic Messages API

Concrete flow:

1. Define each tool as JSON Schema: `{name, description, input_schema}`
2. `POST /v1/messages` with `messages[]`, `tools[]`, optional `tool_choice` (`auto`/`any`/`{type:"tool",name:"X"}`/`none`)
3. Response has `content[]` blocks, each typed `text` or `tool_use` (with `id`, `name`, `input`)
4. If `stop_reason == "tool_use"`:
   - Execute the tool yourself
   - Build the next request: same `messages` + the assistant turn + a new user turn containing a `tool_result` content block (`tool_use_id` + `content`)
5. Loop until `stop_reason == "end_turn"`
6. Streaming: SSE with typed events (`message_start`, `content_block_start`, `content_block_delta`, `message_delta`, `message_stop`)

Extras Anthropic does that nobody else does as cleanly:
- **Extended thinking** — `thinking` content blocks let the model reason before answering, you can budget tokens for it
- **Parallel tool use** — multiple `tool_use` blocks in one assistant turn
- **Computer use** — first-class screen + keyboard tools
- **MCP-native** — Anthropic created the Model Context Protocol; the API has native MCP server support

SDKs: `anthropic-sdk-python`, `anthropic-sdk-typescript`, `anthropic-sdk-go`, `anthropic-sdk-java`.

**Claude Agent SDK** (Python/TS) is Anthropic's higher-level wrapper — built-in compaction, memory layers, subagent orchestration, MCP integration. Heavy and opinionated; fine if you want a managed-feeling experience without going full L4.

### OpenAI Chat Completions

Concrete flow:

1. Define each tool as `{type: "function", function: {name, description, parameters: <JSONSchema>}}`
2. `POST /v1/chat/completions` with `messages[]`, `tools[]`, optional `tool_choice` (`auto`/`none`/`required`/`{type:"function",function:{name}}`)
3. Response: `choices[0].message` has either `content` (text) or `tool_calls[]` (each with `id`, `type:"function"`, `function: {name, arguments}` — **arguments is a JSON string, not an object**, a known footgun)
4. If `finish_reason == "tool_calls"`:
   - Execute each call
   - Next request: same `messages` + assistant message + one `role:"tool"` message per call (with `tool_call_id` + stringified `content`)
5. Loop until `finish_reason == "stop"`
6. Streaming: SSE with deltas inline in `choices[0].delta`, including `tool_calls` deltas

Newer OpenAI surfaces:
- **Responses API** (`/v1/responses`) — different shape, simpler, designed for agent-style stateful interactions; mostly replaces the older Assistants API for new builds
- **Assistants API** (`/v1/assistants` + threads) — server-managed agent state, file search, code interpreter, function calling. Layer 4 territory.
- **OpenAI Agents SDK** (Python/TS) — official multi-agent framework descended from the experimental Swarm
- **Function calling is L1, not a separate API** — built into Chat Completions

SDKs: `openai-python`, `openai-node`, `openai-go`, `openai-java`. Mature, consistent across languages.

### Google Gemini (Vertex AI + AI Studio)

Concrete flow looks similar to OpenAI's — tools are JSON Schema, model returns `functionCall` blocks, you respond with `functionResponse`. Two access modes: AI Studio (consumer API, just an API key) and Vertex AI (GCP project, IAM auth, billing per project). Gemini 2.5 Pro / Flash are the workhorses, Flash is the cheapest of the big three.

SDKs: `google-genai` (Python/JS), `vertexai` (Python/JS/Go). The Go SDK is decent.

### Amazon Bedrock

Bedrock hosts Anthropic, Meta, Mistral, Cohere, Amazon-trained models. Tool use API differs per model family, which is the worst of all worlds — abstracts pricing/region but not the wire format. AWS-shop only.

### Comparison cheatsheet

| | Tool schema | Tool call shape | Tool result shape | Streaming events |
|---|---|---|---|---|
| **Anthropic** | `{name, description, input_schema}` | `content[].type == "tool_use"` (with `input` as JSON object) | `tool_result` content block with `tool_use_id` | Typed events (start/delta/stop per block) |
| **OpenAI** | `{type:"function", function:{name, description, parameters}}` | `message.tool_calls[]` (arguments as **JSON string**) | `role:"tool"` message with `tool_call_id` | Untyped deltas inside `choices[0].delta` |
| **Google** | `{name, description, parameters}` | `functionCall: {name, args}` | `functionResponse: {name, response}` | Server-sent chunks |

OpenAI's wire is the most copied — Anuma uses it, Mistral uses it, most local-model servers (Ollama, vLLM) expose an OpenAI-compatible endpoint. **If you write to OpenAI's shape you can hit ~85% of the market without changing client code.**

---

## Layer 3 — Agent frameworks (compete with each other AND with "just write the loop")

### The big ones

| Framework | Language | What it is | Worth it for fit-cp? |
|---|---|---|---|
| **LangChain / LangGraph** | Python (+ JS) | Toolkits + graph-based agent runtime. LangChain is the broad library, LangGraph is the newer agent state machine. | Probably overkill for one agent. Heavyweight, lots of magic. |
| **LlamaIndex** | Python (+ TS) | RAG-first, agents as a secondary surface. Strong if your data is the centerpiece. | Not a fit — you have one tool, not a knowledge base. |
| **CrewAI** | Python | Multi-agent with roles ("researcher", "writer"). Opinionated. | Not a fit — one agent. |
| **AutoGen** | Python (Microsoft) | Multi-agent, debate-style conversations between agents. | Not a fit. |
| **Vercel AI SDK** | TS/JS | Frontend-friendly streaming + tool calls + UI helpers. Very popular. | Not in Go, not a fit here. |
| **PydanticAI** | Python | Type-safe agents with structured output via Pydantic. Excellent DX if you're Python. | Not in Go. |
| **DSPy** | Python (Stanford) | Compiles prompts via metric-driven optimization. Niche but powerful. | Research tool, not a fit. |
| **Letta** (was MemGPT) | Python | Agents with persistent long-term memory. | Not yet relevant. |

### Go-native options (relevant for fit-cp)

- **`langchaingo`** — Community port of LangChain. Adapters exist but quality is uneven; some are stubs. Popular by default.
- **Eino** — ByteDance's Go-native agent framework. Well-designed, modern, gaining traction. Worth a real look.
- **`swarmgo`** — Port of OpenAI's experimental Swarm. Lightweight, simple multi-agent. Niche.
- **Just write the loop** — provider SDK + ~50 lines of Go is the most boring and reliable path for one agent.

### Is LangChain a competitor?

To **Anuma SDK** — partially. They overlap in "build an agent that uses tools". Differences:

| | Anuma SDK | LangChain |
|---|---|---|
| Hosts the LLM? | Yes (gateway + billing + observability) | No, you bring keys |
| Provides agent loop helpers? | Yes (`runToolLoop`) | Yes (`AgentExecutor`, LangGraph) |
| Personas + prompt management? | Yes | No (separate add-ons like LangSmith Hub) |
| Multi-provider routing? | Yes (via Bifrost) | Yes (via `init_chat_model` indirection) |
| Language coverage | TypeScript only | Python primary, TS secondary |

Anuma is "managed LLM platform with an SDK on top". LangChain is "agent framework, bring your own keys". They compete at Layer 3 but Anuma owns Layer 2 + parts of Layer 4 that LangChain doesn't.

To **fit-cp's agent loop** — no, neither would be in the way. Pick one or write your own.

---

## Layer 2 — Gateways and routers (the Bifrost equivalents)

This is the layer the user asked about most directly. Bifrost is the gateway Anuma uses internally. The broader market:

| Gateway | What it is | Vibe |
|---|---|---|
| **LiteLLM** | Python proxy + library, unified `completion()` across 100+ models. THE most popular open-source LLM router. Translates any input format to provider's native API. | The duct-tape default. Run as a sidecar or import as a library. |
| **OpenRouter** | Hosted gateway, one API for all models, pay-per-token via OpenRouter (which marks up). Great for trying many models without signing up everywhere. | Hosted convenience, mild markup. |
| **Portkey** | Hosted gateway + observability + caching + guardrails. Commercial, with free tier. | Production-grade, more opinionated. |
| **Helicone** | Hosted observability layer (mainly), some gateway features. Open-source server option. | Logging-first. |
| **Bifrost** | Go-native gateway. Anuma uses it. Open-source. | Less famous, similar shape to LiteLLM. |
| **Vercel AI Gateway** | Vercel's offering, lives in their AI SDK ecosystem. | TS-leaning, popular with Next.js shops. |
| **Langfuse Gateway** | Observability + tracing + gateway. | Open-source, growing. |
| **Cloudflare AI Gateway** | Free CDN-edge gateway with logging + caching. | Cheap, opinionated about CF infrastructure. |

For fit-cp:
- Direct to provider in dev, Anuma in prod — that **is** routing through a gateway (Bifrost behind Anuma). You don't need a separate router.
- If you ever want one-shot model comparison ("does Claude or GPT-4o write better workouts?"), LiteLLM is the easiest local proxy.

### Is there a "Bifrost for agent tool loops"?

Short answer: **no, not really**, and that's interesting.

Why not:
- Tool loops are *stateful* — you have conversation history, tool execution happens in *your* process, you decide when to stop. Gateways are stateless request/response.
- The "loop" is really application code, not a wire protocol. Hard to standardize behind one API.

The closest things that exist:

| Thing | What it does | Is it really a "tool-loop gateway"? |
|---|---|---|
| **LiteLLM** | Translates tool definitions between provider shapes (OpenAI ↔ Anthropic ↔ Gemini). Your loop is portable across providers without code changes. | Halfway. It unifies L1; you still own the loop. |
| **MCP (Model Context Protocol)** | Anthropic's open spec for tool *servers*. A tool server speaks MCP; a tool *client* (any LLM client with MCP support) discovers + invokes tools over a standard protocol. | More like "USB for tools" than a gateway. Decouples tool authoring from agent runtime. |
| **OpenAI Assistants threads** | Server hosts conversation + tool loop. You POST a message, it runs the loop, you stream the result. | Yes, but vertically integrated (OpenAI-only). |
| **Anthropic Claude Agent SDK** | Same idea but agent loop runs in your process with built-ins for compaction, memory, MCP. | Halfway managed. |
| **Portkey Agent Observability** | Tracing/observability across agent runs from many SDKs. | Observability layer, not a gateway. |
| **LangSmith / Langfuse** | Trace + replay agent runs, evaluate prompts. | Same — observability, not routing. |

If you squint, **LiteLLM + MCP** is the closest the open ecosystem gets to "Bifrost for agents":
- LiteLLM normalizes the L1 wire across providers
- MCP normalizes how tools are authored and discovered
- Your loop code stays L1-agnostic and tool-source-agnostic

That said, none of this is mature enough to bet on for fit-cp's first agent. Write the loop in Go, ship it, revisit when there are 3+ agents.

---

## Where this lands for fit-cp

- **L1 pick** — OpenAI Go SDK (configurable base URL). Future provider swap = base URL + key.
- **L2** — Anuma's Bifrost (in prod) or direct provider (in dev). Same SDK either way.
- **L3** — write the loop. ~50 lines of Go. No framework dependency.
- **L4** — skip until there are multiple agents / hosted state / persistent memory needs.
- **MCP** — interesting for the longer arc. If fit-cp ever serves agents OTHER than its own, exposing the exercise catalog as an MCP server lets any MCP client (Claude desktop, Cursor, custom agents) plug in. Worth bookmarking, not building yet.

## Sources of further reading

- [Anthropic tool use docs](https://docs.anthropic.com/en/docs/build-with-claude/tool-use)
- [OpenAI function calling docs](https://platform.openai.com/docs/guides/function-calling)
- [MCP specification](https://modelcontextprotocol.io)
- [LiteLLM docs](https://docs.litellm.ai)
- [LangGraph concepts](https://langchain-ai.github.io/langgraph/concepts/)
- [Anuma SDK tool loop](https://github.com/anuma-ai/sdk) (internal)

## Caveat on freshness

This doc is dated 2026-05-13. The agent-framework market is moving fast — new entrants every few months, existing ones pivot their abstractions. If you read this 6+ months from now, re-verify before quoting any framework's current shape.
