#!/usr/bin/env bash
# Vanilla ZAP baseline for fullstack-fastapi-template.
# Represents what a small team would do with stock ZAP Docker —
# stand up the target compose stack, grab a token, point ZAP at it.
set -euo pipefail

: "${TARGET_DIR:?TARGET_DIR is required (path to fullstack-fastapi-template clone)}"

ZAP_VERSION="${ZAP_VERSION:-2.17.0}"
ZAP_IMAGE="zaproxy/zap-stable:${ZAP_VERSION}"
HELPER_IMAGE="${HELPER_IMAGE:-node:20-alpine}"
COMPOSE_PROJECT_NAME="vanilla-fastapi"
NETWORK_NAME="${COMPOSE_PROJECT_NAME}_default"
REPORTS_DIR="${REPORTS_DIR:-$(pwd)/reports/vanilla-fastapi}"
BACKEND_URL="http://backend:8000"
API_BASE="${BACKEND_URL}/api/v1"
LOGIN_URL="${API_BASE}/login/access-token"
HEALTH_URL="${API_BASE}/utils/health-check/"
DOCS_URL="${BACKEND_URL}/docs"

mkdir -p "${REPORTS_DIR}"
chmod 0777 "${REPORTS_DIR}" 2>/dev/null || true

cleanup() {
  (cd "${TARGET_DIR}" && COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" docker compose down -v --remove-orphans >/dev/null 2>&1 || true)
  docker rm -f vanilla-fastapi-zap >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

SECONDS=0

mkdir -p "${TARGET_DIR}/backend/htmlcov"

(cd "${TARGET_DIR}" && COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" docker compose up -d db prestart backend)

for i in $(seq 1 80); do
  if docker run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e \
    "fetch(process.argv[1]).then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))" \
    "${HEALTH_URL}" >/dev/null 2>&1; then
    break
  fi
  sleep 3
done

# --- Auth bootstrap: manual login to get a bearer token ---
AUTH_TOKEN="$(docker run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "
  const body = new URLSearchParams({ username: 'admin@example.com', password: 'changethis' });
  fetch('${LOGIN_URL}', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body
  }).then(async r => {
    const j = await r.json();
    process.stdout.write(j.access_token || '');
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
    - name: "vanilla-fastapi"
      urls:
        - "${API_BASE}"
      includePaths:
        - "${API_BASE}.*"
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
      apiUrl: "${BACKEND_URL}/openapi.json"
      targetUrl: "${BACKEND_URL}"
      context: "vanilla-fastapi"
  - type: spider
    parameters:
      context: "vanilla-fastapi"
      url: "${DOCS_URL}"
      maxDuration: 2
      maxDepth: 5
      maxChildren: 20
  - type: passiveScan-wait
    parameters:
      maxDuration: 2
  - type: activeScan
    parameters:
      context: "vanilla-fastapi"
      maxRuleDurationInMins: 5
      maxScanDurationInMins: 12
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
set +e
docker run --rm \
  --network "${NETWORK_NAME}" \
  --name vanilla-fastapi-zap \
  -v "${CONFIG_PATH}:/zap/wrk/config.yaml:ro" \
  -v "${REPORTS_DIR}:/zap/wrk:rw" \
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
      for (const alert of site.alerts || []) { count++; }
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
  "target": "fullstack-fastapi-template",
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
echo "Target:            fullstack-fastapi-template"
echo "Total seconds:     ${TOTAL_SECONDS}"
echo "ZAP exit:          ${ZAP_EXIT}"
echo "Authenticated:     $([ -n "${AUTH_TOKEN}" ] && echo yes || echo no)"
echo "Alert count:       ${ALERT_COUNT}"
echo "API alert URIs:    ${API_ALERT_URI_COUNT}"
echo "==================================="
