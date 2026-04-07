#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
CONFIG_PATH="${ROOT_DIR}/config.json"
REPORT_DIR="${ROOT_DIR}/reports"
MODE="${ZERODAST_MODE:-pr}"
DOCKER_CMD="${ZERODAST_DOCKER_CMD:-docker}"
HELPER_SCRIPT='fetch(process.argv[1]).then(async r => { if (!r.ok) process.exit(1); process.stdout.write(await r.text()); }).catch((err) => { console.error(err.message); process.exit(1); });'
DOCKER_REQUIRES_WINDOWS_PATHS="false"

if [[ "${DOCKER_CMD}" == *.exe ]] && command -v cygpath >/dev/null 2>&1; then
  DOCKER_REQUIRES_WINDOWS_PATHS="true"
fi

mkdir -p "${REPORT_DIR}"
find "${REPORT_DIR}" -maxdepth 1 -type f -delete

PREPARED_CONFIG="${REPORT_DIR}/prepared-config.json"
RAW_SPEC="${REPORT_DIR}/openapi-raw.json"
SANITIZED_SPEC="${REPORT_DIR}/openapi-sanitized.json"
REQUESTS_JSON="${REPORT_DIR}/request-urls.json"
AUTOMATION_PATH="${REPORT_DIR}/automation.yaml"
REPORT_PATH="${REPORT_DIR}/zap-report.json"
LOG_PATH="${REPORT_DIR}/zap-run.log"
METRICS_PATH="${REPORT_DIR}/metrics.json"
SUMMARY_PATH="${REPORT_DIR}/summary.md"

TARGET_WORK_DIR="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(c.target.workingDirectory || '.');" "${CONFIG_PATH}")"
TARGET_PORT="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(String(c.target.port || 80));" "${CONFIG_PATH}")"
TARGET_HEALTH_PATH="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(c.target.healthPath || '/');" "${CONFIG_PATH}")"
TARGET_OPENAPI_PATH="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(c.target.openApiPath || '/');" "${CONFIG_PATH}")"
TARGET_BUILD_COMMAND="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(c.target.buildCommand || '');" "${CONFIG_PATH}")"
TARGET_ARTIFACT_PATTERN="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(c.target.artifactPattern || '');" "${CONFIG_PATH}")"
APP_IMAGE="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(c.target.appImage || 'eclipse-temurin:17-jre-jammy');" "${CONFIG_PATH}")"
ZAP_VERSION="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(c.scan?.zapVersion || '2.17.0');" "${CONFIG_PATH}")"
HELPER_IMAGE="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(c.scan?.helperImage || 'node:20-alpine');" "${CONFIG_PATH}")"

TARGET_DIR="$(cd "${REPO_ROOT}/${TARGET_WORK_DIR}" && pwd)"
APP_CONTAINER="zerodast-target"
ZAP_CONTAINER="zerodast-zap"
NETWORK_NAME="zerodast-net"
SCANNER_BASE_ROOT="http://${APP_CONTAINER}:${TARGET_PORT}"

if [[ -z "${TARGET_BUILD_COMMAND}" || -z "${TARGET_ARTIFACT_PATTERN}" ]]; then
  echo "config.json must define target.buildCommand and target.artifactPattern" >&2
  exit 1
fi

cleanup() {
  MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" rm -f "${ZAP_CONTAINER}" "${APP_CONTAINER}" >/dev/null 2>&1 || true
  MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" network rm "${NETWORK_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

(cd "${TARGET_DIR}" && eval "${TARGET_BUILD_COMMAND}")

shopt -s nullglob
artifact_matches=( "${TARGET_DIR}"/${TARGET_ARTIFACT_PATTERN} )
shopt -u nullglob

APP_JAR=""
for candidate in "${artifact_matches[@]}"; do
  if [[ "${candidate}" != *.original ]]; then
    APP_JAR="${candidate}"
    break
  fi
done

if [[ ! -f "${APP_JAR}" ]]; then
  echo "Expected build artifact not found for pattern: ${TARGET_ARTIFACT_PATTERN}" >&2
  exit 1
fi

APP_JAR_MOUNT="${APP_JAR}"
RAW_SPEC_MOUNT="${RAW_SPEC}"
SANITIZED_SPEC_MOUNT="${SANITIZED_SPEC}"
AUTOMATION_MOUNT="${AUTOMATION_PATH}"
REPORT_DIR_MOUNT="${REPORT_DIR}"

if [[ "${DOCKER_REQUIRES_WINDOWS_PATHS}" == "true" ]]; then
  APP_JAR_MOUNT="$(cygpath -w "${APP_JAR}")"
  RAW_SPEC_MOUNT="$(cygpath -w "${RAW_SPEC}")"
  SANITIZED_SPEC_MOUNT="$(cygpath -w "${SANITIZED_SPEC}")"
  AUTOMATION_MOUNT="$(cygpath -w "${AUTOMATION_PATH}")"
  REPORT_DIR_MOUNT="$(cygpath -w "${REPORT_DIR}")"
fi

MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" network create --internal "${NETWORK_NAME}" >/dev/null

MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" run -d --rm \
  --network "${NETWORK_NAME}" \
  --name "${APP_CONTAINER}" \
  -v "${APP_JAR_MOUNT}:/app/app.jar:ro" \
  "${APP_IMAGE}" \
  java -jar /app/app.jar >/dev/null

wait_for_health() {
  local attempts="${1:-45}"
  for ((i=0; i<attempts; i++)); do
    if MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "${HELPER_SCRIPT}" "${SCANNER_BASE_ROOT}${TARGET_HEALTH_PATH}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

if ! wait_for_health 60; then
  echo "Timed out waiting for target health endpoint at ${SCANNER_BASE_ROOT}${TARGET_HEALTH_PATH}" >&2
  exit 1
fi

MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "${HELPER_SCRIPT}" "${SCANNER_BASE_ROOT}${TARGET_OPENAPI_PATH}" > "${RAW_SPEC}"

node "${ROOT_DIR}/prepare-openapi.js" "${CONFIG_PATH}" "${MODE}" "${RAW_SPEC}" "${SANITIZED_SPEC}" "${REQUESTS_JSON}" > "${PREPARED_CONFIG}"

SCANNER_BASE_URL="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(c.scannerBaseUrl);" "${PREPARED_CONFIG}")"
SPIDER_MINUTES="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(String(c.modeConfig.spiderMinutes || 2));" "${PREPARED_CONFIG}")"
SCAN_MINUTES="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(String(c.modeConfig.maxDurationMinutes || 15));" "${PREPARED_CONFIG}")"
THREAD_PER_HOST="$(node -e "const fs=require('fs'); const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); process.stdout.write(String(c.modeConfig.threadPerHost || 4));" "${PREPARED_CONFIG}")"
ZAP_IMAGE="zaproxy/zap-stable:${ZAP_VERSION}"
SPEC_MODE="raw"

write_config() {
  local api_url="$1"
  {
    cat <<EOF
env:
  contexts:
    - name: "zerodast-model1"
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
      context: "zerodast-model1"
  - type: requestor
    requests:
EOF
    node -e "const fs=require('fs'); const requests=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); for (const url of requests) { console.log('      - url: \"' + url + '\"'); console.log('        method: \"GET\"'); }" "${REQUESTS_JSON}"
    cat <<EOF
  - type: spider
    parameters:
      context: "zerodast-model1"
      url: "${SCANNER_BASE_URL}/swagger-ui/index.html"
      maxDuration: ${SPIDER_MINUTES}
      maxDepth: 5
      maxChildren: 50
  - type: passiveScan-wait
    parameters:
      maxDuration: 2
  - type: activeScan
    parameters:
      context: "zerodast-model1"
      maxRuleDurationInMins: 5
      maxScanDurationInMins: ${SCAN_MINUTES}
      threadPerHost: ${THREAD_PER_HOST}
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
  } > "${AUTOMATION_PATH}"
}

run_zap() {
  MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" rm -f "${ZAP_CONTAINER}" >/dev/null 2>&1 || true
  MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" run --rm --name "${ZAP_CONTAINER}" \
    --network "${NETWORK_NAME}" \
    -v "${AUTOMATION_MOUNT}:/zap/wrk/config.yaml:Z" \
    -v "${RAW_SPEC_MOUNT}:/zap/wrk/openapi-raw.json:Z" \
    -v "${SANITIZED_SPEC_MOUNT}:/zap/wrk/openapi-sanitized.json:Z" \
    -v "${REPORT_DIR_MOUNT}:/zap/wrk:Z" \
    "${ZAP_IMAGE}" zap.sh -cmd -autorun /zap/wrk/config.yaml
}

SECONDS=0
write_config "file:///zap/wrk/openapi-raw.json"
set +e
run_zap > "${LOG_PATH}" 2>&1
zap_exit=$?
set -e

if [[ ! -f "${REPORT_PATH}" ]] || grep -Eq 'Failed to import OpenAPI definition|OpenAPI' "${LOG_PATH}"; then
  SPEC_MODE="sanitized"
  write_config "file:///zap/wrk/openapi-sanitized.json"
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
  "seededRequestCount": ${seeded_count}
}
EOF

node "${ROOT_DIR}/verify-report.js" "${REPORT_PATH}" "${METRICS_PATH}" "${PREPARED_CONFIG}" | tee "${SUMMARY_PATH}"
