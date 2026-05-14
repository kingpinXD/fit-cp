package agent

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
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
		writeError(w, "agent_unavailable", http.StatusServiceUnavailable, "agent endpoint is not configured")
		return
	}

	var body chatRequestBody
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, "invalid_request", http.StatusBadRequest, "request body must be valid JSON")
		return
	}
	if len(body.Messages) == 0 {
		writeError(w, "invalid_request", http.StatusBadRequest, "messages must not be empty")
		return
	}
	for _, m := range body.Messages {
		if m.Role == "system" {
			writeError(w, "invalid_request", http.StatusBadRequest, "system messages are added internally; do not include them")
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
			writeError(w, "agent_max_iterations", http.StatusInternalServerError, "agent exceeded maximum iterations")
			return
		}
		slog.Error("agent run", "err", err)
		writeError(w, "agent_error", http.StatusInternalServerError, "agent failed to produce a reply")
		return
	}

	writeJSON(w, http.StatusOK, chatResponseBody{Messages: resp.Messages, Reply: resp.Reply})
}

// writeJSON and writeError duplicate the small helpers in httpx. Inlining them
// avoids an import cycle (agent ↔ httpx) without dragging in a shared package
// for two functions.
func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		slog.Error("encode response failed", "err", err)
	}
}

type errorBody struct {
	Error errorDetail `json:"error"`
}

type errorDetail struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

func writeError(w http.ResponseWriter, code string, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(errorBody{Error: errorDetail{Code: code, Message: message}}); err != nil {
		slog.Debug("encode error response failed", "err", err)
	}
}
