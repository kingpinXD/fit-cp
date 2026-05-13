package auth_test

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/kingpinXD/fit-cp/backend/internal/auth"
)

type stubVerifier struct {
	uid string
	err error
}

func (s stubVerifier) VerifyIDToken(_ context.Context, _ string) (string, error) {
	return s.uid, s.err
}

func TestMiddleware(t *testing.T) {
	cases := []struct {
		name       string
		header     string
		verifier   auth.TokenVerifier
		wantStatus int
		wantUID    string
	}{
		{
			name:       "missing header",
			header:     "",
			verifier:   stubVerifier{uid: "u1"},
			wantStatus: http.StatusUnauthorized,
		},
		{
			name:       "malformed header without bearer prefix",
			header:     "Token xyz",
			verifier:   stubVerifier{uid: "u1"},
			wantStatus: http.StatusUnauthorized,
		},
		{
			name:       "empty token after bearer",
			header:     "Bearer ",
			verifier:   stubVerifier{uid: "u1"},
			wantStatus: http.StatusUnauthorized,
		},
		{
			name:       "verifier returns error",
			header:     "Bearer abc",
			verifier:   stubVerifier{err: errors.New("expired")},
			wantStatus: http.StatusUnauthorized,
		},
		{
			name:       "verifier returns uid",
			header:     "Bearer abc",
			verifier:   stubVerifier{uid: "u1"},
			wantStatus: http.StatusOK,
			wantUID:    "u1",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			var gotUID string
			handler := auth.Middleware(tc.verifier)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if uid, ok := auth.UIDFromContext(r.Context()); ok {
					gotUID = uid
				}
				w.WriteHeader(http.StatusOK)
			}))

			req := httptest.NewRequest(http.MethodGet, "/whatever", nil)
			if tc.header != "" {
				req.Header.Set("Authorization", tc.header)
			}
			rr := httptest.NewRecorder()
			handler.ServeHTTP(rr, req)

			if rr.Code != tc.wantStatus {
				t.Fatalf("status: want %d, got %d (body=%s)", tc.wantStatus, rr.Code, rr.Body.String())
			}
			if tc.wantStatus == http.StatusOK && gotUID != tc.wantUID {
				t.Fatalf("uid: want %q, got %q", tc.wantUID, gotUID)
			}
			if tc.wantStatus == http.StatusUnauthorized {
				if ct := rr.Header().Get("Content-Type"); !strings.Contains(ct, "application/json") {
					t.Errorf("content-type: want application/json, got %q", ct)
				}
				if !strings.Contains(rr.Body.String(), `"unauthorized"`) {
					t.Errorf("body should include unauthorized code, got %s", rr.Body.String())
				}
			}
		})
	}
}

func TestDisabledMiddleware(t *testing.T) {
	var gotUID string
	handler := auth.DisabledMiddleware()(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotUID, _ = auth.UIDFromContext(r.Context())
		w.WriteHeader(http.StatusOK)
	}))
	req := httptest.NewRequest(http.MethodGet, "/whatever", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status: want 200, got %d", rr.Code)
	}
	if gotUID != "dev" {
		t.Fatalf("uid: want dev, got %q", gotUID)
	}
}
