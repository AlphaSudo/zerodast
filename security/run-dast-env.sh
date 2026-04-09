#!/usr/bin/env bash
set -euo pipefail

ENGINE_BIN="${CONTAINER_ENGINE_BIN:-docker}"
NETWORK_NAME="${NETWORK_NAME:-dast-net}"
DB_CONTAINER="${DB_CONTAINER:-dast-db}"
APP_CONTAINER="${APP_CONTAINER:-untrusted-app}"
ZAP_CONTAINER="${ZAP_CONTAINER:-dast-zap}"
DB_IMAGE="${DB_IMAGE:-postgres:16-alpine}"
ZAP_VERSION="${ZAP_VERSION:-2.17.0}"
APP_IMAGE="${1:-${APP_IMAGE:-zerodast-demo-app:local}}"
ZAP_CONFIG_PATH="${ZAP_CONFIG_PATH:-/tmp/zap-config.yaml}"
REPORTS_DIR="${REPORTS_DIR:-$(pwd)/reports}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
DATABASE_URL="${DATABASE_URL:-postgresql://testuser:throwaway_ci_test_pass@${DB_CONTAINER}:5432/testdb}"
JWT_SECRET="${JWT_SECRET:-zerodast-test-jwt-secret-not-for-production}"
SCHEMA_SQL="${SCHEMA_SQL:-}"
MOCK_DATA_SQL="${MOCK_DATA_SQL:-}"
OVERLAY_SQL="${OVERLAY_SQL:-}"
APP_HEALTH_PATH="${APP_HEALTH_PATH:-/health}"
APP_PORT_BIND="${APP_PORT_BIND:-127.0.0.1:8080:8080}"
AUTH_BOOTSTRAP_SCRIPT="${AUTH_BOOTSTRAP_SCRIPT:-}"
AUTH_BOOTSTRAP_URL="${AUTH_BOOTSTRAP_URL:-http://127.0.0.1:8080}"
AUTH_BOOTSTRAP_MODE="${AUTH_BOOTSTRAP_MODE:-script}"
AUTH_BOOTSTRAP_EMAIL="${AUTH_BOOTSTRAP_EMAIL:-alice@test.local}"
AUTH_BOOTSTRAP_PASSWORD="${AUTH_BOOTSTRAP_PASSWORD:-Test123!}"
ADMIN_AUTH_BOOTSTRAP_EMAIL="${ADMIN_AUTH_BOOTSTRAP_EMAIL:-admin@test.local}"
ADMIN_AUTH_BOOTSTRAP_PASSWORD="${ADMIN_AUTH_BOOTSTRAP_PASSWORD:-Test123!}"
AUTH_TOKEN_PATH="${AUTH_TOKEN_PATH:-/tmp/zap-auth-token.txt}"
ADMIN_AUTH_TOKEN_PATH="${ADMIN_AUTH_TOKEN_PATH:-/tmp/zap-auth-token-admin.txt}"
POST_SCAN_SCRIPT="${POST_SCAN_SCRIPT:-}"
POST_SCAN_APP_URL="${POST_SCAN_APP_URL:-$AUTH_BOOTSTRAP_URL}"
RUN_AUTHZ_NETWORK="${RUN_AUTHZ_NETWORK:-false}"
AUTHZ_SCRIPT_PATH="${AUTHZ_SCRIPT_PATH:-scripts/authz-tests.js}"
EXPECT_IDOR="${EXPECT_IDOR:-true}"
DB_WAIT_ATTEMPTS="${DB_WAIT_ATTEMPTS:-30}"
APP_WAIT_ATTEMPTS="${APP_WAIT_ATTEMPTS:-30}"
ZAP_EXIT=0

engine() {
  if [[ "$ENGINE_BIN" == *.exe ]]; then
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" "$ENGINE_BIN" "$@"
  else
    "$ENGINE_BIN" "$@"
  fi
}

host_path() {
  local path="$1"
  if [[ "$ENGINE_BIN" == *.exe ]] && command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$path"
  else
    printf '%s\n' "$path"
  fi
}

next_delay() {
  awk -v value="$1" 'BEGIN { value = value * 1.5; if (value > 3) value = 3; printf "%.3f", value }'
}

bootstrap_auth_token_inside_app() {
  local email="$1"
  local password="$2"

  engine exec \
    -e BOOTSTRAP_EMAIL="$email" \
    -e BOOTSTRAP_PASSWORD="$password" \
    "$APP_CONTAINER" \
    node -e "fetch('http://127.0.0.1:8080/api/auth/login', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ email: process.env.BOOTSTRAP_EMAIL, password: process.env.BOOTSTRAP_PASSWORD }) }).then(async (response) => { const body = await response.text(); if (!response.ok) { console.error(body); process.exit(1); } const parsed = JSON.parse(body); if (!parsed.token) { console.error(body); process.exit(1); } process.stdout.write(parsed.token); }).catch((error) => { console.error(error.stack || error.message); process.exit(1); });"
}

validate_admin_route_inside_app() {
  local admin_token="$1"

  engine exec \
    -e ADMIN_TOKEN="$admin_token" \
    "$APP_CONTAINER" \
    node -e "fetch('http://127.0.0.1:8080/api/users', { headers: { Authorization: 'Bearer ' + process.env.ADMIN_TOKEN } }).then(async (response) => { const body = await response.text(); if (response.status !== 200) { console.error(body); process.exit(1); } process.stdout.write(String(response.status)); }).catch((error) => { console.error(error.stack || error.message); process.exit(1); });" >/dev/null
}

cleanup() {
  engine rm -f "$ZAP_CONTAINER" "$APP_CONTAINER" "$DB_CONTAINER" >/dev/null 2>&1 || true
  engine network rm "$NETWORK_NAME" >/dev/null 2>&1 || true
  rm -f /tmp/zap-runtime-config.yaml 2>/dev/null || true
}
trap cleanup EXIT

wait_for_db() {
  local attempt delay=0.2
  for attempt in $(seq 1 "$DB_WAIT_ATTEMPTS"); do
    if engine exec "$DB_CONTAINER" pg_isready -U testuser -d testdb >/dev/null 2>&1; then
      return 0
    fi
    sleep "$delay"
    delay="$(next_delay "$delay")"
  done
  echo "Database did not become ready in time" >&2
  return 1
}

seed_sql_file() {
  local sql_file="$1"
  if [[ -n "$sql_file" && -f "$sql_file" ]]; then
    engine exec -i "$DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U testuser -d testdb < "$sql_file"
  fi
}

wait_for_app() {
  local attempt delay=0.2
  for attempt in $(seq 1 "$APP_WAIT_ATTEMPTS"); do
    if engine exec "$APP_CONTAINER" wget -qO- "http://127.0.0.1:8080${APP_HEALTH_PATH}" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$delay"
    delay="$(next_delay "$delay")"
  done
  echo "Application did not become healthy in time" >&2
  return 1
}

HOST_ZAP_CONFIG_PATH="$(host_path "$ZAP_CONFIG_PATH")"
HOST_REPORTS_DIR="$(host_path "$REPORTS_DIR")"

mkdir -p "$REPORTS_DIR"
chmod 0777 "$REPORTS_DIR" >/dev/null 2>&1 || true

engine network create --internal "$NETWORK_NAME" >/dev/null 2>&1 || true

engine run -d --rm \
  --network "$NETWORK_NAME" \
  --name "$DB_CONTAINER" \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_PASSWORD=throwaway_ci_test_pass \
  "$DB_IMAGE" >/dev/null

echo "Started database container: $DB_CONTAINER"
wait_for_db
seed_sql_file "$SCHEMA_SQL"
seed_sql_file "$MOCK_DATA_SQL"
seed_sql_file "$OVERLAY_SQL"

engine run -d --rm \
  --network "$NETWORK_NAME" \
  --name "$APP_CONTAINER" \
  -p "$APP_PORT_BIND" \
  --cap-drop=ALL \
  --security-opt=no-new-privileges:true \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=100m \
  --user 1000:1000 \
  --memory=1g \
  --memory-swap=1g \
  --pids-limit=512 \
  -e DATABASE_URL="$DATABASE_URL" \
  -e JWT_SECRET="$JWT_SECRET" \
  "$APP_IMAGE" >/dev/null

echo "Started hardened app container: $APP_CONTAINER"
wait_for_app

if [[ "$AUTH_BOOTSTRAP_MODE" == "app_container" ]]; then
  AUTH_TOKEN="$(bootstrap_auth_token_inside_app "$AUTH_BOOTSTRAP_EMAIL" "$AUTH_BOOTSTRAP_PASSWORD")"
  ADMIN_AUTH_TOKEN="$(bootstrap_auth_token_inside_app "$ADMIN_AUTH_BOOTSTRAP_EMAIL" "$ADMIN_AUTH_BOOTSTRAP_PASSWORD")"
  printf '%s' "$AUTH_TOKEN" > "$AUTH_TOKEN_PATH"
  printf '%s' "$ADMIN_AUTH_TOKEN" > "$ADMIN_AUTH_TOKEN_PATH"
elif [[ -n "$AUTH_BOOTSTRAP_SCRIPT" ]]; then
  APP_URL="$AUTH_BOOTSTRAP_URL" bash "$AUTH_BOOTSTRAP_SCRIPT" "$AUTH_BOOTSTRAP_URL"
  if [[ -f "$AUTH_TOKEN_PATH" ]]; then
    AUTH_TOKEN=$(cat "$AUTH_TOKEN_PATH")
  fi
  if [[ -f "$ADMIN_AUTH_TOKEN_PATH" ]]; then
    ADMIN_AUTH_TOKEN=$(cat "$ADMIN_AUTH_TOKEN_PATH")
  fi
fi

if [[ -n "${ADMIN_AUTH_TOKEN:-}" ]]; then
  validate_admin_route_inside_app "$ADMIN_AUTH_TOKEN"
  echo "Admin bootstrap validated against /api/users"
else
  echo "WARNING: ADMIN_AUTH_TOKEN is empty - admin-path coverage verification will likely fail" >&2
fi

if [[ ! -f "$ZAP_CONFIG_PATH" ]]; then
  echo "ZAP config not found: $ZAP_CONFIG_PATH" >&2
  exit 1
fi

ZAP_RUNTIME_CONFIG="/tmp/zap-runtime-config.yaml"
if [[ -n "${AUTH_TOKEN:-}" || -n "${ADMIN_AUTH_TOKEN:-}" ]]; then
  echo "Auth tokens obtained, baking into ZAP config"
  sed \
    -e "s|\${AUTH_TOKEN}|${AUTH_TOKEN:-}|g" \
    -e "s|\${ADMIN_AUTH_TOKEN}|${ADMIN_AUTH_TOKEN:-}|g" \
    "$ZAP_CONFIG_PATH" > "$ZAP_RUNTIME_CONFIG"
else
  echo "WARNING: auth tokens are empty - authenticated endpoints will return 401/403" >&2
  cp "$ZAP_CONFIG_PATH" "$ZAP_RUNTIME_CONFIG"
fi
HOST_ZAP_RUNTIME_PATH="$(host_path "$ZAP_RUNTIME_CONFIG")"

engine run --rm \
  --network "$NETWORK_NAME" \
  --name "$ZAP_CONTAINER" \
  -e ZAP_JVM_OPTS="-Xmx3g -Xms1g" \
  -v "$HOST_ZAP_RUNTIME_PATH:/zap/wrk/config.yaml:ro" \
  -v "$HOST_REPORTS_DIR:/zap/wrk:rw" \
  "zaproxy/zap-stable:${ZAP_VERSION}" \
  zap.sh -cmd -autorun /zap/wrk/config.yaml \
  -config check.onstart=false \
  -config api.disablekey=true \
  || ZAP_EXIT=$?

if [[ "${ZAP_EXIT:-0}" -gt 3 ]]; then
  echo "ZAP crashed with exit code $ZAP_EXIT" >&2
  exit 1
fi

echo "ZAP finished with exit code ${ZAP_EXIT:-0}"

if [[ "$RUN_AUTHZ_NETWORK" == "true" ]]; then
  if [[ -n "$MOCK_DATA_SQL" && -f "$MOCK_DATA_SQL" ]]; then
    seed_sql_file "$MOCK_DATA_SQL"
  fi
  HOST_WORKSPACE_DIR="$(host_path "$WORKSPACE_DIR")"
  engine run --rm \
    --network "$NETWORK_NAME" \
    -e EXPECT_IDOR="$EXPECT_IDOR" \
    -v "$HOST_WORKSPACE_DIR:/work:ro" \
    -w /work \
    node:20-alpine \
    node "$AUTHZ_SCRIPT_PATH" "http://$APP_CONTAINER:8080"
fi

if [[ -n "$POST_SCAN_SCRIPT" ]]; then
  APP_URL="$POST_SCAN_APP_URL" bash "$POST_SCAN_SCRIPT"
fi
