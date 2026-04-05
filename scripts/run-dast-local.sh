#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORTS_DIR="${REPORTS_DIR:-${ROOT_DIR}/reports}"
APP_IMAGE="${APP_IMAGE:-zerodast-demo-app:local}"
ZAP_CONFIG_PATH="${ZAP_CONFIG_PATH:-${ROOT_DIR}/security/zap/automation.yaml}"
HOOK_FILE="$(mktemp)"

cleanup() {
  rm -f "$HOOK_FILE"
  docker rm -f dast-zap untrusted-app dast-db >/dev/null 2>&1 || true
  docker network rm dast-net >/dev/null 2>&1 || true
}
trap cleanup EXIT

mkdir -p "$REPORTS_DIR"

cat > "$HOOK_FILE" <<EOF
#!/usr/bin/env bash
set -euo pipefail
bash "$ROOT_DIR/scripts/authz-tests.sh" "\$APP_URL"
bash "$ROOT_DIR/scripts/verify-canaries.sh" "$REPORTS_DIR/zap-report.json"
EOF
chmod +x "$HOOK_FILE"

echo "[1/5] Building demo app image"
docker build -t "$APP_IMAGE" "$ROOT_DIR/demo-app"

echo "[2/5] Running isolated DAST environment"
SCHEMA_SQL="$ROOT_DIR/db/seed/schema.sql" \
MOCK_DATA_SQL="$ROOT_DIR/db/seed/mock_data.sql" \
ZAP_CONFIG_PATH="$ZAP_CONFIG_PATH" \
AUTH_BOOTSTRAP_SCRIPT="$ROOT_DIR/scripts/bootstrap-auth.sh" \
AUTH_BOOTSTRAP_URL="http://127.0.0.1:8080" \
AUTH_TOKEN_PATH="/tmp/zap-auth-token.txt" \
POST_SCAN_SCRIPT="$HOOK_FILE" \
REPORTS_DIR="$REPORTS_DIR" \
APP_IMAGE="$APP_IMAGE" \
bash "$ROOT_DIR/security/run-dast-env.sh" "$APP_IMAGE"

echo "[3/5] Parsing report summary"
"C:/Users/CM/AppData/Roaming/fnm/node-versions/v22.15.0/installation/node.exe" "$ROOT_DIR/scripts/parse-zap-report.js" "$REPORTS_DIR/zap-report.json" || true

echo "[4/5] Reports written to $REPORTS_DIR"

echo "[5/5] Local DAST run complete"
