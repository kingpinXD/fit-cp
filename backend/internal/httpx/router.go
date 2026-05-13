package httpx

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
)

// RouterDeps wires everything a fully configured router needs.
type RouterDeps struct {
	Pool          *pgxpool.Pool
	AuthMW        func(http.Handler) http.Handler // built by caller, lets tests inject a stub
}

// NewRouter returns the full router with /healthz public and the /v1 surface
// guarded by AuthMW. Outer middleware (recover, request-id, logger) wraps both.
func NewRouter(deps RouterDeps) http.Handler {
	api := NewAPI(deps.Pool)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", api.Healthz)

	v1 := http.NewServeMux()
	v1.HandleFunc("GET /v1/exercises", api.ListExercises)
	v1.HandleFunc("GET /v1/exercises/{id}", api.GetExercise)
	v1.HandleFunc("GET /v1/taxonomy", api.GetTaxonomy)
	mux.Handle("/v1/", deps.AuthMW(v1))

	return RecoverMiddleware(RequestIDMiddleware(LoggerMiddleware(mux)))
}
