// Package agent implements a stateless LLM tool-use loop. The HTTP handler
// receives a conversation, the loop drives the OpenAI Chat Completions API,
// dispatches tool calls back into Go, and returns the final assistant reply
// along with the full message trail so the client can resend it next turn.
package agent

import (
	"context"
	"errors"
	"fmt"

	"github.com/openai/openai-go"
	"github.com/openai/openai-go/option"
	"github.com/openai/openai-go/shared"
)

// systemPrompt is hardcoded so OpenAI's prompt cache can hit on the prefix
// across requests. Do not templatize per-request — every per-user variation
// torches cache reuse.
const systemPrompt = `You are a fitness assistant inside the fit-cp app. You help users find exercises and plan workouts.

Use the search_exercises tool whenever the user asks about specific exercises. Never invent exercises that don't exist in the catalog.

Reply concisely. When listing exercises, include the name and primary muscle.`

// Message is the agent package's own wire shape. We translate to/from the
// OpenAI SDK types inside openaiClient.Chat so the rest of the package never
// touches SDK types.
type Message struct {
	Role       string     `json:"role"`
	Content    string     `json:"content,omitempty"`
	ToolCalls  []ToolCall `json:"tool_calls,omitempty"`
	ToolCallID string     `json:"tool_call_id,omitempty"`
}

// ToolCall mirrors OpenAI's tool_calls entries.
type ToolCall struct {
	ID       string       `json:"id"`
	Function FunctionCall `json:"function"`
}

// FunctionCall carries the model's intended tool invocation. Arguments is raw
// JSON exactly as the model emitted it — the tool registry parses it.
type FunctionCall struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"`
}

// ToolDef describes one tool. Parameters is a JSON Schema object.
type ToolDef struct {
	Name        string
	Description string
	Parameters  map[string]any
}

// ChatRequest is what the loop hands to an LLMClient on each turn.
type ChatRequest struct {
	Model    string
	Messages []Message
	Tools    []ToolDef
}

// ChatResponse is one assistant turn plus the model's reported finish reason.
type ChatResponse struct {
	Message      Message
	FinishReason string
}

// LLMClient is the minimal surface the loop needs. We keep it tiny so tests
// can fake it without dragging in the OpenAI SDK, and so swapping in
// Anthropic/Anuma later is a single new impl.
type LLMClient interface {
	Chat(ctx context.Context, req ChatRequest) (ChatResponse, error)
}

// openaiClient adapts the OpenAI Go SDK to LLMClient.
type openaiClient struct {
	client openai.Client
}

// NewOpenAIClient constructs an OpenAI-backed LLMClient. apiKey is required;
// baseURL is optional (empty falls through to the SDK default), used for the
// Anuma-compatible swap later.
func NewOpenAIClient(apiKey, baseURL string) (LLMClient, error) {
	if apiKey == "" {
		return nil, errors.New("openai api key is required")
	}
	opts := []option.RequestOption{option.WithAPIKey(apiKey)}
	if baseURL != "" {
		opts = append(opts, option.WithBaseURL(baseURL))
	}
	return &openaiClient{client: openai.NewClient(opts...)}, nil
}

func (c *openaiClient) Chat(ctx context.Context, req ChatRequest) (ChatResponse, error) {
	params := openai.ChatCompletionNewParams{
		Model:    shared.ChatModel(req.Model),
		Messages: toOpenAIMessages(req.Messages),
		Tools:    toOpenAITools(req.Tools),
	}
	resp, err := c.client.Chat.Completions.New(ctx, params)
	if err != nil {
		return ChatResponse{}, fmt.Errorf("openai chat: %w", err)
	}
	if len(resp.Choices) == 0 {
		return ChatResponse{}, errors.New("openai returned no choices")
	}
	choice := resp.Choices[0]
	return ChatResponse{
		Message:      fromOpenAIMessage(choice.Message),
		FinishReason: choice.FinishReason,
	}, nil
}

func toOpenAIMessages(msgs []Message) []openai.ChatCompletionMessageParamUnion {
	out := make([]openai.ChatCompletionMessageParamUnion, 0, len(msgs))
	for _, m := range msgs {
		out = append(out, toOpenAIMessage(m))
	}
	return out
}

func toOpenAIMessage(m Message) openai.ChatCompletionMessageParamUnion {
	switch m.Role {
	case "system":
		return openai.SystemMessage(m.Content)
	case "user":
		return openai.UserMessage(m.Content)
	case "tool":
		return openai.ToolMessage(m.Content, m.ToolCallID)
	case "assistant":
		assistant := openai.ChatCompletionAssistantMessageParam{}
		if m.Content != "" {
			assistant.Content.OfString = openai.String(m.Content)
		}
		if len(m.ToolCalls) > 0 {
			assistant.ToolCalls = toOpenAIToolCalls(m.ToolCalls)
		}
		return openai.ChatCompletionMessageParamUnion{OfAssistant: &assistant}
	}
	// Unknown roles get sent as user — safest fallback; the model will ignore
	// what it doesn't understand rather than the SDK panicking on a zero union.
	return openai.UserMessage(m.Content)
}

func toOpenAIToolCalls(calls []ToolCall) []openai.ChatCompletionMessageToolCallParam {
	out := make([]openai.ChatCompletionMessageToolCallParam, 0, len(calls))
	for _, c := range calls {
		out = append(out, openai.ChatCompletionMessageToolCallParam{
			ID: c.ID,
			Function: openai.ChatCompletionMessageToolCallFunctionParam{
				Name:      c.Function.Name,
				Arguments: c.Function.Arguments,
			},
		})
	}
	return out
}

func toOpenAITools(defs []ToolDef) []openai.ChatCompletionToolParam {
	out := make([]openai.ChatCompletionToolParam, 0, len(defs))
	for _, d := range defs {
		out = append(out, openai.ChatCompletionToolParam{
			Function: shared.FunctionDefinitionParam{
				Name:        d.Name,
				Description: openai.String(d.Description),
				Parameters:  shared.FunctionParameters(d.Parameters),
			},
		})
	}
	return out
}

func fromOpenAIMessage(m openai.ChatCompletionMessage) Message {
	out := Message{Role: "assistant", Content: m.Content}
	if len(m.ToolCalls) == 0 {
		return out
	}
	out.ToolCalls = make([]ToolCall, 0, len(m.ToolCalls))
	for _, tc := range m.ToolCalls {
		out.ToolCalls = append(out.ToolCalls, ToolCall{
			ID: tc.ID,
			Function: FunctionCall{
				Name:      tc.Function.Name,
				Arguments: tc.Function.Arguments,
			},
		})
	}
	return out
}
