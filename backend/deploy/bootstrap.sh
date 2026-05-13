#!/usr/bin/env bash
# End-to-end fit-cp backend deploy.
#
# Idempotent: re-run safely. Each step checks current state before acting.
#
# Required env:
#   NEON_API_KEY         create at https://console.neon.tech/app/settings/api-keys
#   NEON_ORG_ID          your Neon org id
#   GCP_PROJECT          target GCP project (must exist, you must have access)
#
# Optional env (defaults shown):
#   REGION=us-central1
#   SERVICE_NAME=fit-backend
#   NEON_PROJECT_NAME=fit-cp-backend
#   FIREBASE_PROJECT_ID=fit-cp-tanmay
#   NEON_DATABASE_URL=   (when set, skips Neon create; uses this directly)
#
# Prereqs on your machine:
#   - gcloud installed, logged in (gcloud auth login) with access to GCP_PROJECT
#   - migrate (golang-migrate) installed
#   - go installed (for the seed CLI)
#   - jq, curl

set -euo pipefail

# ---------- config ------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ENV_FILE="${SCRIPT_DIR}/.env.cloudrun"
if [[ -f "${ENV_FILE}" ]]; then
  set -o allexport
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +o allexport
fi

: "${REGION:=us-central1}"
: "${SERVICE_NAME:=fit-backend}"
: "${NEON_PROJECT_NAME:=fit-cp-backend}"
: "${FIREBASE_PROJECT_ID:=fit-cp-tanmay}"
: "${NEON_REGION:=aws-us-east-1}"

required=(NEON_API_KEY NEON_ORG_ID GCP_PROJECT)
missing=()
for var in "${required[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    missing+=("${var}")
  fi
done
if (( ${#missing[@]} > 0 )); then
  echo "missing required env: ${missing[*]}" >&2
  echo "see deploy/bootstrap.sh header for details" >&2
  exit 1
fi

# ---------- helpers -----------------------------------------------------

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok() { printf '    \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }
fail() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 not found on PATH"
}

neon_api() {
  local method="$1" path="$2"
  shift 2
  curl -sS -X "${method}" \
    -H "Authorization: Bearer ${NEON_API_KEY}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "https://console.neon.tech/api/v2${path}" "$@"
}

# ---------- prereq checks -----------------------------------------------

log "checking prereqs"
need gcloud
need curl
need jq
need migrate
need go
ok "all CLIs present"

active_account="$(gcloud config get-value account 2>/dev/null || true)"
if [[ -z "${active_account}" ]]; then
  fail "no active gcloud account. run: gcloud auth login"
fi
ok "gcloud account: ${active_account}"

if ! gcloud projects describe "${GCP_PROJECT}" --quiet >/dev/null 2>&1; then
  fail "GCP project '${GCP_PROJECT}' not accessible by ${active_account}"
fi
ok "GCP project: ${GCP_PROJECT}"

# ---------- step 1: ensure Neon project + db url -----------------------

if [[ -n "${NEON_DATABASE_URL:-}" ]]; then
  log "neon: using NEON_DATABASE_URL from env (skipping create)"
else
  log "neon: locating project '${NEON_PROJECT_NAME}'"
  list_json="$(neon_api GET "/projects?org_id=${NEON_ORG_ID}&limit=100")"
  project_id="$(jq -r --arg name "${NEON_PROJECT_NAME}" '.projects[]? | select(.name == $name) | .id' <<<"${list_json}" | head -n1)"

  if [[ -n "${project_id}" && "${project_id}" != "null" ]]; then
    ok "found existing project: ${project_id}"
    # Fetch the pooled connection URI from the running compute endpoint.
    role="neondb_owner"
    db="neondb"
    pooled_json="$(neon_api GET "/projects/${project_id}/connection_uri?database_name=${db}&role_name=${role}&pooled=true")"
    direct_json="$(neon_api GET "/projects/${project_id}/connection_uri?database_name=${db}&role_name=${role}&pooled=false")"
    NEON_POOLED_URL="$(jq -r '.uri' <<<"${pooled_json}")"
    NEON_DIRECT_URL="$(jq -r '.uri' <<<"${direct_json}")"
  else
    log "neon: creating project '${NEON_PROJECT_NAME}' in ${NEON_REGION}"
    body="$(jq -nc --arg name "${NEON_PROJECT_NAME}" --arg region "${NEON_REGION}" --arg org "${NEON_ORG_ID}" \
      '{project: {name: $name, region_id: $region, org_id: $org, pg_version: 16}}')"
    create_json="$(neon_api POST "/projects" -d "${body}")"
    project_id="$(jq -r '.project.id' <<<"${create_json}")"
    [[ -n "${project_id}" && "${project_id}" != "null" ]] || fail "neon create failed: ${create_json}"
    ok "created: ${project_id}"
    NEON_DIRECT_URL="$(jq -r '.connection_uris[0].connection_uri' <<<"${create_json}")"
    pooler_host="$(jq -r '.connection_uris[0].connection_parameters.pooler_host' <<<"${create_json}")"
    NEON_POOLED_URL="$(sed -E "s|@[^/]+/|@${pooler_host}/|" <<<"${NEON_DIRECT_URL}")"
  fi
  NEON_DATABASE_URL="${NEON_POOLED_URL}"
  export NEON_DATABASE_URL
  ok "pooled url:  ${NEON_POOLED_URL%@*}@[redacted]"
  ok "direct url:  ${NEON_DIRECT_URL%@*}@[redacted]"
fi

# ---------- step 2: migrate + seed --------------------------------------

migrate_url="${NEON_DIRECT_URL:-${NEON_DATABASE_URL}}"

log "migrate: applying schema"
migrate -path "${BACKEND_DIR}/migrations" -database "${migrate_url}" up || warn "migrate up returned non-zero (likely 'no change')"
ok "schema applied"

log "seed: loading exercise catalog"
( cd "${BACKEND_DIR}" && DATABASE_URL="${migrate_url}" go run ./cmd/seed )
ok "seed complete"

# ---------- step 3: GCP APIs + Artifact Registry ------------------------

log "gcp: enabling required APIs"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com \
  --project "${GCP_PROJECT}" --quiet
ok "apis enabled"

# Cloud Build + gcloud run deploy --source uses a default Artifact Registry repo
# named 'cloud-run-source-deploy' which gcloud will create on first deploy.
# Nothing to do here unless you want a custom repo; default works.

# ---------- step 4: deploy ----------------------------------------------

log "cloud run: deploying ${SERVICE_NAME} to ${REGION}"
export GCP_PROJECT REGION SERVICE_NAME NEON_DATABASE_URL FIREBASE_PROJECT_ID
bash "${SCRIPT_DIR}/cloud-run.sh"

# ---------- step 5: smoke test ------------------------------------------

log "smoke test: GET /health"
service_url="$(gcloud run services describe "${SERVICE_NAME}" --region "${REGION}" --project "${GCP_PROJECT}" --format='value(status.url)')"
ok "service URL: ${service_url}"

if curl -fsS "${service_url}/health" -o /tmp/health.json; then
  ok "/health: $(cat /tmp/health.json)"
else
  warn "/health did not return 200 — check Cloud Run logs"
fi

log "done"
echo "service:   ${service_url}"
echo "v1 routes require Authorization: Bearer <firebase-id-token>"
