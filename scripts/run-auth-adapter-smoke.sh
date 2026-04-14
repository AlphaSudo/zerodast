#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_IMAGE="${APP_IMAGE:-zerodast-demo-app:local}"
ENGINE_BIN="${CONTAINER_ENGINE_BIN:-docker}"
AUTH_ADAPTER_SCRIPT="${AUTH_ADAPTER_SCRIPT:-$ROOT_DIR/scripts/auth-adapters/json-token-login.sh}"

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
  elif [[ "$ENGINE_BIN" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$path"
  else
    printf '%s\n' "$path"
  fi
}

cleanup() {
  engine rm -f dast-zap untrusted-app dast-db >/dev/null 2>&1 || true
  engine network rm dast-net >/dev/null 2>&1 || true
}
trap cleanup EXIT

HOST_BUILD_CONTEXT="$(host_path "$ROOT_DIR/demo-app")"

echo "[1/3] Building demo app image with $ENGINE_BIN"
engine build -t "$APP_IMAGE" "$HOST_BUILD_CONTEXT"

echo "[2/3] Running auth-adapter smoke bootstrap"
CONTAINER_ENGINE_BIN="$ENGINE_BIN" \
SCHEMA_SQL="$ROOT_DIR/db/seed/schema.sql" \
MOCK_DATA_SQL="$ROOT_DIR/db/seed/mock_data.sql" \
ZAP_CONFIG_PATH="$ROOT_DIR/security/zap/automation.yaml" \
AUTH_BOOTSTRAP_MODE="adapter" \
AUTH_ADAPTER_SCRIPT="$AUTH_ADAPTER_SCRIPT" \
AUTH_TOKEN_PATH="/tmp/zap-auth-token.txt" \
ADMIN_AUTH_TOKEN_PATH="/tmp/zap-auth-token-admin.txt" \
SKIP_ZAP_RUN="true" \
APP_IMAGE="$APP_IMAGE" \
bash "$ROOT_DIR/security/run-dast-env.sh" "$APP_IMAGE"

echo "[3/3] Auth-adapter smoke completed"
