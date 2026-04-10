#!/usr/bin/env bash
set -euo pipefail

: "${TARGET_DIR:?TARGET_DIR is required}"
: "${APP_JAR:?APP_JAR is required}"
: "${REPORTS_DIR:?REPORTS_DIR is required}"

ZAP_VERSION="${ZAP_VERSION:-2.17.0}"
ZAP_IMAGE="zaproxy/zap-stable:${ZAP_VERSION}"
HELPER_IMAGE="${HELPER_IMAGE:-node:20-alpine}"
APP_IMAGE="${APP_IMAGE:-eclipse-temurin:17-jre-jammy}"
NETWORK_NAME="${NETWORK_NAME:-petclinic-t4-net}"
APP_CONTAINER="${APP_CONTAINER:-petclinic-t4-app}"
ZAP_CONTAINER="${ZAP_CONTAINER:-petclinic-t4-zap}"
SCANNER_BASE_ROOT="http://${APP_CONTAINER}:9966"
SCANNER_BASE_PATH="/petclinic"
SCANNER_BASE_URL="${SCANNER_BASE_ROOT}${SCANNER_BASE_PATH}"
HEALTH_URL="${SCANNER_BASE_URL}/actuator/health"
API_DOCS_URL="${SCANNER_BASE_URL}/v3/api-docs"
WORK_DIR="${REPORTS_DIR}/petclinic-t4"
RAW_SPEC="${WORK_DIR}/petclinic-openapi-raw.json"
SANITIZED_SPEC="${WORK_DIR}/petclinic-openapi-sanitized.json"
REQUESTS_JSON="${WORK_DIR}/request-urls.json"
CONFIG_PATH="${WORK_DIR}/automation.yaml"
REPORT_PATH="${WORK_DIR}/zap-report.json"
LOG_PATH="${WORK_DIR}/zap-run.log"
METRICS_PATH="${WORK_DIR}/metrics.json"
VERIFY_PATH="${WORK_DIR}/verification.md"
API_INVENTORY_JSON="${WORK_DIR}/api-inventory.json"
API_INVENTORY_MD="${WORK_DIR}/api-inventory.md"
ROUTE_HINTS_JSON="${WORK_DIR}/route-hints.json"
SPEC_MODE="raw"

mkdir -p "${WORK_DIR}"
find "${WORK_DIR}" -maxdepth 1 -type f -delete
chmod 0777 "${WORK_DIR}"

cleanup() {
  docker rm -f "${ZAP_CONTAINER}" "${APP_CONTAINER}" >/dev/null 2>&1 || true
  docker network rm "${NETWORK_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

docker network create --internal "${NETWORK_NAME}" >/dev/null

docker run -d --rm \
  --network "${NETWORK_NAME}" \
  --name "${APP_CONTAINER}" \
  -v "${APP_JAR}:/app/petclinic.jar:ro" \
  "${APP_IMAGE}" \
  java -jar /app/petclinic.jar >/dev/null

wait_for_health() {
  local attempts="${1:-45}"
  for ((i=0; i<attempts; i++)); do
    if docker run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "fetch(process.argv[1]).then(async r => { if (!r.ok) process.exit(1); process.stdout.write(await r.text()); }).catch(() => process.exit(1));" "${HEALTH_URL}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

if ! wait_for_health 60; then
  echo "Timed out waiting for Petclinic health endpoint at ${HEALTH_URL}" >&2
  exit 1
fi

docker run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "fetch(process.argv[1]).then(async r => { if (!r.ok) process.exit(1); process.stdout.write(await r.text()); }).catch((err) => { console.error(err.message); process.exit(1); });" "${API_DOCS_URL}" > "${RAW_SPEC}"

node "${GITHUB_WORKSPACE}/benchmarks/petclinic/prepare-openapi.js" \
  "${RAW_SPEC}" \
  "${SANITIZED_SPEC}" \
  "${REQUESTS_JSON}" \
  "${SCANNER_BASE_ROOT}" \
  "${SCANNER_BASE_PATH}"

write_config() {
  local api_url="$1"
  {
    cat <<EOF
env:
  contexts:
    - name: "petclinic-t4"
      urls:
        - "${SCANNER_BASE_URL}"
      includePaths:
        - "${SCANNER_BASE_URL}.*"
  parameters:
    failOnError: true
    progressToStdout: true
jobs:
  - type: openapi
    parameters:
      apiUrl: "${api_url}"
      targetUrl: "${SCANNER_BASE_URL}"
      context: "petclinic-t4"
  - type: requestor
    requests:
EOF
    node -e "const fs=require('fs'); const requests=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); for (const url of requests) { console.log('      - url: \"' + url + '\"'); console.log('        method: \"GET\"'); }" "${REQUESTS_JSON}"
    cat <<EOF
  - type: spider
    parameters:
      context: "petclinic-t4"
      url: "${SCANNER_BASE_URL}/swagger-ui/index.html"
      maxDuration: 2
      maxDepth: 5
      maxChildren: 50
  - type: passiveScan-wait
    parameters:
      maxDuration: 2
  - type: activeScan
    parameters:
      context: "petclinic-t4"
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
EOF
  } > "${CONFIG_PATH}"
}

run_zap() {
  docker rm -f "${ZAP_CONTAINER}" >/dev/null 2>&1 || true
  docker run --rm --name "${ZAP_CONTAINER}" \
    --network "${NETWORK_NAME}" \
    -v "${CONFIG_PATH}:/zap/wrk/config.yaml:Z" \
    -v "${RAW_SPEC}:/zap/wrk/petclinic-openapi-raw.json:Z" \
    -v "${SANITIZED_SPEC}:/zap/wrk/petclinic-openapi-sanitized.json:Z" \
    -v "${WORK_DIR}:/zap/wrk:Z" \
    "${ZAP_IMAGE}" zap.sh -cmd -autorun /zap/wrk/config.yaml
}

SECONDS=0
write_config "file:///zap/wrk/petclinic-openapi-raw.json"
set +e
run_zap > "${LOG_PATH}" 2>&1
zap_exit=$?
set -e

if [[ ! -f "${REPORT_PATH}" ]] || grep -Eq 'Failed to import OpenAPI definition|OpenAPI' "${LOG_PATH}"; then
  SPEC_MODE="sanitized"
  write_config "file:///zap/wrk/petclinic-openapi-sanitized.json"
  set +e
  run_zap > "${LOG_PATH}" 2>&1
  zap_exit=$?
  set -e
fi

if [[ ! -f "${REPORT_PATH}" ]]; then
  echo "ZAP did not generate a report at ${REPORT_PATH}" >&2
  exit 1
fi

seeded_count=$(node -e "const fs=require('fs'); console.log(JSON.parse(fs.readFileSync(process.argv[1],'utf8')).length);" "${REQUESTS_JSON}")
cold_run_seconds="${SECONDS}"
cat > "${METRICS_PATH}" <<EOF
{
  "specMode": "${SPEC_MODE}",
  "zapImage": "${ZAP_IMAGE}",
  "zapExitCode": ${zap_exit},
  "coldRunSeconds": ${cold_run_seconds},
  "seededRequestCount": ${seeded_count},
  "apiInventoryJsonPath": "${API_INVENTORY_JSON}"
}
EOF

node "${GITHUB_WORKSPACE}/scripts/extract-route-hints.js" \
  --prefix "${SCANNER_BASE_PATH}/api" \
  "${TARGET_DIR}/target/generated-sources/openapi/src/main/java/org/springframework/samples/petclinic/rest/api" > "${ROUTE_HINTS_JSON}"

node "${GITHUB_WORKSPACE}/scripts/build-api-inventory.js" \
  "${REPORT_PATH}" \
  "${LOG_PATH}" \
  "${RAW_SPEC}" \
  "${API_INVENTORY_JSON}" \
  "${API_INVENTORY_MD}" \
  "${ROUTE_HINTS_JSON}" \
  "${SCANNER_BASE_PATH}"

node "${GITHUB_WORKSPACE}/benchmarks/petclinic/verify-t4.js" "${REPORT_PATH}" "${METRICS_PATH}" | tee "${VERIFY_PATH}"
