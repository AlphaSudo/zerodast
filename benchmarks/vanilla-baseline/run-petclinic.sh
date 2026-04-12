#!/usr/bin/env bash
# Vanilla ZAP baseline for spring-petclinic-rest.
# Represents the official zaproxy/action-api-scan approach — the thing a
# team would reach for before building any custom orchestration.
# Petclinic runs unauthenticated in default mode, so no auth bootstrap needed.
set -euo pipefail

: "${TARGET_DIR:?TARGET_DIR is required (path to spring-petclinic-rest clone)}"
: "${APP_JAR:?APP_JAR is required (path to the built petclinic jar)}"

ENGINE_BIN="${CONTAINER_ENGINE_BIN:-docker}"
ZAP_VERSION="${ZAP_VERSION:-2.17.0}"
ZAP_IMAGE="zaproxy/zap-stable:${ZAP_VERSION}"
APP_IMAGE="${APP_IMAGE:-eclipse-temurin:17-jre-jammy}"
HELPER_IMAGE="${HELPER_IMAGE:-node:20-alpine}"
NETWORK_NAME="vanilla-petclinic-net"
APP_CONTAINER="vanilla-petclinic-app"
ZAP_CONTAINER="vanilla-petclinic-zap"
REPORTS_DIR="${REPORTS_DIR:-$(pwd)/reports/vanilla-petclinic}"
BASE_URL="http://${APP_CONTAINER}:9966/petclinic"
HEALTH_URL="${BASE_URL}/actuator/health"
API_DOCS_URL="${BASE_URL}/v3/api-docs"

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
  engine rm -f "${ZAP_CONTAINER}" "${APP_CONTAINER}" >/dev/null 2>&1 || true
  engine network rm "${NETWORK_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

SECONDS=0

engine network create "${NETWORK_NAME}" >/dev/null 2>&1 || true

engine run -d --rm \
  --network "${NETWORK_NAME}" \
  --name "${APP_CONTAINER}" \
  -v "$(host_path "${APP_JAR}"):/app/petclinic.jar:ro" \
  "${APP_IMAGE}" \
  java -jar /app/petclinic.jar >/dev/null

for i in $(seq 1 60); do
  if engine run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e \
    "fetch(process.argv[1]).then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))" \
    "${HEALTH_URL}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# --- Fetch and store the OpenAPI spec ---
RAW_SPEC="${REPORTS_DIR}/petclinic-openapi.json"
engine run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e \
  "fetch(process.argv[1]).then(async r=>{if(!r.ok)process.exit(1);process.stdout.write(await r.text())}).catch(()=>process.exit(1))" \
  "${API_DOCS_URL}" > "${RAW_SPEC}"

# --- Write minimal ZAP automation config ---
CONFIG_PATH="${REPORTS_DIR}/automation.yaml"
cat > "${CONFIG_PATH}" <<YAML
env:
  contexts:
    - name: "vanilla-petclinic"
      urls:
        - "${BASE_URL}"
      includePaths:
        - "${BASE_URL}.*"
  parameters:
    failOnError: true
    progressToStdout: true
jobs:
  - type: openapi
    parameters:
      apiUrl: "file:///zap/wrk/petclinic-openapi.json"
      targetUrl: "${BASE_URL}"
      context: "vanilla-petclinic"
  - type: spider
    parameters:
      context: "vanilla-petclinic"
      url: "${BASE_URL}/swagger-ui/index.html"
      maxDuration: 2
      maxDepth: 5
      maxChildren: 50
  - type: passiveScan-wait
    parameters:
      maxDuration: 2
  - type: activeScan
    parameters:
      context: "vanilla-petclinic"
      maxRuleDurationInMins: 5
      maxScanDurationInMins: 15
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
HOST_SPEC="$(host_path "${RAW_SPEC}")"
HOST_REPORTS="$(host_path "${REPORTS_DIR}")"
set +e
engine run --rm \
  --network "${NETWORK_NAME}" \
  --name "${ZAP_CONTAINER}" \
  -v "${HOST_CONFIG}:/zap/wrk/config.yaml:ro" \
  -v "${HOST_SPEC}:/zap/wrk/petclinic-openapi.json:ro" \
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
  "target": "spring-petclinic-rest",
  "baseline": "vanilla-zap",
  "zapVersion": "${ZAP_VERSION}",
  "zapExitCode": ${ZAP_EXIT},
  "totalSeconds": ${TOTAL_SECONDS},
  "authenticated": false,
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
echo "Target:            spring-petclinic-rest"
echo "Total seconds:     ${TOTAL_SECONDS}"
echo "ZAP exit:          ${ZAP_EXIT}"
echo "Authenticated:     no (default unauthenticated mode)"
echo "Alert count:       ${ALERT_COUNT}"
echo "API alert URIs:    ${API_ALERT_URI_COUNT}"
echo "==================================="
