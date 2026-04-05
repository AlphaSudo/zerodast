#!/usr/bin/env bash
set -euo pipefail

NETWORK_NAME="${NETWORK_NAME:-dast-net}"
DB_CONTAINER="${DB_CONTAINER:-dast-db}"
APP_CONTAINER="${APP_CONTAINER:-untrusted-app}"
ZAP_CONTAINER="${ZAP_CONTAINER:-dast-zap}"
DB_IMAGE="${DB_IMAGE:-postgres:16-alpine}"
ZAP_VERSION="${ZAP_VERSION:-2.16.0}"
APP_IMAGE="${1:-${APP_IMAGE:-zerodast-demo-app:local}}"
ZAP_CONFIG_PATH="${ZAP_CONFIG_PATH:-/tmp/zap-config.yaml}"
REPORTS_DIR="${REPORTS_DIR:-$(pwd)/reports}"
DATABASE_URL="${DATABASE_URL:-postgresql://testuser:throwaway_ci_test_pass@${DB_CONTAINER}:5432/testdb}"
JWT_SECRET="${JWT_SECRET:-zerodast-test-jwt-secret-not-for-production}"
ZAP_EXIT=0

cleanup() {
  docker rm -f "$ZAP_CONTAINER" "$APP_CONTAINER" "$DB_CONTAINER" >/dev/null 2>&1 || true
  docker network rm "$NETWORK_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkdir -p "$REPORTS_DIR"

docker network create --internal "$NETWORK_NAME" >/dev/null 2>&1 || true

docker run -d --rm \
  --network "$NETWORK_NAME" \
  --name "$DB_CONTAINER" \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_PASSWORD=throwaway_ci_test_pass \
  "$DB_IMAGE" >/dev/null

echo "Started database container: $DB_CONTAINER"

docker run -d --rm \
  --network "$NETWORK_NAME" \
  --name "$APP_CONTAINER" \
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

if [[ ! -f "$ZAP_CONFIG_PATH" ]]; then
  echo "ZAP config not found: $ZAP_CONFIG_PATH" >&2
  exit 1
fi

docker run --rm \
  --network "$NETWORK_NAME" \
  --name "$ZAP_CONTAINER" \
  -e ZAP_JVM_OPTS="-Xmx3g -Xms1g" \
  -e AUTH_TOKEN="${AUTH_TOKEN:-}" \
  -v "$ZAP_CONFIG_PATH:/zap/wrk/config.yaml:ro" \
  -v "$REPORTS_DIR:/zap/wrk:rw" \
  "zaproxy/zaproxy:${ZAP_VERSION}" \
  zap.sh -cmd -autorun /zap/wrk/config.yaml \
  -config check.onstart=false \
  -config api.disablekey=true \
  || ZAP_EXIT=$?

if [[ "${ZAP_EXIT:-0}" -gt 3 ]]; then
  echo "ZAP crashed with exit code $ZAP_EXIT" >&2
  exit 1
fi

echo "ZAP finished with exit code ${ZAP_EXIT:-0}"
