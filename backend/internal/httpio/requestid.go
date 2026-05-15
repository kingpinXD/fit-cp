package httpio

import "context"

// RequestIDHeader is the canonical request-id header name. Middleware reads
// the incoming value (or generates one), echoes it on the response, and stashes
// it in the context for downstream handlers to log.
const RequestIDHeader = "X-Request-Id"

type requestIDKey struct{}

// WithRequestID returns a context carrying the given request id.
func WithRequestID(ctx context.Context, id string) context.Context {
	return context.WithValue(ctx, requestIDKey{}, id)
}

// RequestIDFromContext returns the request id set by WithRequestID. Empty when
// the middleware hasn't run (test calls, background work, etc.).
func RequestIDFromContext(ctx context.Context) string {
	id, _ := ctx.Value(requestIDKey{}).(string)
	return id
}
