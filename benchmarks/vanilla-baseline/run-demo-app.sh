#!/usr/bin/env bash
# Vanilla ZAP baseline for the ZeroDAST demo app.
# Represents what a small team would do with stock ZAP Docker —
# no ZeroDAST orchestration, no operator artifacts, no trusted/untrusted split.
set -euo pipefail

ENGINE_BIN="${CONTAINER_ENGINE_BIN:-docker}"
ZAP_VERSION="${ZAP_VERSION:-2.17.0}"
ZAP_IMAGE="zaproxy/zap-stable:${ZAP_VERSION}"
DB_IMAGE="${DB_IMAGE:-postgres:16-alpine}"
NETWORK_NAME="vanilla-demo-net"
DB_CONTAINER="vanilla-demo-db"
APP_CONTAINER="vanilla-demo-app"
ZAP_CONTAINER="vanilla-demo-zap"
APP_IMAGE="${1:-${APP_IMAGE:-zerodast-demo-app:local}}"
REPORTS_DIR="${REPORTS_DIR:-$(pwd)/reports/vanilla-demo}"
APP_URL="http://${APP_CONTAINER}:8080"
DATABASE_URL="postgresql://testuser:throwaway_ci_test_pass@${DB_CONTAINER}:5432/testdb"
JWT_SECRET="zerodast-test-jwt-secret-not-for-production"

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

mkdir -p "${REPORTS_DIR}"
chmod 0777 "${REPORTS_DIR}" 2>/dev/null || true

cleanup() {
  engine rm -f "${ZAP_CONTAINER}" "${APP_CONTAINER}" "${DB_CONTAINER}" >/dev/null 2>&1 || true
  engine network rm "${NETWORK_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

SECONDS=0

engine network create "${NETWORK_NAME}" >/dev/null 2>&1 || true

engine run -d --rm \
  --network "${NETWORK_NAME}" \
  --name "${DB_CONTAINER}" \
  -e POSTGRES_DB=testdb \
  -e POSTGRES_USER=testuser \
  -e POSTGRES_PASSWORD=throwaway_ci_test_pass \
  "${DB_IMAGE}" >/dev/null

for i in $(seq 1 30); do
  if engine exec "${DB_CONTAINER}" sh -c "PGPASSWORD=throwaway_ci_test_pass psql -h 127.0.0.1 -U testuser -d testdb -c 'select 1' >/dev/null 2>&1"; then
    break
  fi
  sleep 1
done

engine run -d --rm \
  --network "${NETWORK_NAME}" \
  --name "${APP_CONTAINER}" \
  -e DATABASE_URL="${DATABASE_URL}" \
  -e JWT_SECRET="${JWT_SECRET}" \
  "${APP_IMAGE}" >/dev/null

for i in $(seq 1 30); do
  if engine exec "${APP_CONTAINER}" wget -qO- "http://127.0.0.1:8080/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# --- Auth bootstrap: manual curl-equivalent via helper container ---
REGISTER_BODY='{"email":"alice@test.local","password":"Test123!"}'
engine run --rm --network "${NETWORK_NAME}" node:20-alpine node -e "
  fetch('${APP_URL}/api/auth/register', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '${REGISTER_BODY}'
  }).then(r => r.text()).then(t => process.stdout.write(t)).catch(() => {});
" >/dev/null 2>&1 || true

LOGIN_BODY='{"email":"alice@test.local","password":"Test123!"}'
AUTH_TOKEN="$(engine run --rm --network "${NETWORK_NAME}" node:20-alpine node -e "
  fetch('${APP_URL}/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '${LOGIN_BODY}'
  }).then(async r => {
    const body = await r.json();
    process.stdout.write(body.token || '');
  }).catch(() => process.exit(1));
")"

if [[ -z "${AUTH_TOKEN}" ]]; then
  echo "WARNING: auth bootstrap failed; scan will be unauthenticated" >&2
fi

# --- Write minimal ZAP automation config ---
CONFIG_PATH="${REPORTS_DIR}/automation.yaml"
AUTH_HEADER="Bearer ${AUTH_TOKEN}"
cat > "${CONFIG_PATH}" <<YAML
env:
  contexts:
    - name: "vanilla-demo"
      urls:
        - "${APP_URL}"
      includePaths:
        - "${APP_URL}.*"
  parameters:
    failOnError: true
    progressToStdout: true
jobs:
  - type: replacer
    parameters:
      deleteAllRules: true
    rules:
      - description: "Auth token"
        matchType: "REQ_HEADER"
        matchString: "Authorization"
        replacementString: "${AUTH_HEADER}"
  - type: openapi
    parameters:
      apiUrl: "${APP_URL}/v3/api-docs"
      targetUrl: "${APP_URL}"
      context: "vanilla-demo"
  - type: spider
    parameters:
      context: "vanilla-demo"
      url: "${APP_URL}"
      maxDuration: 2
      maxDepth: 5
      maxChildren: 10
  - type: passiveScan-wait
    parameters:
      maxDuration: 2
  - type: activeScan
    parameters:
      context: "vanilla-demo"
      maxRuleDurationInMins: 5
      maxScanDurationInMins: 30
      threadPerHost: 4
      delayInMs: 50
    policyDefinition:
      defaultStrength: medium
      defaultThreshold: low
  - type: report
    parameters:
      template: "traditional-json"
      reportDir: "/zap/wrk"
      reportFile: "zap-report.json"
  - type: report
    parameters:
      template: "traditional-html"
      reportDir: "/zap/wrk"
      reportFile: "zap-report.html"
YAML

# --- Run ZAP ---
LOG_PATH="${REPORTS_DIR}/zap-run.log"
HOST_CONFIG="$(host_path "${CONFIG_PATH}")"
HOST_REPORTS="$(host_path "${REPORTS_DIR}")"
set +e
engine run --rm \
  --network "${NETWORK_NAME}" \
  --name "${ZAP_CONTAINER}" \
  -v "${HOST_CONFIG}:/zap/wrk/config.yaml:ro" \
  -v "${HOST_REPORTS}:/zap/wrk:rw" \
  "${ZAP_IMAGE}" \
  zap.sh -cmd -autorun /zap/wrk/config.yaml \
  2>&1 | tee "${LOG_PATH}"
ZAP_EXIT=$?
set -e

TOTAL_SECONDS="${SECONDS}"

# --- Capture baseline metrics ---
ALERT_COUNT=0
API_ALERT_URI_COUNT=0
if [[ -f "${REPORTS_DIR}/zap-report.json" ]]; then
  ALERT_COUNT="$(node -e "
    const fs = require('fs');
    const report = JSON.parse(fs.readFileSync('${REPORTS_DIR}/zap-report.json', 'utf8'));
    let count = 0;
    for (const site of report.site || []) {
      for (const alert of site.alerts || []) {
        count++;
      }
    }
    console.log(count);
  " 2>/dev/null || echo 0)"
  API_ALERT_URI_COUNT="$(node -e "
    const fs = require('fs');
    const report = JSON.parse(fs.readFileSync('${REPORTS_DIR}/zap-report.json', 'utf8'));
    const uris = new Set();
    for (const site of report.site || []) {
      for (const alert of site.alerts || []) {
        for (const instance of alert.instances || []) {
          if (instance.uri && instance.uri.includes('/api/')) uris.add(instance.uri.split('?')[0]);
        }
      }
    }
    console.log(uris.size);
  " 2>/dev/null || echo 0)"
fi

cat > "${REPORTS_DIR}/baseline-result.json" <<JSON
{
  "target": "zerodast-demo-app",
  "baseline": "vanilla-zap",
  "zapVersion": "${ZAP_VERSION}",
  "zapExitCode": ${ZAP_EXIT},
  "totalSeconds": ${TOTAL_SECONDS},
  "authenticated": $([ -n "${AUTH_TOKEN}" ] && echo true || echo false),
  "alertCount": ${ALERT_COUNT},
  "apiAlertUriCount": ${API_ALERT_URI_COUNT},
  "networkIsolation": false,
  "trustedUntrustedSplit": false,
  "containerHardening": false,
  "operatorArtifacts": false,
  "baselineComparison": false,
  "deltaScoping": false,
  "postScanVerification": false,
  "authzRegression": false
}
JSON

echo ""
echo "=== Vanilla ZAP Baseline Result ==="
echo "Target:            zerodast-demo-app"
echo "Total seconds:     ${TOTAL_SECONDS}"
echo "ZAP exit:          ${ZAP_EXIT}"
echo "Authenticated:     $([ -n "${AUTH_TOKEN}" ] && echo yes || echo no)"
echo "Alert count:       ${ALERT_COUNT}"
echo "API alert URIs:    ${API_ALERT_URI_COUNT}"
echo "==================================="
