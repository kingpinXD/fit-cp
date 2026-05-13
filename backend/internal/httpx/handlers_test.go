package httpx_test

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/kingpinXD/fit-cp/backend/internal/auth"
	"github.com/kingpinXD/fit-cp/backend/internal/httpx"
	"github.com/kingpinXD/fit-cp/backend/internal/testhelpers"
)

func newTestServer(t *testing.T) *httptest.Server {
	t.Helper()
	pool := testhelpers.RequireDB(t)
	testhelpers.SeedFixtures(t, pool)
	router := httpx.NewRouter(httpx.RouterDeps{
		Pool:   pool,
		AuthMW: auth.DisabledMiddleware(),
	})
	srv := httptest.NewServer(router)
	t.Cleanup(srv.Close)
	return srv
}

func get(t *testing.T, srv *httptest.Server, path string) (int, []byte) {
	t.Helper()
	resp, err := http.Get(srv.URL + path)
	if err != nil {
		t.Fatalf("get %s: %v", path, err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, body
}

func TestHealthz(t *testing.T) {
	srv := newTestServer(t)
	status, body := get(t, srv, "/healthz")
	if status != http.StatusOK {
		t.Fatalf("status: want 200, got %d", status)
	}
	var got map[string]string
	if err := json.Unmarshal(body, &got); err != nil {
		t.Fatalf("decode: %v: %s", err, body)
	}
	if got["status"] != "ok" || got["db"] != "ok" {
		t.Errorf("unexpected body: %v", got)
	}
}

func TestListExercisesNoFilter(t *testing.T) {
	srv := newTestServer(t)
	status, body := get(t, srv, "/v1/exercises")
	if status != http.StatusOK {
		t.Fatalf("status: want 200, got %d body=%s", status, body)
	}
	var got struct {
		Exercises []struct {
			ID      string `json:"id"`
			Muscles struct {
				Primary   []string `json:"primary"`
				Secondary []string `json:"secondary"`
			} `json:"muscles"`
		} `json:"exercises"`
		Total  int `json:"total"`
		Limit  int `json:"limit"`
		Offset int `json:"offset"`
	}
	if err := json.Unmarshal(body, &got); err != nil {
		t.Fatalf("decode: %v: %s", err, body)
	}
	if got.Total != 3 || len(got.Exercises) != 3 {
		t.Fatalf("want 3 exercises, got total=%d list=%d", got.Total, len(got.Exercises))
	}
	if got.Limit != 50 || got.Offset != 0 {
		t.Errorf("pagination defaults wrong: limit=%d offset=%d", got.Limit, got.Offset)
	}
}

func TestListExercisesFilteredByMuscle(t *testing.T) {
	srv := newTestServer(t)
	status, body := get(t, srv, "/v1/exercises?muscle=biceps&limit=5")
	if status != http.StatusOK {
		t.Fatalf("status: want 200, got %d body=%s", status, body)
	}
	var got struct {
		Exercises []struct {
			ID string `json:"id"`
		} `json:"exercises"`
		Total int `json:"total"`
	}
	_ = json.Unmarshal(body, &got)
	if got.Total != 2 || len(got.Exercises) != 2 {
		t.Fatalf("want 2 biceps exercises, got total=%d list=%d", got.Total, len(got.Exercises))
	}
}

func TestListExercisesLimitClamped(t *testing.T) {
	srv := newTestServer(t)
	status, body := get(t, srv, "/v1/exercises?limit=9999")
	if status != http.StatusOK {
		t.Fatalf("status: want 200, got %d", status)
	}
	var got struct {
		Limit int `json:"limit"`
	}
	_ = json.Unmarshal(body, &got)
	if got.Limit != 200 {
		t.Errorf("limit should be clamped to 200, got %d", got.Limit)
	}
}

func TestGetExerciseByID(t *testing.T) {
	srv := newTestServer(t)
	status, body := get(t, srv, "/v1/exercises/Barbell_Curl")
	if status != http.StatusOK {
		t.Fatalf("status: want 200, got %d body=%s", status, body)
	}
	var got struct {
		ID      string  `json:"id"`
		Name    string  `json:"name"`
		Force   *string `json:"force"`
		Muscles struct {
			Primary   []string `json:"primary"`
			Secondary []string `json:"secondary"`
		} `json:"muscles"`
		ImageURLs []string `json:"imageUrls"`
	}
	if err := json.Unmarshal(body, &got); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if got.ID != "Barbell_Curl" || got.Name != "Barbell Curl" {
		t.Errorf("unexpected body: %+v", got)
	}
	if got.Force == nil || *got.Force != "pull" {
		t.Errorf("force should be pull, got %v", got.Force)
	}
	if len(got.Muscles.Primary) != 1 || got.Muscles.Primary[0] != "biceps" {
		t.Errorf("primary muscle wrong: %v", got.Muscles.Primary)
	}
	if len(got.Muscles.Secondary) != 1 || got.Muscles.Secondary[0] != "forearms" {
		t.Errorf("secondary muscle wrong: %v", got.Muscles.Secondary)
	}
	if len(got.ImageURLs) != 1 {
		t.Errorf("imageUrls should have 1 entry, got %d", len(got.ImageURLs))
	}
}

func TestGetExerciseNotFound(t *testing.T) {
	srv := newTestServer(t)
	status, body := get(t, srv, "/v1/exercises/DoesNotExist")
	if status != http.StatusNotFound {
		t.Fatalf("status: want 404, got %d body=%s", status, body)
	}
	var got struct {
		Error struct {
			Code    string `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
	}
	_ = json.Unmarshal(body, &got)
	if got.Error.Code != "not_found" {
		t.Errorf("error code: want not_found, got %q", got.Error.Code)
	}
}

func TestGetTaxonomy(t *testing.T) {
	srv := newTestServer(t)
	status, body := get(t, srv, "/v1/taxonomy")
	if status != http.StatusOK {
		t.Fatalf("status: want 200, got %d", status)
	}
	var got map[string][]string
	if err := json.Unmarshal(body, &got); err != nil {
		t.Fatalf("decode: %v", err)
	}
	for _, key := range []string{"muscles", "equipment", "levels", "categories"} {
		if len(got[key]) == 0 {
			t.Errorf("%s should be non-empty", key)
		}
	}
}

func TestAuthRequiredWhenMiddlewareEnforces(t *testing.T) {
	pool := testhelpers.RequireDB(t)
	testhelpers.SeedFixtures(t, pool)
	rejecting := auth.Middleware(stubVerifier{err: errStub})
	router := httpx.NewRouter(httpx.RouterDeps{Pool: pool, AuthMW: rejecting})
	srv := httptest.NewServer(router)
	defer srv.Close()

	resp, err := http.Get(srv.URL + "/v1/exercises")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status: want 401, got %d", resp.StatusCode)
	}
}

type stubVerifier struct{ err error }

func (s stubVerifier) VerifyIDToken(_ context.Context, _ string) (string, error) {
	return "", s.err
}

var errStub = errStubError("rejected")

type errStubError string

func (e errStubError) Error() string { return string(e) }
