package agent

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func newTestRegistry(handler ToolHandler) *Registry {
	r := &Registry{handlers: map[string]ToolHandler{}}
	r.register(ToolDef{
		Name:        "search_exercises",
		Description: "stub",
		Parameters:  map[string]any{"type": "object"},
	}, handler)
	return r
}

func TestRunReturnsTextOnFirstTurn(t *testing.T) {
	stub := &stubClient{queue: []ChatResponse{textReply("hi there")}}
	tools := newTestRegistry(func(context.Context, json.RawMessage) (string, error) {
		t.Fatalf("tool should not be called when model replies with text")
		return "", nil
	})

	resp, err := Run(context.Background(), stub, tools, Request{
		Model:    "gpt-4o-mini",
		Messages: []Message{{Role: RoleUser, Content: "hello"}},
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if resp.Reply != "hi there" {
		t.Errorf("reply: want %q, got %q", "hi there", resp.Reply)
	}
	if stub.calls != 1 {
		t.Errorf("calls: want 1, got %d", stub.calls)
	}
	wantRoles := []string{RoleSystem, RoleUser, RoleAssistant}
	gotRoles := roles(resp.Messages)
	if !equalSlices(gotRoles, wantRoles) {
		t.Errorf("roles: want %v, got %v", wantRoles, gotRoles)
	}
}

func TestRunExecutesToolThenReturnsText(t *testing.T) {
	stub := &stubClient{queue: []ChatResponse{
		toolCallReply("call_1", "search_exercises", `{"muscle":"biceps"}`),
		textReply("Try the Barbell Curl."),
	}}
	var gotArgs string
	tools := newTestRegistry(func(_ context.Context, raw json.RawMessage) (string, error) {
		gotArgs = string(raw)
		return `[{"id":"Barbell_Curl"}]`, nil
	})

	resp, err := Run(context.Background(), stub, tools, Request{
		Model:    "gpt-4o-mini",
		Messages: []Message{{Role: RoleUser, Content: "find a biceps exercise"}},
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if resp.Reply != "Try the Barbell Curl." {
		t.Errorf("reply: want %q, got %q", "Try the Barbell Curl.", resp.Reply)
	}
	if gotArgs != `{"muscle":"biceps"}` {
		t.Errorf("tool args: want %q, got %q", `{"muscle":"biceps"}`, gotArgs)
	}
	if stub.calls != 2 {
		t.Errorf("calls: want 2, got %d", stub.calls)
	}
	wantRoles := []string{RoleSystem, RoleUser, RoleAssistant, RoleTool, RoleAssistant}
	gotRoles := roles(resp.Messages)
	if !equalSlices(gotRoles, wantRoles) {
		t.Errorf("roles: want %v, got %v", wantRoles, gotRoles)
	}
	// The tool turn must carry the tool_call_id so OpenAI can match it back.
	if resp.Messages[3].ToolCallID != "call_1" {
		t.Errorf("tool_call_id: want call_1, got %q", resp.Messages[3].ToolCallID)
	}
}

func TestRunHitsMaxIterations(t *testing.T) {
	loopForever := toolCallReply("call_x", "search_exercises", `{}`)
	stub := &stubClient{trailing: &loopForever}
	tools := newTestRegistry(func(context.Context, json.RawMessage) (string, error) {
		return `[]`, nil
	})

	_, err := Run(context.Background(), stub, tools, Request{
		Model:    "gpt-4o-mini",
		Messages: []Message{{Role: RoleUser, Content: "loop"}},
	})
	if !errors.Is(err, ErrMaxIterations) {
		t.Fatalf("want ErrMaxIterations, got %v", err)
	}
	if stub.calls != maxIterations {
		t.Errorf("calls: want %d, got %d", maxIterations, stub.calls)
	}
}

func TestRunSurfacesToolErrorToModel(t *testing.T) {
	stub := &stubClient{queue: []ChatResponse{
		toolCallReply("call_1", "search_exercises", `{}`),
		textReply("Sorry, something went wrong."),
	}}
	tools := newTestRegistry(func(context.Context, json.RawMessage) (string, error) {
		return "", errors.New("boom")
	})

	resp, err := Run(context.Background(), stub, tools, Request{
		Model:    "gpt-4o-mini",
		Messages: []Message{{Role: RoleUser, Content: "find exercises"}},
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}
	if resp.Reply != "Sorry, something went wrong." {
		t.Errorf("reply: %q", resp.Reply)
	}
	toolMsg := resp.Messages[3]
	if toolMsg.Role != RoleTool {
		t.Fatalf("msg[3].role: want tool, got %q", toolMsg.Role)
	}
	if !strings.Contains(toolMsg.Content, "boom") {
		t.Errorf("tool message should surface the error: %q", toolMsg.Content)
	}
	// Must be valid JSON so the model can parse it.
	var parsed map[string]string
	if err := json.Unmarshal([]byte(toolMsg.Content), &parsed); err != nil {
		t.Errorf("tool message not valid JSON: %v: %s", err, toolMsg.Content)
	}
	if parsed["error"] != "boom" {
		t.Errorf("parsed error: %q", parsed["error"])
	}
}

func TestHandlerRejectsEmptyMessages(t *testing.T) {
	api := NewAPI(&stubClient{}, newTestRegistry(func(context.Context, json.RawMessage) (string, error) { return "", nil }), "gpt-4o-mini")
	rec := postJSON(api.Chat, `{"messages":[]}`)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status: want 400, got %d", rec.Code)
	}
}

func TestHandlerRejectsSystemMessage(t *testing.T) {
	api := NewAPI(&stubClient{}, newTestRegistry(func(context.Context, json.RawMessage) (string, error) { return "", nil }), "gpt-4o-mini")
	rec := postJSON(api.Chat, `{"messages":[{"role":"system","content":"hi"}]}`)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status: want 400, got %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestHandlerReturnsReplyAndTrail(t *testing.T) {
	stub := &stubClient{queue: []ChatResponse{textReply("here you go")}}
	api := NewAPI(stub, newTestRegistry(func(context.Context, json.RawMessage) (string, error) { return "", nil }), "gpt-4o-mini")
	rec := postJSON(api.Chat, `{"messages":[{"role":"user","content":"hi"}]}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("status: want 200, got %d body=%s", rec.Code, rec.Body.String())
	}
	var got struct {
		Messages []Message `json:"messages"`
		Reply    string    `json:"reply"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &got); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got.Reply != "here you go" {
		t.Errorf("reply: want %q, got %q", "here you go", got.Reply)
	}
	if stub.lastRequest.Model != "gpt-4o-mini" {
		t.Errorf("model: want gpt-4o-mini, got %q", stub.lastRequest.Model)
	}
	wantRoles := []string{RoleSystem, RoleUser, RoleAssistant}
	if !equalSlices(roles(got.Messages), wantRoles) {
		t.Errorf("roles: want %v, got %v", wantRoles, roles(got.Messages))
	}
}

func TestHandlerHonorsRequestModel(t *testing.T) {
	stub := &stubClient{queue: []ChatResponse{textReply("ok")}}
	api := NewAPI(stub, newTestRegistry(func(context.Context, json.RawMessage) (string, error) { return "", nil }), "gpt-4o-mini")
	rec := postJSON(api.Chat, `{"messages":[{"role":"user","content":"hi"}],"model":"gpt-4o"}`)
	if rec.Code != http.StatusOK {
		t.Fatalf("status: want 200, got %d", rec.Code)
	}
	if stub.lastRequest.Model != "gpt-4o" {
		t.Errorf("model: want gpt-4o, got %q", stub.lastRequest.Model)
	}
}

func postJSON(handler http.HandlerFunc, body string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/v1/agent/chat", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	handler.ServeHTTP(rec, req)
	return rec
}

func roles(msgs []Message) []string {
	out := make([]string, 0, len(msgs))
	for _, m := range msgs {
		out = append(out, m.Role)
	}
	return out
}

func equalSlices(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
