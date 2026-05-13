// Package auth verifies Firebase ID tokens on incoming requests.
//
// Firebase tokens carry the Firebase project ID in their `aud` claim, so a token
// minted for one Firebase project cannot be replayed against the backend for
// another. The verifier is wired with the project ID at startup.
package auth

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"

	firebase "firebase.google.com/go/v4"
	firebaseauth "firebase.google.com/go/v4/auth"
	"google.golang.org/api/option"
)

// TokenVerifier is the minimal surface the middleware needs. Production wires
// it to the Firebase SDK; tests swap in a stub.
type TokenVerifier interface {
	VerifyIDToken(ctx context.Context, token string) (uid string, err error)
}

// firebaseVerifier wraps the real Firebase SDK client.
type firebaseVerifier struct {
	client *firebaseauth.Client
}

func (v *firebaseVerifier) VerifyIDToken(ctx context.Context, token string) (string, error) {
	tok, err := v.client.VerifyIDToken(ctx, token)
	if err != nil {
		return "", err
	}
	return tok.UID, nil
}

// NewFirebaseVerifier initializes a TokenVerifier backed by the Firebase Admin SDK.
// projectID is required (Firebase tokens' `aud` claim is the project ID). credsPath
// is optional — when empty, Application Default Credentials are used (Cloud Run
// supplies these via the runtime service account).
func NewFirebaseVerifier(ctx context.Context, projectID, credsPath string) (TokenVerifier, error) {
	if projectID == "" {
		return nil, errors.New("firebase project id is required")
	}
	cfg := &firebase.Config{ProjectID: projectID}
	var opts []option.ClientOption
	if credsPath != "" {
		opts = append(opts, option.WithCredentialsFile(credsPath))
	}
	app, err := firebase.NewApp(ctx, cfg, opts...)
	if err != nil {
		return nil, fmt.Errorf("firebase init: %w", err)
	}
	client, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("firebase auth client: %w", err)
	}
	return &firebaseVerifier{client: client}, nil
}

type ctxKey struct{}

// WithUID returns a new context carrying the authenticated uid. Exported so other
// middleware (e.g. AUTH_DISABLED bypass) can populate the same key.
func WithUID(ctx context.Context, uid string) context.Context {
	return context.WithValue(ctx, ctxKey{}, uid)
}

// UIDFromContext returns the authenticated uid set by the middleware.
func UIDFromContext(ctx context.Context) (string, bool) {
	uid, ok := ctx.Value(ctxKey{}).(string)
	return uid, ok && uid != ""
}

// Middleware verifies the Authorization header and stashes the uid in the
// request context. On failure it writes a 401 with the standard error shape.
func Middleware(v TokenVerifier) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token, err := extractBearer(r.Header.Get("Authorization"))
			if err != nil {
				writeUnauthorized(w, err.Error())
				return
			}
			uid, err := v.VerifyIDToken(r.Context(), token)
			if err != nil {
				writeUnauthorized(w, "invalid token")
				return
			}
			next.ServeHTTP(w, r.WithContext(WithUID(r.Context(), uid)))
		})
	}
}

// DisabledMiddleware is used when AUTH_DISABLED=true so local devs can hit the
// API without a real token. It injects uid="dev".
func DisabledMiddleware() func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			next.ServeHTTP(w, r.WithContext(WithUID(r.Context(), "dev")))
		})
	}
}

func extractBearer(header string) (string, error) {
	if header == "" {
		return "", errors.New("missing authorization header")
	}
	const prefix = "Bearer "
	if !strings.HasPrefix(header, prefix) {
		return "", errors.New("authorization header must be Bearer <token>")
	}
	token := strings.TrimSpace(header[len(prefix):])
	if token == "" {
		return "", errors.New("empty token")
	}
	return token, nil
}

func writeUnauthorized(w http.ResponseWriter, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"error": map[string]string{
			"code":    "unauthorized",
			"message": message,
		},
	})
}
