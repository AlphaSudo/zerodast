#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORTS_DIR="${REPORTS_DIR:-${ROOT_DIR}/reports}"
APP_IMAGE="${APP_IMAGE:-zerodast-demo-app:local}"
ZAP_CONFIG_PATH="${ZAP_CONFIG_PATH:-${ROOT_DIR}/security/zap/automation.yaml}"
ENGINE_BIN="${CONTAINER_ENGINE_BIN:-docker}"
HOOK_FILE="$(mktemp)"

if [[ "${FAST_AUTH_SMOKE:-false}" == "true" ]]; then
  exec bash "$ROOT_DIR/scripts/run-auth-adapter-smoke.sh"
fi

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

cleanup() {
  rm -f "$HOOK_FILE"
  engine rm -f dast-zap untrusted-app dast-db >/dev/null 2>&1 || true
  engine network rm dast-net >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkdir -p "$REPORTS_DIR"
HOST_BUILD_CONTEXT="$(host_path "$ROOT_DIR/demo-app")"

cat > "$HOOK_FILE" <<EOF
#!/usr/bin/env bash
set -euo pipefail
bash "$ROOT_DIR/scripts/verify-admin-coverage.sh" "$REPORTS_DIR/zap-report.json"
bash "$ROOT_DIR/scripts/verify-canaries.sh" "$REPORTS_DIR/zap-report.json"
EOF
chmod +x "$HOOK_FILE"

echo "[1/5] Building demo app image with $ENGINE_BIN"
engine build -t "$APP_IMAGE" "$HOST_BUILD_CONTEXT"

echo "[2/5] Running isolated DAST environment"
CONTAINER_ENGINE_BIN="$ENGINE_BIN" \
SCHEMA_SQL="$ROOT_DIR/db/seed/schema.sql" \
MOCK_DATA_SQL="$ROOT_DIR/db/seed/mock_data.sql" \
ZAP_CONFIG_PATH="$ZAP_CONFIG_PATH" \
AUTH_BOOTSTRAP_MODE="adapter" \
AUTH_ADAPTER_SCRIPT="$ROOT_DIR/scripts/auth-adapters/json-token-login.sh" \
AUTH_TOKEN_PATH="/tmp/zap-auth-token.txt" \
ADMIN_AUTH_TOKEN_PATH="/tmp/zap-auth-token-admin.txt" \
POST_SCAN_SCRIPT="$HOOK_FILE" \
REPORTS_DIR="$REPORTS_DIR" \
APP_IMAGE="$APP_IMAGE" \
bash "$ROOT_DIR/security/run-dast-env.sh" "$APP_IMAGE"

echo "[3/5] Parsing report summary"
NODE_BIN=""
if command -v node >/dev/null 2>&1; then
  NODE_BIN="node"
elif [[ -x "${NODE_PATH:-}" ]]; then
  NODE_BIN="$NODE_PATH"
elif [[ -x "C:/Users/CM/AppData/Roaming/fnm/node-versions/v22.15.0/installation/node.exe" ]]; then
  NODE_BIN="C:/Users/CM/AppData/Roaming/fnm/node-versions/v22.15.0/installation/node.exe"
fi

if [[ -n "$NODE_BIN" ]]; then
  REPORT_PATH="$REPORTS_DIR/zap-report.json"
  if [[ "$NODE_BIN" == *.exe ]] && command -v cygpath >/dev/null 2>&1; then
    REPORT_PATH="$(cygpath -w "$REPORT_PATH")"
  fi
  "$NODE_BIN" "$ROOT_DIR/scripts/parse-zap-report.js" "$REPORT_PATH" || true
else
  echo "Warning: node not found, skipping report parsing" >&2
fi

echo "[4/5] Reports written to $REPORTS_DIR"

echo "[5/5] Local DAST run complete"
