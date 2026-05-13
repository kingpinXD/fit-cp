#!/usr/bin/env bash
# Deploys the fit-cp backend to Cloud Run.
#
# Usage:
#   bash deploy/cloud-run.sh            # apply
#   bash deploy/cloud-run.sh --dry-run  # print resolved gcloud command, change nothing
#
# Required env (loaded from deploy/.env.cloudrun if present, or your shell):
#   GCP_PROJECT             — target GCP project
#   REGION                  — e.g. us-central1
#   SERVICE_NAME            — Cloud Run service name
#   NEON_DATABASE_URL       — Postgres connection string (Neon)
#   FIREBASE_PROJECT_ID     — fit-cp Firebase project id
#   FIREBASE_CREDS_SECRET   — Secret Manager secret name holding service account JSON
#   IMAGE_TAG               — fully qualified Artifact Registry image to deploy
#
# The script mounts FIREBASE_CREDS_SECRET as a file and points
# GOOGLE_APPLICATION_CREDENTIALS at it so the Admin SDK initializes against the
# right project.

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env.cloudrun"
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -o allexport
  source "${ENV_FILE}"
  set +o allexport
fi

required=(GCP_PROJECT REGION SERVICE_NAME NEON_DATABASE_URL FIREBASE_PROJECT_ID FIREBASE_CREDS_SECRET IMAGE_TAG)
missing=()
for var in "${required[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    missing+=("${var}")
  fi
done
if (( ${#missing[@]} > 0 )); then
  echo "missing required vars: ${missing[*]}" >&2
  echo "populate deploy/.env.cloudrun (see .env.cloudrun.example)" >&2
  exit 1
fi

CREDS_MOUNT_PATH="/secrets/firebase-creds/key.json"

# gcloud run deploy: image, env vars, secret-mount, service account.
# Health check defaults to GET / which we don't serve, so set startup probe to /healthz.
cmd=(
  gcloud run deploy "${SERVICE_NAME}"
  --project "${GCP_PROJECT}"
  --region "${REGION}"
  --image "${IMAGE_TAG}"
  --platform managed
  --allow-unauthenticated
  --port 8080
  --memory 512Mi
  --cpu 1
  --min-instances 0
  --max-instances 4
  --timeout 30s
  --set-env-vars "FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}"
  --set-env-vars "GOOGLE_APPLICATION_CREDENTIALS=${CREDS_MOUNT_PATH}"
  --set-env-vars "PORT=8080"
  --set-env-vars "^@^DATABASE_URL=${NEON_DATABASE_URL}"
  --set-secrets "${CREDS_MOUNT_PATH}=${FIREBASE_CREDS_SECRET}:latest"
)

printf 'resolved gcloud command:\n'
printf '  %q ' "${cmd[@]}"
printf '\n'

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "dry-run: not executing"
  exit 0
fi

"${cmd[@]}"
