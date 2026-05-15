package httpx

import (
	"crypto/rand"
	"encoding/hex"
	"log/slog"
	"net/http"
	"runtime/debug"
	"time"

	"github.com/kingpinXD/fit-cp/backend/internal/auth"
	"github.com/kingpinXD/fit-cp/backend/internal/httpio"
)

// RecoverMiddleware turns a handler panic into a 500 with the standard error shape.
// Always outermost so it can catch panics from any inner middleware too.
func RecoverMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				slog.Error("panic recovered",
					"err", rec,
					"path", r.URL.Path,
					"stack", string(debug.Stack()))
				httpio.WriteError(w, "internal_error", http.StatusInternalServerError, "internal server error")
			}
		}()
		next.ServeHTTP(w, r)
	})
}

// RequestIDMiddleware reuses an incoming X-Request-Id or generates one.
func RequestIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get(httpio.RequestIDHeader)
		if id == "" {
			id = newRequestID()
		}
		w.Header().Set(httpio.RequestIDHeader, id)
		next.ServeHTTP(w, r.WithContext(httpio.WithRequestID(r.Context(), id)))
	})
}

func newRequestID() string {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "req-fallback"
	}
	return hex.EncodeToString(b[:])
}

// http.ResponseWriter exposes no status getter after WriteHeader, so we wrap it
// to capture status and bytes for the access log.
type statusRecorder struct {
	http.ResponseWriter
	status int
	bytes  int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

func (s *statusRecorder) Write(b []byte) (int, error) {
	if s.status == 0 {
		s.status = http.StatusOK
	}
	n, err := s.ResponseWriter.Write(b)
	s.bytes += n
	return n, err
}

// LoggerMiddleware logs every request with method, path, status, duration, request-id
// and uid (if auth has run).
func LoggerMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w}
		next.ServeHTTP(rec, r)

		uid, _ := auth.UIDFromContext(r.Context())
		slog.Info("http",
			"method", r.Method,
			"path", r.URL.Path,
			"status", rec.status,
			"bytes", rec.bytes,
			"duration_ms", time.Since(start).Milliseconds(),
			"request_id", httpio.RequestIDFromContext(r.Context()),
			"uid", uid)
	})
}
