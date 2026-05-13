# Deploy runbook — Cloud Run + Neon

This is the manual runbook the operator (you) follows the first time. After that, `bash deploy/cloud-run.sh` deploys an updated image.

The script under [`cloud-run.sh`](cloud-run.sh) doesn't create infra — it only deploys to an already-created Cloud Run service. Steps 1-4 below set up the infra; step 5 deploys; step 6 verifies.

## 1. Neon Postgres

1. Sign in to [neon.tech](https://neon.tech) and create a project (region close to the Cloud Run region).
2. Create a database called `fit_backend`.
3. Copy the connection string from the project dashboard (looks like `postgres://user:pass@ep-xxx.us-east-2.aws.neon.tech/fit_backend?sslmode=require`). Paste it into `deploy/.env.cloudrun` as `NEON_DATABASE_URL`.

Run migrations and seed from your laptop pointing at Neon:

```bash
cd backend
DATABASE_URL="postgres://...@neon.tech/fit_backend?sslmode=require" make migrate-up
DATABASE_URL="postgres://...@neon.tech/fit_backend?sslmode=require" make seed
```

The seed CLI is idempotent — safe to re-run when the source dataset updates.

## 2. GCP project + APIs

```bash
export GCP_PROJECT=your-gcp-project
gcloud config set project ${GCP_PROJECT}
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com
```

## 3. Artifact Registry + image build

Create a repo (one-time):

```bash
gcloud artifacts repositories create fit --location=us-central1 --repository-format=docker
```

Build and push the image (re-run on every deploy):

```bash
cd backend
gcloud builds submit --tag us-central1-docker.pkg.dev/${GCP_PROJECT}/fit/fit-backend:latest .
```

`IMAGE_TAG` in `.env.cloudrun` must match what you push.

## 4. Firebase service account (Secret Manager)

1. Open the Firebase console for the `fit-cp-tanmay` project (the same one the Flutter app uses).
2. Project settings -> Service accounts -> Generate new private key. Download the JSON.
3. Upload to Secret Manager:

   ```bash
   gcloud secrets create fit-backend-firebase --data-file=path/to/firebase-creds.json
   ```

   If updating an existing secret:

   ```bash
   gcloud secrets versions add fit-backend-firebase --data-file=path/to/firebase-creds.json
   ```

4. Grant the Cloud Run runtime service account access to the secret. The default service account is `${PROJECT_NUMBER}-compute@developer.gserviceaccount.com`:

   ```bash
   PROJECT_NUMBER=$(gcloud projects describe ${GCP_PROJECT} --format='value(projectNumber)')
   gcloud secrets add-iam-policy-binding fit-backend-firebase \
     --member=serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com \
     --role=roles/secretmanager.secretAccessor
   ```

`FIREBASE_CREDS_SECRET=fit-backend-firebase` in `.env.cloudrun`.

## 5. Deploy

```bash
cd backend
cp deploy/.env.cloudrun.example deploy/.env.cloudrun
# edit deploy/.env.cloudrun with values from steps 1-4

# Dry-run first to inspect the resolved gcloud command:
bash deploy/cloud-run.sh --dry-run

# Then deploy:
bash deploy/cloud-run.sh
```

The script:
- Sets `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS`, `DATABASE_URL` as env vars on the service.
- Mounts the `fit-backend-firebase` secret at `/secrets/firebase-creds/key.json`.
- Allows unauthenticated traffic at the Cloud Run layer (the app enforces auth via Firebase ID tokens on every `/v1` request).

## 6. Smoke test

```bash
SERVICE_URL=$(gcloud run services describe fit-backend --region us-central1 --format='value(status.url)')
curl -s ${SERVICE_URL}/healthz
# {"status":"ok","db":"ok"}

# /v1 should reject without a token:
curl -s -o /dev/null -w '%{http_code}\n' ${SERVICE_URL}/v1/exercises
# 401
```

To smoke-test an authenticated request, grab a fresh ID token from the Flutter app (Firebase Auth, signed-in user, `user.getIdToken()`) and:

```bash
TOKEN=...
curl -s -H "Authorization: Bearer ${TOKEN}" ${SERVICE_URL}/v1/exercises?limit=1 | head -c 400
```
