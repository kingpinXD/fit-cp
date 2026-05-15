package agent

import (
	"context"
	"errors"
)

// stubClient is an in-package fake LLMClient. Tests load a queue of canned
// ChatResponses; each call to Chat pops the next one. When the queue is empty
// it returns the configured trailing response on repeat — handy for the
// "loops forever" case in loop_test.go.
type stubClient struct {
	queue       []ChatResponse
	trailing    *ChatResponse
	calls       int
	lastRequest ChatRequest
	err         error
}

func (s *stubClient) Chat(_ context.Context, req ChatRequest) (ChatResponse, error) {
	s.calls++
	s.lastRequest = req
	if s.err != nil {
		return ChatResponse{}, s.err
	}
	if len(s.queue) > 0 {
		resp := s.queue[0]
		s.queue = s.queue[1:]
		return resp, nil
	}
	if s.trailing != nil {
		return *s.trailing, nil
	}
	return ChatResponse{}, errors.New("stubClient: no canned response and no trailing default")
}

func textReply(content string) ChatResponse {
	return ChatResponse{
		Message:      Message{Role: RoleAssistant, Content: content},
		FinishReason: FinishReasonStop,
	}
}

func toolCallReply(id, name, args string) ChatResponse {
	return multiToolCallReply(ToolCall{ID: id, Function: FunctionCall{Name: name, Arguments: args}})
}

// multiToolCallReply packages N tool_calls into a single assistant turn, the
// way OpenAI's parallel-tool-calling mode emits them.
func multiToolCallReply(calls ...ToolCall) ChatResponse {
	return ChatResponse{
		Message: Message{
			Role:      RoleAssistant,
			ToolCalls: calls,
		},
		FinishReason: FinishReasonToolCalls,
	}
}
