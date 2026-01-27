#!/usr/bin/env bash
set -euo pipefail

API_BASE="${NF_API_BASE:-https://api.northflank.com/v1}"

PROJECT_ID="${NF_PROJECT_ID:-habbits}"
PROJECT_NAME="${NF_PROJECT_NAME:-Habbits}"
PROJECT_REGION="${NF_PROJECT_REGION:-europe-west}"

SERVICE_NAME="${NF_SERVICE_NAME:-habbits-web}"
DEPLOY_PLAN="${NF_DEPLOY_PLAN:-nf-compute-20}"

ADDON_NAME="${NF_ADDON_NAME:-habbits-db}"
ADDON_VERSION="${NF_ADDON_VERSION:-15}"
ADDON_PLAN="${NF_ADDON_PLAN:-nf-compute-20}"
ADDON_STORAGE="${NF_ADDON_STORAGE:-4096}"

DOMAIN="${NF_DOMAIN:-habbits.xyz}"
SUBDOMAIN="${NF_SUBDOMAIN:-@}"

REPO_URL="${NF_REPO_URL:-}"
REPO_BRANCH="${NF_REPO_BRANCH:-main}"
REPO_TYPE="${NF_REPO_TYPE:-github}"

PHX_HOST="${NF_PHX_HOST:-$DOMAIN}"
APP_URL="${NF_APP_URL:-https://$PHX_HOST}"

NF_TOKEN="${NF_TOKEN:-}"
if [[ -z "${NF_TOKEN}" && -f "${HOME}/.northflank_token" ]]; then
  NF_TOKEN="$(<"${HOME}/.northflank_token")"
fi

if [[ -z "${NF_TOKEN}" ]]; then
  echo "Error: NF_TOKEN is not set. Export NF_TOKEN or create ~/.northflank_token." >&2
  exit 1
fi

auth_header=(-H "Authorization: Bearer ${NF_TOKEN}")

api_request() {
  local method="$1"
  local path="$2"
  local data="${3:-}"

  local url="${API_BASE}${path}"
  local response
  if [[ -n "${data}" ]]; then
    response="$(curl -sS -X "${method}" "${auth_header[@]}" \
      -H "Content-Type: application/json" \
      -d "${data}" \
      -w $'\n%{http_code}\n' \
      "${url}")"
  else
    response="$(curl -sS -X "${method}" "${auth_header[@]}" \
      -w $'\n%{http_code}\n' \
      "${url}")"
  fi

  local http_code
  http_code="$(printf "%s" "${response}" | tail -n1)"
  local body
  body="$(printf "%s" "${response}" | sed '$d')"

  if [[ "${http_code}" -ge 400 ]]; then
    local message
    message="$(printf "%s" "${body}" | jq -r '.error.message // .message // "Unknown error"')"
    echo "Northflank API error (${http_code}): ${message}" >&2
    printf "%s" "${body}" > /tmp/northflank_last_error.json
    return 1
  fi

  printf "%s" "${body}"
}

ensure_project() {
  echo "Ensuring project ${PROJECT_ID} exists..."
  local projects
  projects="$(api_request GET "/projects?perPage=200&page=1")"
  if printf "%s" "${projects}" | jq -e --arg id "${PROJECT_ID}" '.data.projects[]? | select(.id == $id)' >/dev/null; then
    echo "Project ${PROJECT_ID} already exists."
    return 0
  fi

  local payload
  payload="$(jq -n \
    --arg name "${PROJECT_NAME}" \
    --arg region "${PROJECT_REGION}" \
    '{name: $name, region: $region, description: "Habit tracker production"}')"
  api_request POST "/projects" "${payload}" >/dev/null
  echo "Project ${PROJECT_ID} created."
}

ensure_domain() {
  echo "Ensuring domain ${DOMAIN} is registered..."
  local domains
  domains="$(api_request GET "/domains")"
  if ! printf "%s" "${domains}" | jq -e --arg domain "${DOMAIN}" '.data.domains[]? | select(.name == $domain)' >/dev/null; then
    local payload
    payload="$(jq -n --arg domain "${DOMAIN}" '{domain: $domain}')"
    api_request POST "/domains" "${payload}" >/dev/null
    echo "Domain ${DOMAIN} registered."
  else
    echo "Domain ${DOMAIN} already registered."
  fi

  local domain_details
  domain_details="$(api_request GET "/domains/${DOMAIN}")"
  local status hostname token
  status="$(printf "%s" "${domain_details}" | jq -r '.data.status')"
  hostname="$(printf "%s" "${domain_details}" | jq -r '.data.hostname')"
  token="$(printf "%s" "${domain_details}" | jq -r '.data.token')"

  echo "Domain status: ${status}"
  if [[ "${status}" != "verified" ]]; then
    cat <<EOF
DNS verification required before custom domains can be assigned:
- Type: TXT
- Name: ${hostname}.${DOMAIN}
- Value: ${token}
EOF
  fi
}

ensure_secret_key_base() {
  if [[ -n "${NF_SECRET_KEY_BASE:-}" ]]; then
    SECRET_KEY_BASE="${NF_SECRET_KEY_BASE}"
    return 0
  fi

  local secret_file="${HOME}/.northflank_secret"
  if [[ -f "${secret_file}" ]]; then
    SECRET_KEY_BASE="$(<"${secret_file}")"
    return 0
  fi

  echo "Generating SECRET_KEY_BASE..."
  SECRET_KEY_BASE="$(openssl rand -base64 64 | tr -d '\n')"
  (umask 177 && printf "%s" "${SECRET_KEY_BASE}" > "${secret_file}")
  echo "SECRET_KEY_BASE stored at ${secret_file}"
}

ensure_addon() {
  echo "Ensuring PostgreSQL addon ${ADDON_NAME} exists..."
  local addons
  addons="$(api_request GET "/projects/${PROJECT_ID}/addons")"
  local addon_id
  addon_id="$(printf "%s" "${addons}" | jq -r --arg name "${ADDON_NAME}" '.data.addons[]? | select(.name == $name) | .id' | head -n1)"
  if [[ -n "${addon_id}" && "${addon_id}" != "null" ]]; then
    echo "Addon ${ADDON_NAME} already exists (${addon_id})."
    ADDON_ID="${addon_id}"
    return 0
  fi

  local payload
  payload="$(jq -n \
    --arg name "${ADDON_NAME}" \
    --arg type "postgresql" \
    --arg version "${ADDON_VERSION}" \
    --arg plan "${ADDON_PLAN}" \
    --argjson storage "${ADDON_STORAGE}" \
    '{
      name: $name,
      type: $type,
      version: $version,
      billing: {
        deploymentPlan: $plan,
        storage: $storage,
        replicas: 1
      }
    }')"

  local created
  if ! created="$(api_request POST "/projects/${PROJECT_ID}/addons" "${payload}")"; then
    echo "Failed to create addon. If you see a payment method error, add a default payment method in Northflank and re-run." >&2
    exit 1
  fi

  ADDON_ID="$(printf "%s" "${created}" | jq -r '.data.addon.id // .data.id // empty')"
  if [[ -z "${ADDON_ID}" || "${ADDON_ID}" == "null" ]]; then
    # Fall back to listing addons (creation responses may not include the ID).
    addons="$(api_request GET "/projects/${PROJECT_ID}/addons")"
    ADDON_ID="$(printf "%s" "${addons}" | jq -r --arg name "${ADDON_NAME}" '.data.addons[]? | select(.name == $name) | .id' | head -n1)"
  fi

  if [[ -z "${ADDON_ID}" || "${ADDON_ID}" == "null" ]]; then
    echo "Addon was created but no ID could be resolved. Check /tmp/northflank_last_error.json." >&2
    exit 1
  fi

  echo "Addon created (${ADDON_ID})."
}

resolve_database_url() {
  echo "Resolving DATABASE_URL from addon credentials..."

  # Wait for addon to be ready before requesting credentials.
  local status=""
  local attempts=0
  local max_attempts=30
  local sleep_seconds=10

  while [[ "${attempts}" -lt "${max_attempts}" ]]; do
    status="$(api_request GET "/projects/${PROJECT_ID}/addons/${ADDON_ID}" | jq -r '.data.status')"
    if [[ "${status}" == "running" || "${status}" == "ready" || "${status}" == "active" ]]; then
      break
    fi
    echo "Addon status: ${status}. Waiting for readiness..."
    attempts=$((attempts + 1))
    sleep "${sleep_seconds}"
  done

  if [[ "${status}" != "running" && "${status}" != "ready" && "${status}" != "active" ]]; then
    echo "Addon is not ready after waiting. Current status: ${status}" >&2
    exit 1
  fi

  local creds
  creds="$(api_request GET "/projects/${PROJECT_ID}/addons/${ADDON_ID}/credentials")"

  DATABASE_URL="$(
    printf "%s" "${creds}" | jq -r '
      .data.envs.DATABASE_URL //
      .data.envs.POSTGRESQL_URL //
      .data.envs.POSTGRES_URL //
      .data.envs.POSTGRES_URI //
      .data.envs.POSTGRES_URI_ADMIN //
      .data.envs.connectionString //
      empty
    '
  )"

  if [[ -z "${DATABASE_URL}" ]]; then
    echo "Could not find a DATABASE_URL in addon credentials. Inspect /tmp/northflank_last_error.json or the credentials response." >&2
    printf "%s" "${creds}" > /tmp/northflank_addon_credentials.json
    exit 1
  fi

  echo "DATABASE_URL resolved."
}

ensure_service() {
  if [[ -z "${REPO_URL}" ]]; then
    echo "Error: NF_REPO_URL is required to deploy from Git." >&2
    echo "Export NF_REPO_URL (and optionally NF_REPO_BRANCH, NF_REPO_TYPE) and re-run." >&2
    exit 1
  fi

  echo "Ensuring service ${SERVICE_NAME} exists..."
  local services=""
  local service_id=""

  if services="$(api_request GET "/projects/${PROJECT_ID}/services/combined" 2>/dev/null)"; then
    service_id="$(printf "%s" "${services}" | jq -r --arg name "${SERVICE_NAME}" '.data.services[]? | select(.name == $name) | .id' | head -n1)"
  else
    echo "Combined service list endpoint not available; will attempt create."
  fi

  if [[ -n "${service_id}" && "${service_id}" != "null" ]]; then
    SERVICE_ID="${service_id}"
    echo "Service ${SERVICE_NAME} already exists (${SERVICE_ID})."
    return 0
  fi

  ensure_secret_key_base

  local payload
  payload="$(jq -n \
    --arg name "${SERVICE_NAME}" \
    --arg plan "${DEPLOY_PLAN}" \
    --arg repo_url "${REPO_URL}" \
    --arg repo_type "${REPO_TYPE}" \
    --arg repo_branch "${REPO_BRANCH}" \
    --arg phx_host "${PHX_HOST}" \
    --arg app_url "${APP_URL}" \
    --arg secret_key_base "${SECRET_KEY_BASE}" \
    --arg database_url "${DATABASE_URL}" \
    '{
      name: $name,
      description: "Habit Tracker web service",
      billing: {deploymentPlan: $plan},
      deployment: {instances: 1, docker: {configType: "default"}},
      ports: [
        {
          name: "http",
          internalPort: 4000,
          public: true,
          protocol: "HTTP"
        }
      ],
      buildSource: "git",
      vcsData: {
        projectUrl: $repo_url,
        projectType: $repo_type,
        projectBranch: $repo_branch
      },
      buildSettings: {
        dockerfile: {
          dockerFilePath: "/docker/Dockerfile",
          dockerWorkDir: "/"
        }
      },
      runtimeEnvironment: {
        PHX_HOST: $phx_host,
        APP_URL: $app_url,
        SECRET_KEY_BASE: $secret_key_base,
        DATABASE_URL: $database_url,
        POOL_SIZE: "1",
        PORT: "4000"
      },
      healthChecks: [
        {
          protocol: "HTTP",
          type: "readinessProbe",
          path: "/health",
          port: 4000,
          initialDelaySeconds: 10,
          periodSeconds: 30,
          timeoutSeconds: 5,
          failureThreshold: 5,
          successThreshold: 1
        }
      ]
    }')"

  local created
  if ! created="$(api_request POST "/projects/${PROJECT_ID}/services/combined" "${payload}")"; then
    echo "Failed to create service. Check /tmp/northflank_last_error.json for details." >&2
    exit 1
  fi

  SERVICE_ID="$(printf "%s" "${created}" | jq -r '.data.id // .data.service.id // empty')"
  if [[ -z "${SERVICE_ID}" ]]; then
    # Fall back to listing services again.
    services="$(api_request GET "/projects/${PROJECT_ID}/services/combined")"
    SERVICE_ID="$(printf "%s" "${services}" | jq -r --arg name "${SERVICE_NAME}" '.data.services[]? | select(.name == $name) | .id' | head -n1)"
  fi

  echo "Service created (${SERVICE_ID})."
}

trigger_build() {
  echo "Triggering a build for ${SERVICE_NAME}..."
  api_request POST "/projects/${PROJECT_ID}/services/${SERVICE_ID}/build" "{}" >/dev/null || true
  echo "Build triggered."
}

maybe_assign_domain() {
  local domain_details
  domain_details="$(api_request GET "/domains/${DOMAIN}")"
  local status
  status="$(printf "%s" "${domain_details}" | jq -r '.data.status')"
  if [[ "${status}" != "verified" ]]; then
    echo "Domain ${DOMAIN} is not verified yet; skipping domain assignment."
    return 0
  fi

  echo "Ensuring subdomain ${SUBDOMAIN}.${DOMAIN} exists..."
  local sub_payload
  sub_payload="$(jq -n --arg subdomain "${SUBDOMAIN}" '{subdomain: $subdomain}')"
  api_request POST "/domains/${DOMAIN}/subdomains" "${sub_payload}" >/dev/null || true

  local subdomain_path
  subdomain_path="$(python3 -c 'import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1], safe=""))' "${SUBDOMAIN}")"

  echo "Assigning ${SUBDOMAIN}.${DOMAIN} to ${SERVICE_NAME} (port http)..."
  local assign_payload
  assign_payload="$(jq -n \
    --arg project_id "${PROJECT_ID}" \
    --arg service_id "${SERVICE_ID}" \
    --arg port_name "http" \
    '{projectId: $project_id, serviceId: $service_id, portName: $port_name}')"
  api_request POST "/domains/${DOMAIN}/subdomains/${subdomain_path}/assign" "${assign_payload}" >/dev/null
  echo "Domain assignment complete."
}

main() {
  ensure_project
  ensure_domain
  ensure_addon
  resolve_database_url
  ensure_service
  trigger_build
  maybe_assign_domain
  echo "Done. Next: run migrations with a Northflank job or command override."
}

main "$@"
