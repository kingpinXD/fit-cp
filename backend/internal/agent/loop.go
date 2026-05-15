package agent

import (
	"context"
	"errors"
	"log/slog"

	"golang.org/x/sync/errgroup"

	"github.com/kingpinXD/fit-cp/backend/internal/httpio"
)

// maxIterations is a hard safety cap on the tool-use loop. Real flows finish
// in 1-3 turns; ten is generous and ensures a runaway model can't bill us into
// next week.
const maxIterations = 10

// genericToolErrorJSON is what we hand back to the model when a tool blows up.
// Keeping it generic (a) avoids leaking pgx errors and (b) gives the model a
// stable shape it can branch on instead of parsing arbitrary error strings.
const genericToolErrorJSON = `{"error":"tool execution failed; try different arguments"}`

// ErrMaxIterations is returned when the agent loop exceeds maxIterations
// without the model emitting a final answer. The handler maps it to a 500
// with code "agent_max_iterations".
var ErrMaxIterations = errors.New("agent exceeded max iterations")

// Request is what the handler hands to Run. Messages must be non-empty and
// must not include a system message — Run prepends one internally.
type Request struct {
	Model    string
	Messages []Message
}

// Response is the full message trail plus the final assistant reply for
// convenience. Returning the trail lets a stateless client resend it next
// turn.
type Response struct {
	Messages []Message
	Reply    string
}

// Run drives the tool-use loop: call the model, if it asked for tools execute
// them and append the results, otherwise return the assistant text.
func Run(ctx context.Context, client LLMClient, tools *Registry, req Request) (Response, error) {
	messages := prependSystemPrompt(req.Messages)
	defs := tools.Definitions()

	for i := 0; i < maxIterations; i++ {
		resp, err := client.Chat(ctx, ChatRequest{
			Model:    req.Model,
			Messages: messages,
			Tools:    defs,
		})
		if err != nil {
			return Response{}, err
		}
		messages = append(messages, resp.Message)

		if len(resp.Message.ToolCalls) == 0 {
			return Response{Messages: messages, Reply: resp.Message.Content}, nil
		}

		toolMessages := executeToolCalls(ctx, tools, resp.Message.ToolCalls)
		messages = append(messages, toolMessages...)
	}
	return Response{}, ErrMaxIterations
}

// executeToolCalls dispatches every tool_call in a single assistant turn in
// parallel. Order is preserved in the returned slice so the model's
// position-based references stay valid. Per-call errors are captured into the
// tool message rather than failing the whole turn — one bad search should not
// torch the others.
func executeToolCalls(ctx context.Context, tools *Registry, calls []ToolCall) []Message {
	results := make([]Message, len(calls))
	g, gctx := errgroup.WithContext(ctx)
	for i, tc := range calls {
		i, tc := i, tc
		g.Go(func() error {
			out, err := tools.Execute(gctx, tc.Function.Name, tc.Function.Arguments)
			if err != nil {
				slog.Error("tool execution failed",
					"tool", tc.Function.Name,
					"err", err,
					"request_id", httpio.RequestIDFromContext(gctx))
				out = genericToolErrorJSON
			}
			results[i] = Message{
				Role:       RoleTool,
				ToolCallID: tc.ID,
				Content:    out,
			}
			// Never return the error — we want every sibling to finish so the
			// model sees the full set of results, not whichever raced first.
			return nil
		})
	}
	_ = g.Wait()
	return results
}

func prependSystemPrompt(msgs []Message) []Message {
	out := make([]Message, 0, len(msgs)+1)
	out = append(out, Message{Role: RoleSystem, Content: systemPrompt})
	out = append(out, msgs...)
	return out
}
