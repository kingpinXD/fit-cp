package agent

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"github.com/kingpinXD/fit-cp/backend/internal/httpio"
)

// API holds the dependencies the agent HTTP handler needs. Constructed once
// at startup in main.go and passed into the router.
type API struct {
	Client       LLMClient
	Tools        *Registry
	DefaultModel string
}

// NewAPI wires up an agent handler against a constructed LLM client and tool
// registry. DefaultModel is used when the request body omits "model".
func NewAPI(client LLMClient, tools *Registry, defaultModel string) *API {
	return &API{Client: client, Tools: tools, DefaultModel: defaultModel}
}

type chatRequestBody struct {
	Messages []Message `json:"messages"`
	Model    string    `json:"model"`
}

type chatResponseBody struct {
	Messages []Message `json:"messages"`
	Reply    string    `json:"reply"`
}

// Chat handles POST /v1/agent/chat. The system prompt is added internally so
// callers never include it; including one in the request is rejected.
func (a *API) Chat(w http.ResponseWriter, r *http.Request) {
	if a == nil || a.Client == nil {
		httpio.WriteError(w, "agent_unavailable", http.StatusServiceUnavailable, "agent endpoint is not configured")
		return
	}

	var body chatRequestBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httpio.WriteError(w, "invalid_request", http.StatusBadRequest, "request body must be valid JSON")
		return
	}
	if len(body.Messages) == 0 {
		httpio.WriteError(w, "invalid_request", http.StatusBadRequest, "messages must not be empty")
		return
	}
	for _, m := range body.Messages {
		if m.Role == "system" {
			httpio.WriteError(w, "invalid_request", http.StatusBadRequest, "system messages are added internally; do not include them")
			return
		}
	}

	model := body.Model
	if model == "" {
		model = a.DefaultModel
	}

	resp, err := Run(r.Context(), a.Client, a.Tools, Request{Model: model, Messages: body.Messages})
	if err != nil {
		if errors.Is(err, ErrMaxIterations) {
			slog.Warn("agent hit max iterations", "model", model)
			httpio.WriteError(w, "agent_max_iterations", http.StatusInternalServerError, "agent exceeded maximum iterations")
			return
		}
		slog.Error("agent run", "err", err)
		httpio.WriteError(w, "agent_error", http.StatusInternalServerError, "agent failed to produce a reply")
		return
	}

	httpio.WriteJSON(w, http.StatusOK, chatResponseBody{Messages: resp.Messages, Reply: resp.Reply})
}
