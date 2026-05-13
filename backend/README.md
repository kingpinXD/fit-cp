# fit-cp backend

Go service that serves the exercise catalog (seeded from [free-exercise-db](https://github.com/yuhonas/free-exercise-db)) to the Flutter app, behind Firebase ID token auth.

Lives entirely under `backend/` so the Flutter app, configs, and tooling at the repo root stay untouched.

## Stack

- Go (stdlib `net/http` with Go 1.22+ method-scoped routing)
- Postgres 16 (docker-compose locally, Neon in production)
- `sqlc` for type-safe query generation
- `golang-migrate` for schema migrations
- `firebase.google.com/go/v4` for ID token verification
- `log/slog` for structured logs
- env-var configuration loaded once at startup

## Prereqs

```bash
brew install golang-migrate sqlc
# Docker Desktop (or compatible) for Postgres
```

Go 1.23+ recommended.

## Local setup

```bash
cd backend
cp .env.example .env       # then edit if needed
make docker-up             # starts Postgres on :5432
make migrate-up            # applies schema
make seed                  # downloads exercises.json and upserts ~870 rows
AUTH_DISABLED=true make run
curl -s localhost:8080/health
```

## Endpoints (T6)

All `v1/*` routes require `Authorization: Bearer <firebase-id-token>`. In local dev, set `AUTH_DISABLED=true` and the middleware injects `uid=dev`.

- `GET /health` — liveness + DB ping. Public.
- `GET /v1/exercises?muscle=&equipment=&level=&q=&limit=&offset=` — paginated list.
- `GET /v1/exercises/{id}` — single exercise by slug id (e.g. `Barbell_Curl`).
- `GET /v1/taxonomy` — `{muscles, equipment, levels, categories}` for filter UIs.

Error shape:
```json
{"error":{"code":"not_found","message":"exercise not found"}}
```

## Make targets

| Target           | What it does                                              |
|------------------|-----------------------------------------------------------|
| `run`            | `go run ./cmd/server`                                     |
| `build`          | builds `bin/server` and `bin/seed`                        |
| `test`           | `go test ./... -count=1`                                  |
| `vet`            | `go vet ./...`                                            |
| `lint`           | vet + gofmt drift check                                   |
| `sqlc`           | regenerates `internal/db/` from `queries/*.sql`           |
| `seed`           | runs the seed CLI against `DATABASE_URL`                  |
| `migrate-up`     | applies all pending migrations                            |
| `migrate-down`   | rolls back the most recent migration                      |
| `migrate-new`    | scaffolds a new migration: `make migrate-new NAME=foo`    |
| `docker-up/down` | starts/stops the docker-compose Postgres                  |

## Integration tests

Integration tests read `TEST_DATABASE_URL` — deliberately separate from the runtime `DATABASE_URL` so a shell pointing at production can't trip the suite into running `TRUNCATE`. If unset, integration tests skip cleanly and only unit tests run.

`make test` defaults `TEST_DATABASE_URL` to the docker-compose connection. As a second layer, the test helper refuses to proceed unless the host is one of `localhost`, `127.0.0.1`, `::1`, `postgres` (docker-compose), or `host.docker.internal`.

```bash
make docker-up
make migrate-up
make test                          # uses the docker-compose default
TEST_DATABASE_URL=... make test    # custom local target
```

## Firebase auth notes

Firebase ID tokens carry the Firebase project ID in the `aud` claim. The verifier rejects tokens signed for any other project. The project ID for fit-cp is `fit-cp-tanmay` — same as the Flutter app's `google-services.json`.

Three ways to satisfy auth locally:
1. `AUTH_DISABLED=true` — bypass, uid is `dev`.
2. `GOOGLE_APPLICATION_CREDENTIALS=/path/to/firebase-service-account.json` — full verification.
3. Set `FIREBASE_PROJECT_ID` only and rely on the SDK's JWK route — works without creds in some setups.

Production (Cloud Run) uses ADC: leave `GOOGLE_APPLICATION_CREDENTIALS` unset; the runtime service account injects it.

## Deploy

See [`deploy/README.md`](deploy/README.md) for the Cloud Run + Neon runbook.
