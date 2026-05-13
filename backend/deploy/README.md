# Deploy runbook — Cloud Run + Neon

Two scripts:

- **`bootstrap.sh`** — one-shot end-to-end. Creates the Neon project, runs migrations + seed, enables GCP APIs, deploys to Cloud Run, smoke-tests. Idempotent.
- **`cloud-run.sh`** — Cloud Run redeploy only (called by bootstrap, or run alone for code-only updates).

Both are non-interactive. The only thing you do interactively is `gcloud auth login`.

## Prereqs

```bash
brew install --cask google-cloud-sdk   # if not already installed
brew install golang-migrate jq         # already required for local dev
```

Then:

```bash
gcloud auth login                       # use your personal Google account
gcloud config set project fit-cp-backend
```

## First run

You need three values:

| Var               | Where to find                                                          |
|-------------------|------------------------------------------------------------------------|
| `NEON_API_KEY`    | https://console.neon.tech/app/settings/api-keys (create new)           |
| `NEON_ORG_ID`     | https://console.neon.tech/app/settings/general                         |
| `GCP_PROJECT`     | The GCP project id you'll deploy into (must have billing enabled)      |

Then:

```bash
export NEON_API_KEY=napi_...
export NEON_ORG_ID=org-...
export GCP_PROJECT=fit-cp-backend

cd backend
bash deploy/bootstrap.sh
```

The script prints a per-step ✓/! summary and ends with the deployed Cloud Run URL plus the `/health` response.

## Subsequent deploys (code-only)

After the first bootstrap, redeploys don't need to touch Neon:

```bash
cd backend
NEON_DATABASE_URL=$(...) \
GCP_PROJECT=fit-cp-backend \
FIREBASE_PROJECT_ID=fit-cp-tanmay \
REGION=us-central1 \
SERVICE_NAME=fit-backend \
bash deploy/cloud-run.sh
```

Or set those in `deploy/.env.cloudrun` (gitignored) and just `bash deploy/cloud-run.sh`.

`bash deploy/cloud-run.sh --dry-run` prints the resolved gcloud command without applying it.

## What gets created

| Resource                          | Where         | Cost (free tier)         |
|-----------------------------------|---------------|--------------------------|
| Neon project `fit-cp-backend`     | aws-us-east-1 | free, autosuspends idle  |
| GCP Cloud Run service `fit-backend` | us-central1 | free, scales to zero     |
| Artifact Registry repo `cloud-run-source-deploy` | us-central1 | free up to 0.5 GB |
| Cloud Build job per deploy        | us-central1   | free first 120 min/day   |

No Firebase service account JSON, no Secret Manager. Cloud Run's runtime ADC is enough to verify Firebase ID tokens (the SDK only needs project id + access to Google's public JWKs).

## Smoke test (manual)

```bash
SERVICE_URL=$(gcloud run services describe fit-backend --region us-central1 --format='value(status.url)')

curl -s ${SERVICE_URL}/health
# {"status":"ok","db":"ok"}

curl -s -o /dev/null -w '%{http_code}\n' ${SERVICE_URL}/v1/exercises
# 401 (no token)

# Authenticated: grab an ID token from the Flutter app (Firebase Auth, user.getIdToken())
TOKEN=...
curl -s -H "Authorization: Bearer ${TOKEN}" ${SERVICE_URL}/v1/exercises?limit=1 | head -c 400
```

## Logs

```bash
gcloud logging read 'resource.type=cloud_run_revision AND resource.labels.service_name=fit-backend' \
  --project fit-cp-backend --limit 50 --format='value(textPayload)'
```
