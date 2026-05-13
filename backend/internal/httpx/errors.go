package httpx

import (
	"encoding/json"
	"log/slog"
	"net/http"
)

// errorBody is the wire shape every error response uses. Frontend can rely on it.
type errorBody struct {
	Error errorDetail `json:"error"`
}

type errorDetail struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// WriteError writes a JSON error response with the standard shape and logs at debug.
func WriteError(w http.ResponseWriter, code string, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(errorBody{Error: errorDetail{Code: code, Message: message}}); err != nil {
		slog.Debug("encode error response failed", "err", err)
	}
}

// WriteJSON writes a successful JSON response.
func WriteJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		slog.Error("encode response failed", "err", err)
	}
}
