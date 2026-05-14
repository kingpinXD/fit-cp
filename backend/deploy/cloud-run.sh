#!/usr/bin/env bash
# Deploys the fit-cp backend to Cloud Run from source.
#
# Builds via Cloud Build, pushes to Artifact Registry, deploys in one shot.
# Cloud Run's runtime service account provides ADC, which the Firebase Admin
# SDK uses to fetch the public JWKs needed for ID token verification — no
# Firebase service account JSON or Secret Manager mount required.
#
# Usage:
#   bash deploy/cloud-run.sh             # apply
#   bash deploy/cloud-run.sh --dry-run   # print resolved gcloud command, change nothing
#
# Required env (export in shell, or set in deploy/.env.cloudrun if present):
#   GCP_PROJECT          target GCP project
#   REGION               e.g. us-central1
#   SERVICE_NAME         Cloud Run service name (e.g. fit-backend)
#   NEON_DATABASE_URL    pooled Postgres connection string
#   FIREBASE_PROJECT_ID  fit-cp Firebase project id (e.g. fit-cp-tanmay)
#   OPENAI_API_KEY       OpenAI key for /v1/agent/chat

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

required=(GCP_PROJECT REGION SERVICE_NAME NEON_DATABASE_URL FIREBASE_PROJECT_ID OPENAI_API_KEY)
missing=()
for var in "${required[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    missing+=("${var}")
  fi
done
if (( ${#missing[@]} > 0 )); then
  echo "missing required vars: ${missing[*]}" >&2
  exit 1
fi

BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Build + push + deploy from source in one call. gcloud handles Dockerfile detection,
# Cloud Build invocation, Artifact Registry push, and Cloud Run rollout.
cmd=(
  gcloud run deploy "${SERVICE_NAME}"
  --project "${GCP_PROJECT}"
  --region "${REGION}"
  --source "${BACKEND_DIR}"
  --platform managed
  --allow-unauthenticated
  --quiet
  --port 8080
  --memory 512Mi
  --cpu 1
  --min-instances 0
  --max-instances 4
  --timeout 30s
  --set-env-vars "FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}"
  --set-env-vars "^|^DATABASE_URL=${NEON_DATABASE_URL}"
  --set-env-vars "OPENAI_API_KEY=${OPENAI_API_KEY}"
)

echo "resolved gcloud command:"
printf '  %q ' "${cmd[@]}"
printf '\n'

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "dry-run: not executing"
  exit 0
fi

"${cmd[@]}"
