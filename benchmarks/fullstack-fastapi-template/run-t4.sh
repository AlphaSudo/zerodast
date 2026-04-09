#!/usr/bin/env bash
set -euo pipefail

: "${TARGET_DIR:?TARGET_DIR is required}"
: "${REPORTS_DIR:?REPORTS_DIR is required}"

ZAP_VERSION="${ZAP_VERSION:-2.17.0}"
ZAP_IMAGE="zaproxy/zap-stable:${ZAP_VERSION}"
HELPER_IMAGE="${HELPER_IMAGE:-node:20-alpine}"
NETWORK_NAME="${NETWORK_NAME:-fastapi-t4_default}"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-fastapi-t4}"
SCANNER_BASE_ROOT="http://backend:8000"
API_BASE_PATH="/api/v1"
API_BASE_URL="${SCANNER_BASE_ROOT}${API_BASE_PATH}"
HEALTH_URL="${API_BASE_URL}/utils/health-check/"
API_DOCS_URL="${API_BASE_URL}/openapi.json"
LOGIN_URL="${API_BASE_URL}/login/access-token"
PROTECTED_URL="${API_BASE_URL}/users/me"
ADMIN_ROUTE_URL="${API_BASE_URL}/users/?skip=0&limit=10"
DOCS_URL="${SCANNER_BASE_ROOT}/docs"
WORK_DIR="${REPORTS_DIR}/fullstack-fastapi-t4"
RAW_SPEC="${WORK_DIR}/fullstack-fastapi-openapi-raw.json"
SANITIZED_SPEC="${WORK_DIR}/fullstack-fastapi-openapi-sanitized.json"
REQUESTS_JSON="${WORK_DIR}/request-seeds.json"
TOKEN_JSON="${WORK_DIR}/token.json"
CONFIG_PATH="${WORK_DIR}/automation.yaml"
REPORT_PATH="${WORK_DIR}/zap-report.json"
LOG_PATH="${WORK_DIR}/zap-run.log"
METRICS_PATH="${WORK_DIR}/metrics.json"
VERIFY_PATH="${WORK_DIR}/verification.md"
SPEC_MODE="raw"

mkdir -p "${WORK_DIR}"
find "${WORK_DIR}" -maxdepth 1 -type f -delete
chmod 0777 "${WORK_DIR}"

cleanup() {
  (
    cd "${TARGET_DIR}"
    COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" docker compose down -v --remove-orphans >/dev/null 2>&1 || true
  )
  docker rm -f fastapi-t4-zap >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

mkdir -p "${TARGET_DIR}/backend/htmlcov"

(
  cd "${TARGET_DIR}"
  COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" docker compose up -d db prestart backend
)

wait_for_backend() {
  local attempts="${1:-60}"
  for ((i=0; i<attempts; i++)); do
    if docker run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "fetch(process.argv[1]).then(async r => { if (!r.ok) process.exit(1); process.stdout.write(await r.text()); }).catch(() => process.exit(1));" "${HEALTH_URL}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done
  return 1
}

if ! wait_for_backend 80; then
  echo "Timed out waiting for FastAPI backend health at ${HEALTH_URL}" >&2
  exit 1
fi

docker run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "fetch(process.argv[1]).then(async r => { if (!r.ok) process.exit(1); process.stdout.write(await r.text()); }).catch((err) => { console.error(err.message); process.exit(1); });" "${API_DOCS_URL}" > "${RAW_SPEC}"

AUTH_JSON="$({
  docker run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "
    const [url, user, pass] = process.argv.slice(1);
    const body = new URLSearchParams({ username: user, password: pass });
    fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body
    }).then(async (r) => {
      const text = await r.text();
      if (!r.ok) {
        console.error(text);
        process.exit(r.status || 1);
      }
      process.stdout.write(text);
    }).catch((err) => {
      console.error(err.message);
      process.exit(1);
    });
  " "${LOGIN_URL}" "admin@example.com" "changethis"
})"
printf '%s' "${AUTH_JSON}" > "${TOKEN_JSON}"

AUTH_TOKEN="$(node -e "const fs=require('fs'); const token=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); if (!token.access_token) process.exit(1); process.stdout.write(token.access_token);" "${TOKEN_JSON}")"

docker run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "
  const [url, token] = process.argv.slice(1);
  fetch(url, { headers: { Authorization: 'Bearer ' + token } }).then(async (r) => {
    if (!r.ok) {
      const text = await r.text();
      console.error(text);
      process.exit(r.status || 1);
    }
    process.stdout.write(String(r.status));
  }).catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
" "${PROTECTED_URL}" "${AUTH_TOKEN}" >/dev/null

docker run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "
  const [url, token] = process.argv.slice(1);
  fetch(url, { headers: { Authorization: 'Bearer ' + token } }).then(async (r) => {
    if (!r.ok) {
      const text = await r.text();
      console.error(text);
      process.exit(r.status || 1);
    }
    process.stdout.write(String(r.status));
  }).catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
" "${ADMIN_ROUTE_URL}" "${AUTH_TOKEN}" >/dev/null

node "${GITHUB_WORKSPACE}/benchmarks/fullstack-fastapi-template/prepare-openapi.js" \
  "${RAW_SPEC}" \
  "${SANITIZED_SPEC}" \
  "${REQUESTS_JSON}" \
  "${SCANNER_BASE_ROOT}" \
  "${API_BASE_PATH}"

write_config() {
  local api_url="$1"
  local auth_header="Bearer ${AUTH_TOKEN}"
  {
    cat <<EOF
env:
  contexts:
    - name: "fullstack-fastapi-t4"
      urls:
        - "${API_BASE_URL}"
      includePaths:
        - "${API_BASE_URL}.*"
  parameters:
    failOnError: true
    progressToStdout: true
jobs:
  - type: replacer
    parameters:
      deleteAllRules: true
    rules:
      - description: "Auth token injection"
        matchType: "REQ_HEADER"
        matchString: "Authorization"
        replacementString: "${auth_header}"
  - type: openapi
    parameters:
      apiUrl: "${api_url}"
      targetUrl: "${SCANNER_BASE_ROOT}"
      context: "fullstack-fastapi-t4"
EOF
    node -e "const fs=require('fs'); const requests=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); for (const request of requests) { console.log('  - type: requestor'); console.log('    parameters:'); console.log('      user: \"\"'); console.log('    requests:'); console.log('      - url: \"' + request.url + '\"'); console.log('        method: \"' + request.method + '\"'); }" "${REQUESTS_JSON}"
    cat <<EOF
  - type: spider
    parameters:
      context: "fullstack-fastapi-t4"
      url: "${DOCS_URL}"
      maxDuration: 2
      maxDepth: 5
      maxChildren: 20
  - type: passiveScan-wait
    parameters:
      maxDuration: 2
  - type: activeScan
    parameters:
      context: "fullstack-fastapi-t4"
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
EOF
  } > "${CONFIG_PATH}"
}

run_zap() {
  docker rm -f fastapi-t4-zap >/dev/null 2>&1 || true
  docker run --rm --name fastapi-t4-zap \
    --network "${NETWORK_NAME}" \
    -v "${CONFIG_PATH}:/zap/wrk/config.yaml:Z" \
    -v "${RAW_SPEC}:/zap/wrk/fullstack-fastapi-openapi-raw.json:Z" \
    -v "${SANITIZED_SPEC}:/zap/wrk/fullstack-fastapi-openapi-sanitized.json:Z" \
    -v "${WORK_DIR}:/zap/wrk:Z" \
    "${ZAP_IMAGE}" zap.sh -cmd -autorun /zap/wrk/config.yaml
}

SECONDS=0
write_config "file:///zap/wrk/fullstack-fastapi-openapi-raw.json"
set +e
run_zap > "${LOG_PATH}" 2>&1
zap_exit=$?
set -e

if [[ ! -f "${REPORT_PATH}" ]] || grep -Eq 'Failed to import OpenAPI definition|OpenAPI' "${LOG_PATH}"; then
  SPEC_MODE="sanitized"
  write_config "file:///zap/wrk/fullstack-fastapi-openapi-sanitized.json"
  set +e
  run_zap > "${LOG_PATH}" 2>&1
  zap_exit=$?
  set -e
fi

if [[ ! -f "${REPORT_PATH}" ]]; then
  echo "ZAP did not generate a report at ${REPORT_PATH}" >&2
  exit 1
fi

seeded_count="$(node -e "const fs=require('fs'); console.log(JSON.parse(fs.readFileSync(process.argv[1],'utf8')).length);" "${REQUESTS_JSON}")"
openapi_imported="$(grep -Eo 'Job openapi added [0-9]+ URLs' "${LOG_PATH}" | tail -n 1 | grep -Eo '[0-9]+' || echo 0)"
spider_found="$(grep -Eo 'Job spider found [0-9]+ URLs' "${LOG_PATH}" | tail -n 1 | grep -Eo '[0-9]+' || echo 0)"
cold_run_seconds="${SECONDS}"

cat > "${METRICS_PATH}" <<EOF
{
  "specMode": "${SPEC_MODE}",
  "zapImage": "${ZAP_IMAGE}",
  "zapExitCode": ${zap_exit},
  "coldRunSeconds": ${cold_run_seconds},
  "authBootstrapStatus": 200,
  "protectedValidationStatus": 200,
  "adminValidationStatus": 200,
  "seededRequestCount": ${seeded_count},
  "openApiImportedUrlCount": ${openapi_imported},
  "spiderDiscoveredUrlCount": ${spider_found},
  "adminRouteUrl": "${ADMIN_ROUTE_URL}"
}
EOF

node "${GITHUB_WORKSPACE}/benchmarks/fullstack-fastapi-template/verify-t4.js" "${REPORT_PATH}" "${METRICS_PATH}" "${LOG_PATH}" | tee "${VERIFY_PATH}"
