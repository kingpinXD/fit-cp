package agent

import (
	"context"
	"errors"
	"fmt"
)

// maxIterations is a hard safety cap on the tool-use loop. Real flows finish
// in 1-3 turns; ten is generous and ensures a runaway model can't bill us into
// next week.
const maxIterations = 10

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

		for _, tc := range resp.Message.ToolCalls {
			result, err := tools.Execute(ctx, tc.Function.Name, tc.Function.Arguments)
			if err != nil {
				// Surface tool failures back to the model rather than aborting the
				// loop. The model can recover (apologize, ask for a different
				// search) instead of the user seeing a 500.
				result = fmt.Sprintf(`{"error":%q}`, err.Error())
			}
			messages = append(messages, Message{
				Role:       RoleTool,
				ToolCallID: tc.ID,
				Content:    result,
			})
		}
	}
	return Response{}, ErrMaxIterations
}

func prependSystemPrompt(msgs []Message) []Message {
	out := make([]Message, 0, len(msgs)+1)
	out = append(out, Message{Role: RoleSystem, Content: systemPrompt})
	out = append(out, msgs...)
	return out
}
