package httpx

import (
	"encoding/json"
	"net/http"
)

// NewRouter wires the minimal routes available at T1. T6 expands this with
// the full v1 surface (exercises, taxonomy) and auth.
func NewRouter() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", healthz)
	return mux
}

func healthz(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}
