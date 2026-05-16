package agent

// Role / finish-reason constants mirror the OpenAI Chat Completions vocabulary
// the rest of this package speaks to. Centralized so we don't get drift between
// loop, handler, and tests.
const (
	RoleSystem    = "system"
	RoleUser      = "user"
	RoleAssistant = "assistant"
	RoleTool      = "tool"

	FinishReasonStop      = "stop"
	FinishReasonToolCalls = "tool_calls"

	// MaxIterations is a hard safety cap on the tool-use loop. Real flows
	// finish in 1-3 turns; ten is generous and ensures a runaway model can't
	// bill us into next week.
	MaxIterations = 10

	// DefaultModel is the fallback Chat Completions model when callers don't
	// specify one.
	DefaultModel = "gpt-4o-mini"
)

// Mode selects which system prompt + tool subset the agent runs with.
type Mode string

const (
	ModeChat  Mode = "chat"
	ModeCoach Mode = "coach"
)
