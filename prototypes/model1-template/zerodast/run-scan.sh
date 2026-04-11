#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
CONFIG_PATH="${ROOT_DIR}/config.json"
REPORT_DIR="${ROOT_DIR}/reports"
SCRIPTS_DIR="${ROOT_DIR}/scripts"
MODE="${ZERODAST_MODE:-pr}"
DOCKER_CMD="${ZERODAST_DOCKER_CMD:-docker}"
DOCKER_REQUIRES_WINDOWS_PATHS="false"
NODE_REQUIRES_WINDOWS_PATHS="false"
RUN_STARTED_AT="$(date +%s)"

HELPER_SCRIPT='fetch(process.argv[1]).then(async r => { if (!r.ok) process.exit(1); process.stdout.write(await r.text()); }).catch((err) => { console.error(err.message); process.exit(1); });'

AUTH_LOGIN_SCRIPT='const body={};body[process.env.EMAIL_FIELD||"email"]=process.env.EMAIL;body[process.env.PASSWORD_FIELD||"password"]=process.env.PASSWORD;const ct=process.env.CONTENT_TYPE||"application/json";const bs=ct.includes("json")?JSON.stringify(body):new URLSearchParams(body).toString();fetch(process.env.LOGIN_URL,{method:"POST",headers:{"Content-Type":ct},body:bs,redirect:"manual"}).then(async r=>{if(process.env.EXTRACT_MODE==="cookie"){const c=r.headers.get("set-cookie");if(!c){console.error(await r.text());process.exit(1);}process.stdout.write(c.split(";")[0]);return;}if(!r.ok){console.error(await r.text());process.exit(1);}const d=await r.json();const fields=(process.env.TOKEN_FIELD||"token").split(".");let t=d;for(const f of fields){t=t&&t[f];}if(!t){console.error(JSON.stringify(d));process.exit(1);}process.stdout.write(String(t));}).catch(e=>{console.error(e.message);process.exit(1);});'

AUTH_VALIDATE_SCRIPT='const h={};if(process.env.HEADER_NAME&&process.env.HEADER_VALUE)h[process.env.HEADER_NAME]=process.env.HEADER_VALUE;fetch(process.env.ROUTE_URL,{headers:h}).then(async r=>{if(String(r.status)!==process.env.EXPECTED_STATUS){console.error(await r.text());process.exit(1);}}).catch(e=>{console.error(e.message);process.exit(1);});'

if [[ "${DOCKER_CMD}" == *.exe ]] && command -v cygpath >/dev/null 2>&1; then
  DOCKER_REQUIRES_WINDOWS_PATHS="true"
fi

if command -v node >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
  NODE_EXEC_PATH="$(node -p "process.execPath" 2>/dev/null || true)"
  if [[ "${NODE_EXEC_PATH}" == *.exe ]]; then
    NODE_REQUIRES_WINDOWS_PATHS="true"
  fi
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
ENV_MANIFEST_JSON="${REPORT_DIR}/environment-manifest.json"
ENV_MANIFEST_MD="${REPORT_DIR}/environment-manifest.md"
API_INVENTORY_JSON="${REPORT_DIR}/api-inventory.json"
API_INVENTORY_MD="${REPORT_DIR}/api-inventory.md"
RESULT_STATE_JSON="${REPORT_DIR}/result-state.json"
RESULT_STATE_MD="${REPORT_DIR}/result-state.md"
REMEDIATION_MD="${REPORT_DIR}/remediation-guide.md"
RELIABILITY_JSON="${REPORT_DIR}/reliability-metrics.json"
OP_RELIABILITY_JSON="${REPORT_DIR}/operational-reliability.json"
OP_RELIABILITY_MD="${REPORT_DIR}/operational-reliability.md"
ROUTE_HINTS_JSON="${REPORT_DIR}/route-hints.json"
BASELINE_PATH="${ROOT_DIR}/.zap-baseline.json"
FINDING_BASELINE_PATH="${ROOT_DIR}/.zap-result-baseline.json"
PREPARE_OPENAPI_SCRIPT="${ROOT_DIR}/prepare-openapi.js"
VERIFY_REPORT_SCRIPT="${ROOT_DIR}/verify-report.js"

# --- Reliability tracking booleans ---
APP_READY=false
APP_READY_SECONDS=""
AUTH_VALIDATION_ATTEMPTED=false
AUTH_VALIDATION_PASSED=false
ADMIN_VALIDATION_ATTEMPTED=false
ADMIN_VALIDATION_PASSED=false
ZAP_RUN_REQUESTED=false
ZAP_RUN_COMPLETED=false
REPORT_PRODUCED=false
API_INVENTORY_PRODUCED=false
RESULT_STATE_PRODUCED=false
REMEDIATION_GUIDE_PRODUCED=false

# --- Windows path helpers ---
node_path() {
  local p="$1"
  if [[ "${NODE_REQUIRES_WINDOWS_PATHS}" == "true" ]]; then
    cygpath -w "$p"
  else
    printf '%s' "$p"
  fi
}

docker_path() {
  local p="$1"
  if [[ "${DOCKER_REQUIRES_WINDOWS_PATHS}" == "true" ]]; then
    cygpath -w "$p"
  else
    printf '%s' "$p"
  fi
}

# --- Read config values ---
cfg() {
  node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));const v=process.argv[2].split('.').reduce((o,k)=>o&&o[k],c);process.stdout.write(v==null?'':String(v));" "$(node_path "${CONFIG_PATH}")" "$1"
}

TARGET_WORK_DIR="$(cfg target.workingDirectory)"
TARGET_RUNTIME_MODE="$(cfg target.runtimeMode)"
TARGET_PORT="$(cfg target.port)"
TARGET_HEALTH_PATH="$(cfg target.healthPath)"
TARGET_OPENAPI_PATH="$(cfg target.openApiPath)"
TARGET_BUILD_COMMAND="$(cfg target.buildCommand)"
TARGET_ARTIFACT_PATTERN="$(cfg target.artifactPattern)"
TARGET_START_COMMAND="$(cfg target.startCommand)"
APP_IMAGE="$(cfg target.appImage)"
COMPOSE_UP_COMMAND="$(cfg target.compose.upCommand)"
COMPOSE_DOWN_COMMAND="$(cfg target.compose.downCommand)"
COMPOSE_NETWORK_NAME="$(cfg target.compose.networkName)"
COMPOSE_APP_HOST="$(cfg target.compose.appHost)"
ZAP_VERSION="$(cfg scan.zapVersion)"
HELPER_IMAGE="$(cfg scan.helperImage)"

[[ -z "$TARGET_PORT" ]] && TARGET_PORT="80"
[[ -z "$ZAP_VERSION" ]] && ZAP_VERSION="2.17.0"
[[ -z "$HELPER_IMAGE" ]] && HELPER_IMAGE="node:20-alpine"
[[ -z "$TARGET_WORK_DIR" ]] && TARGET_WORK_DIR="."

AUTH_ADAPTER="$(cfg auth.adapter)"
AUTH_LOGIN_PATH="$(cfg auth.loginPath)"
AUTH_CONTENT_TYPE="$(cfg auth.contentType)"
AUTH_EMAIL_FIELD="$(cfg auth.emailField)"
AUTH_PASSWORD_FIELD="$(cfg auth.passwordField)"
AUTH_RESPONSE_TOKEN_FIELD="$(cfg auth.responseTokenField)"
AUTH_HEADER_NAME_CFG="$(cfg auth.headerName)"
AUTH_HEADER_PREFIX="$(cfg auth.headerPrefix)"
AUTH_USER_EMAIL="$(cfg auth.user.email)"
AUTH_USER_PASSWORD="$(cfg auth.user.password)"
AUTH_ADMIN_EMAIL="$(cfg auth.admin.email)"
AUTH_ADMIN_PASSWORD="$(cfg auth.admin.password)"
AUTH_PROTECTED_ROUTE="$(cfg auth.protectedRoute.path)"
AUTH_PROTECTED_EXPECTED="$(cfg auth.protectedRoute.expectedStatus)"
AUTH_ADMIN_ROUTE="$(cfg auth.adminRoute.path)"
AUTH_ADMIN_EXPECTED="$(cfg auth.adminRoute.expectedStatus)"

[[ -z "$AUTH_CONTENT_TYPE" ]] && AUTH_CONTENT_TYPE="application/json"
[[ -z "$AUTH_EMAIL_FIELD" ]] && AUTH_EMAIL_FIELD="email"
[[ -z "$AUTH_PASSWORD_FIELD" ]] && AUTH_PASSWORD_FIELD="password"
[[ -z "$AUTH_RESPONSE_TOKEN_FIELD" ]] && AUTH_RESPONSE_TOKEN_FIELD="token"
[[ -z "$AUTH_HEADER_NAME_CFG" ]] && AUTH_HEADER_NAME_CFG="Authorization"
[[ -z "$AUTH_HEADER_PREFIX" ]] && AUTH_HEADER_PREFIX="Bearer "
[[ -z "$AUTH_PROTECTED_EXPECTED" ]] && AUTH_PROTECTED_EXPECTED="200"
[[ -z "$AUTH_ADMIN_EXPECTED" ]] && AUTH_ADMIN_EXPECTED="200"

TARGET_DIR="$(cd "${REPO_ROOT}/${TARGET_WORK_DIR}" && pwd)"
APP_CONTAINER="zerodast-target"
ZAP_CONTAINER="zerodast-zap"
NETWORK_NAME="zerodast-net"
APP_HOST="${APP_CONTAINER}"
SCANNER_BASE_ROOT="http://${APP_HOST}:${TARGET_PORT}"
MANAGED_RUNTIME="true"

AUTH_HEADER_NAME=""
AUTH_HEADER_VALUE=""
ADMIN_AUTH_HEADER_NAME=""
ADMIN_AUTH_HEADER_VALUE=""

if [[ "${TARGET_RUNTIME_MODE}" == "artifact" ]]; then
  if [[ -z "${TARGET_BUILD_COMMAND}" || -z "${TARGET_ARTIFACT_PATTERN}" ]]; then
    echo "artifact mode requires target.buildCommand and target.artifactPattern" >&2
    exit 1
  fi
elif [[ "${TARGET_RUNTIME_MODE}" == "compose" ]]; then
  if [[ -z "${COMPOSE_UP_COMMAND}" || -z "${COMPOSE_DOWN_COMMAND}" || -z "${COMPOSE_NETWORK_NAME}" || -z "${COMPOSE_APP_HOST}" ]]; then
    echo "compose mode requires target.compose.upCommand, downCommand, networkName, and appHost" >&2
    exit 1
  fi
  NETWORK_NAME="${COMPOSE_NETWORK_NAME}"
  APP_HOST="${COMPOSE_APP_HOST}"
  SCANNER_BASE_ROOT="http://${APP_HOST}:${TARGET_PORT}"
  MANAGED_RUNTIME="false"
else
  echo "Unsupported target.runtimeMode: ${TARGET_RUNTIME_MODE}" >&2
  exit 1
fi

# --- Cleanup ---
cleanup() {
  MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" rm -f "${ZAP_CONTAINER}" >/dev/null 2>&1 || true
  if [[ "${MANAGED_RUNTIME}" == "true" ]]; then
    MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" rm -f "${APP_CONTAINER}" >/dev/null 2>&1 || true
    MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" network rm "${NETWORK_NAME}" >/dev/null 2>&1 || true
  elif [[ -n "${COMPOSE_DOWN_COMMAND}" ]]; then
    (cd "${TARGET_DIR}" && eval "${COMPOSE_DOWN_COMMAND}") >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT
cleanup

# --- Auth functions ---
auth_login() {
  local email="$1" password="$2"
  local login_url="${SCANNER_BASE_ROOT}${AUTH_LOGIN_PATH}"
  local extract_mode="token"
  [[ "${AUTH_ADAPTER}" == "form-cookie-login" ]] && extract_mode="cookie"

  MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" run --rm --network "${NETWORK_NAME}" \
    -e "LOGIN_URL=${login_url}" \
    -e "EMAIL=${email}" \
    -e "PASSWORD=${password}" \
    -e "EMAIL_FIELD=${AUTH_EMAIL_FIELD}" \
    -e "PASSWORD_FIELD=${AUTH_PASSWORD_FIELD}" \
    -e "TOKEN_FIELD=${AUTH_RESPONSE_TOKEN_FIELD}" \
    -e "CONTENT_TYPE=${AUTH_CONTENT_TYPE}" \
    -e "EXTRACT_MODE=${extract_mode}" \
    "${HELPER_IMAGE}" node -e "${AUTH_LOGIN_SCRIPT}"
}

validate_route() {
  local header_name="$1" header_value="$2" route_path="$3" expected_status="$4"
  local route_url="${SCANNER_BASE_ROOT}${route_path}"

  MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" run --rm --network "${NETWORK_NAME}" \
    -e "ROUTE_URL=${route_url}" \
    -e "HEADER_NAME=${header_name}" \
    -e "HEADER_VALUE=${header_value}" \
    -e "EXPECTED_STATUS=${expected_status}" \
    "${HELPER_IMAGE}" node -e "${AUTH_VALIDATE_SCRIPT}"
}

write_operational_reliability() {
  local total_runtime_seconds
  total_runtime_seconds=$(( $(date +%s) - RUN_STARTED_AT ))

  cat > "${RELIABILITY_JSON}" <<JSON
{
  "totalRuntimeSeconds": ${total_runtime_seconds},
  "appReady": ${APP_READY},
  "appReadySeconds": ${APP_READY_SECONDS:-null},
  "authValidationAttempted": ${AUTH_VALIDATION_ATTEMPTED},
  "authValidationPassed": ${AUTH_VALIDATION_PASSED},
  "adminValidationAttempted": ${ADMIN_VALIDATION_ATTEMPTED},
  "adminValidationPassed": ${ADMIN_VALIDATION_PASSED},
  "zapRunRequested": ${ZAP_RUN_REQUESTED},
  "zapRunCompleted": ${ZAP_RUN_COMPLETED},
  "reportProduced": ${REPORT_PRODUCED},
  "apiInventoryProduced": ${API_INVENTORY_PRODUCED},
  "resultStateProduced": ${RESULT_STATE_PRODUCED},
  "remediationGuideProduced": ${REMEDIATION_GUIDE_PRODUCED}
}
JSON

  if [[ -f "${SCRIPTS_DIR}/build-operational-reliability.js" ]]; then
    node "$(node_path "${SCRIPTS_DIR}/build-operational-reliability.js")" \
      "$(node_path "${RELIABILITY_JSON}")" \
      "$(node_path "${OP_RELIABILITY_JSON}")" \
      "$(node_path "${OP_RELIABILITY_MD}")"
  fi
}

# --- Build environment manifest ---
if [[ -f "${SCRIPTS_DIR}/build-environment-manifest.js" ]]; then
  ZERODAST_TARGET_NAME="$(cfg name)" \
  ZERODAST_SCAN_PROFILE="${MODE}" \
  ZERODAST_SCAN_TRIGGER="${ZERODAST_SCAN_TRIGGER:-ci}" \
  ZERODAST_SCAN_MODE="model1" \
  AUTH_BOOTSTRAP_MODE="${AUTH_ADAPTER}" \
  AUTH_ADAPTER_SCRIPT="${AUTH_ADAPTER}" \
  AUTH_PROTECTED_ROUTE_PATH="${AUTH_PROTECTED_ROUTE}" \
  ADMIN_PROTECTED_ROUTE_PATH="${AUTH_ADMIN_ROUTE}" \
  AUTH_BOOTSTRAP_URL="${SCANNER_BASE_ROOT}" \
  APP_HEALTH_PATH="${TARGET_HEALTH_PATH}" \
  OPENAPI_SPEC_URL="${SCANNER_BASE_ROOT}${TARGET_OPENAPI_PATH}" \
  node "$(node_path "${SCRIPTS_DIR}/build-environment-manifest.js")" \
    "$(node_path "${ENV_MANIFEST_JSON}")" \
    "$(node_path "${ENV_MANIFEST_MD}")"
fi

# --- Start target ---
APP_JAR_MOUNT=""
RAW_SPEC_MOUNT="$(docker_path "${RAW_SPEC}")"
SANITIZED_SPEC_MOUNT="$(docker_path "${SANITIZED_SPEC}")"
AUTOMATION_MOUNT="$(docker_path "${AUTOMATION_PATH}")"
REPORT_DIR_MOUNT="$(docker_path "${REPORT_DIR}")"

if [[ "${TARGET_RUNTIME_MODE}" == "artifact" ]]; then
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

  APP_JAR_MOUNT="$(docker_path "${APP_JAR}")"

  MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" network create --internal "${NETWORK_NAME}" >/dev/null

  START_CMD="${TARGET_START_COMMAND}"
  if [[ -z "${START_CMD}" ]]; then
    START_CMD="java -jar /app/app.jar"
  fi

  # shellcheck disable=SC2086
  MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" run -d --rm \
    --network "${NETWORK_NAME}" \
    --name "${APP_CONTAINER}" \
    --cap-drop=ALL \
    --security-opt=no-new-privileges:true \
    --read-only \
    --tmpfs /tmp:rw,noexec,nosuid,size=100m \
    --memory=1g \
    --memory-swap=1g \
    --pids-limit=512 \
    -v "${APP_JAR_MOUNT}:/app/app.jar:ro" \
    "${APP_IMAGE}" \
    ${START_CMD} >/dev/null
else
  (cd "${TARGET_DIR}" && eval "${COMPOSE_UP_COMMAND}")
fi

# --- Wait for health ---
wait_for_health() {
  local attempts="${1:-60}"
  local start_ts
  start_ts="$(date +%s)"
  for ((i=0; i<attempts; i++)); do
    if MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "${HELPER_SCRIPT}" "${SCANNER_BASE_ROOT}${TARGET_HEALTH_PATH}" >/dev/null 2>&1; then
      APP_READY=true
      APP_READY_SECONDS=$(( $(date +%s) - start_ts ))
      return 0
    fi
    sleep 2
  done
  return 1
}

if ! wait_for_health 90; then
  echo "Timed out waiting for target health endpoint at ${SCANNER_BASE_ROOT}${TARGET_HEALTH_PATH}" >&2
  if [[ "${TARGET_RUNTIME_MODE}" == "compose" ]]; then
    echo "--- Container logs for debugging ---"
    (cd "${TARGET_DIR}" && docker compose -f docker-compose.zerodast.yml logs --tail=80 2>&1) || true
    echo "--- End container logs ---"
  fi
  write_operational_reliability
  exit 1
fi
echo "Target healthy at ${SCANNER_BASE_ROOT}${TARGET_HEALTH_PATH}"

# --- Seed (runs on host, after health, before auth) ---
SEED_COMMAND="$(cfg target.compose.seedCommand)"
if [[ -n "${SEED_COMMAND}" ]]; then
  echo "Running seed command: ${SEED_COMMAND}"
  (cd "${REPO_ROOT}" && eval "${SEED_COMMAND}")
  echo "Seed complete"
fi

# --- Auth bootstrap ---
if [[ -n "${AUTH_ADAPTER}" && -n "${AUTH_LOGIN_PATH}" ]]; then
  echo "Running auth adapter: ${AUTH_ADAPTER}"

  user_token="$(auth_login "${AUTH_USER_EMAIL}" "${AUTH_USER_PASSWORD}")"
  if [[ "${AUTH_ADAPTER}" == "form-cookie-login" ]]; then
    AUTH_HEADER_NAME="Cookie"
    AUTH_HEADER_VALUE="${user_token}"
  else
    AUTH_HEADER_NAME="${AUTH_HEADER_NAME_CFG}"
    AUTH_HEADER_VALUE="${AUTH_HEADER_PREFIX}${user_token}"
  fi
  echo "User auth obtained"

  if [[ -n "${AUTH_ADMIN_EMAIL}" && -n "${AUTH_ADMIN_PASSWORD}" ]]; then
    admin_token="$(auth_login "${AUTH_ADMIN_EMAIL}" "${AUTH_ADMIN_PASSWORD}")"
    if [[ "${AUTH_ADAPTER}" == "form-cookie-login" ]]; then
      ADMIN_AUTH_HEADER_NAME="Cookie"
      ADMIN_AUTH_HEADER_VALUE="${admin_token}"
    else
      ADMIN_AUTH_HEADER_NAME="${AUTH_HEADER_NAME_CFG}"
      ADMIN_AUTH_HEADER_VALUE="${AUTH_HEADER_PREFIX}${admin_token}"
    fi
    echo "Admin auth obtained"
  fi

  if [[ -n "${AUTH_PROTECTED_ROUTE}" ]]; then
    AUTH_VALIDATION_ATTEMPTED=true
    validate_route "${AUTH_HEADER_NAME}" "${AUTH_HEADER_VALUE}" "${AUTH_PROTECTED_ROUTE}" "${AUTH_PROTECTED_EXPECTED}"
    AUTH_VALIDATION_PASSED=true
    echo "Protected route validated: ${AUTH_PROTECTED_ROUTE}"
  fi

  if [[ -n "${AUTH_ADMIN_ROUTE}" && -n "${ADMIN_AUTH_HEADER_VALUE}" ]]; then
    ADMIN_VALIDATION_ATTEMPTED=true
    validate_route "${ADMIN_AUTH_HEADER_NAME}" "${ADMIN_AUTH_HEADER_VALUE}" "${AUTH_ADMIN_ROUTE}" "${AUTH_ADMIN_EXPECTED}"
    ADMIN_VALIDATION_PASSED=true
    echo "Admin route validated: ${AUTH_ADMIN_ROUTE}"
  fi
fi

# --- Fetch OpenAPI spec ---
MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "${HELPER_SCRIPT}" "${SCANNER_BASE_ROOT}${TARGET_OPENAPI_PATH}" > "${RAW_SPEC}" 2>/dev/null || true

# --- Prepare OpenAPI ---
node "$(node_path "${PREPARE_OPENAPI_SCRIPT}")" \
  "$(node_path "${CONFIG_PATH}")" \
  "${MODE}" \
  "$(node_path "${RAW_SPEC}")" \
  "$(node_path "${SANITIZED_SPEC}")" \
  "$(node_path "${REQUESTS_JSON}")" > "${PREPARED_CONFIG}"

SCANNER_BASE_URL="$(node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.stdout.write(c.scannerBaseUrl);" "$(node_path "${PREPARED_CONFIG}")")"
SPIDER_TARGET_URL="$(node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.stdout.write(c.spiderTargetUrl||(c.scannerBaseUrl+'/'));" "$(node_path "${PREPARED_CONFIG}")")"
ENABLE_SPIDER="$(node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.stdout.write(String(c.modeConfig.enableSpider!==false));" "$(node_path "${PREPARED_CONFIG}")")"
SPIDER_MINUTES="$(node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.stdout.write(String(c.modeConfig.spiderMinutes||2));" "$(node_path "${PREPARED_CONFIG}")")"
SPIDER_MAX_DEPTH="$(node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.stdout.write(String(c.modeConfig.spiderMaxDepth||5));" "$(node_path "${PREPARED_CONFIG}")")"
SPIDER_MAX_CHILDREN="$(node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.stdout.write(String(c.modeConfig.spiderMaxChildren||50));" "$(node_path "${PREPARED_CONFIG}")")"
PASSIVE_WAIT_MINUTES="$(node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.stdout.write(String(c.modeConfig.passiveWaitMinutes||2));" "$(node_path "${PREPARED_CONFIG}")")"
SCAN_MINUTES="$(node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.stdout.write(String(c.modeConfig.maxDurationMinutes||15));" "$(node_path "${PREPARED_CONFIG}")")"
THREAD_PER_HOST="$(node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.stdout.write(String(c.modeConfig.threadPerHost||4));" "$(node_path "${PREPARED_CONFIG}")")"
DEFAULT_STRENGTH="$(node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.stdout.write(String(c.modeConfig.defaultStrength||'medium'));" "$(node_path "${PREPARED_CONFIG}")")"
DEFAULT_THRESHOLD="$(node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));process.stdout.write(String(c.modeConfig.defaultThreshold||'low'));" "$(node_path "${PREPARED_CONFIG}")")"
ZAP_IMAGE="zaproxy/zap-stable:${ZAP_VERSION}"
SPEC_MODE="raw"

# --- Write ZAP automation config ---
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
    failOnError: false
    progressToStdout: true
jobs:
EOF
    if [[ -n "${AUTH_HEADER_VALUE}" ]]; then
      cat <<EOF
  - type: replacer
    parameters:
      deleteAllRules: true
    rules:
      - description: "ZeroDAST auth header"
        matchType: REQ_HEADER
        matchString: "${AUTH_HEADER_NAME}"
        matchRegex: false
        replacementString: "${AUTH_HEADER_VALUE}"
        initiators: []
EOF
    fi
    local spec_has_paths
    spec_has_paths="$(node -e "try{const s=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'));process.stdout.write(Object.keys(s.paths||{}).length>0?'yes':'no');}catch{process.stdout.write('no');}" "$(node_path "${RAW_SPEC}")" 2>/dev/null || echo no)"
    if [[ "${spec_has_paths}" == "yes" ]]; then
      cat <<EOF
  - type: openapi
    parameters:
      apiUrl: "${api_url}"
      targetUrl: "${SCANNER_BASE_URL}"
      context: "zerodast-model1"
EOF
    fi
    cat <<EOF
  - type: requestor
    requests:
EOF
    node -e "const fs=require('fs');const requests=JSON.parse(fs.readFileSync(process.argv[1],'utf8'));for(const url of requests){console.log('      - url: \"'+url+'\"');console.log('        method: \"GET\"');}" "$(node_path "${REQUESTS_JSON}")"
    if [[ "${ENABLE_SPIDER}" == "true" ]]; then
      cat <<EOF
  - type: spider
    parameters:
      context: "zerodast-model1"
      url: "${SPIDER_TARGET_URL}"
      maxDuration: ${SPIDER_MINUTES}
      maxDepth: ${SPIDER_MAX_DEPTH}
      maxChildren: ${SPIDER_MAX_CHILDREN}
EOF
    fi
    cat <<EOF
  - type: passiveScan-wait
    parameters:
      maxDuration: ${PASSIVE_WAIT_MINUTES}
  - type: activeScan
    parameters:
      context: "zerodast-model1"
      maxRuleDurationInMins: 5
      maxScanDurationInMins: ${SCAN_MINUTES}
      threadPerHost: ${THREAD_PER_HOST}
      delayInMs: 50
    policyDefinition:
      defaultStrength: ${DEFAULT_STRENGTH}
      defaultThreshold: ${DEFAULT_THRESHOLD}
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
EOF
  } > "${AUTOMATION_PATH}"
}

# --- Run ZAP ---
run_zap() {
  chmod 777 "${REPORT_DIR}" 2>/dev/null || true
  MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" rm -f "${ZAP_CONTAINER}" >/dev/null 2>&1 || true
  MSYS_NO_PATHCONV=1 "${DOCKER_CMD}" run --rm --name "${ZAP_CONTAINER}" \
    --network "${NETWORK_NAME}" \
    -v "${REPORT_DIR_MOUNT}:/zap/wrk:Z" \
    "${ZAP_IMAGE}" zap.sh -cmd -autorun /zap/wrk/automation.yaml
}

SECONDS=0
write_config "file:///zap/wrk/openapi-raw.json"
ZAP_RUN_REQUESTED=true
set +e
run_zap > "${LOG_PATH}" 2>&1
zap_exit=$?
set -e

if [[ ! -f "${REPORT_PATH}" ]] && grep -q 'Failed to import OpenAPI definition' "${LOG_PATH}" 2>/dev/null; then
  SPEC_MODE="sanitized"
  write_config "file:///zap/wrk/openapi-sanitized.json"
  set +e
  run_zap > "${LOG_PATH}" 2>&1
  zap_exit=$?
  set -e
fi

ZAP_RUN_COMPLETED=true

if [[ ! -f "${REPORT_PATH}" ]]; then
  echo "ZAP did not generate a report at ${REPORT_PATH}" >&2
  write_operational_reliability
  exit 1
fi

REPORT_PRODUCED=true
echo "ZAP finished with exit code ${zap_exit}"

# --- Operator artifacts ---
seeded_count=$(node -e "const fs=require('fs');console.log(JSON.parse(fs.readFileSync(process.argv[1],'utf8')).length);" "$(node_path "${REQUESTS_JSON}")")
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

if [[ -f "${SCRIPTS_DIR}/build-api-inventory.js" && -f "${LOG_PATH}" ]]; then
  node "$(node_path "${SCRIPTS_DIR}/build-api-inventory.js")" \
    "$(node_path "${REPORT_PATH}")" \
    "$(node_path "${LOG_PATH}")" \
    "$(node_path "${RAW_SPEC}")" \
    "$(node_path "${API_INVENTORY_JSON}")" \
    "$(node_path "${API_INVENTORY_MD}")" \
    "$(node_path "${ROUTE_HINTS_JSON}")" || true
  if [[ -f "${API_INVENTORY_JSON}" ]]; then
    API_INVENTORY_PRODUCED=true
  fi
fi

if [[ -f "${SCRIPTS_DIR}/build-result-state.js" ]]; then
  local_baseline="${BASELINE_PATH}"
  [[ ! -f "${local_baseline}" ]] && local_baseline="/dev/null"
  local_finding_baseline="${FINDING_BASELINE_PATH}"
  [[ ! -f "${local_finding_baseline}" ]] && local_finding_baseline=""

  node "$(node_path "${SCRIPTS_DIR}/build-result-state.js")" \
    "$(node_path "${REPORT_PATH}")" \
    "$(node_path "${local_baseline}")" \
    "$(node_path "${RESULT_STATE_JSON}")" \
    "$(node_path "${RESULT_STATE_MD}")" \
    ${local_finding_baseline:+"$(node_path "${local_finding_baseline}")"} || true
  if [[ -f "${RESULT_STATE_JSON}" ]]; then
    RESULT_STATE_PRODUCED=true
  fi
fi

if [[ -f "${SCRIPTS_DIR}/build-remediation-guide.js" && -f "${RESULT_STATE_JSON}" ]]; then
  node "$(node_path "${SCRIPTS_DIR}/build-remediation-guide.js")" \
    "$(node_path "${RESULT_STATE_JSON}")" \
    "$(node_path "${REMEDIATION_MD}")" || true
  if [[ -f "${REMEDIATION_MD}" ]]; then
    REMEDIATION_GUIDE_PRODUCED=true
  fi
fi

write_operational_reliability

# --- Summary ---
node "$(node_path "${VERIFY_REPORT_SCRIPT}")" \
  "$(node_path "${REPORT_PATH}")" \
  "$(node_path "${METRICS_PATH}")" \
  "$(node_path "${PREPARED_CONFIG}")" \
  "$(node_path "${LOG_PATH}")" \
  "$(node_path "${REQUESTS_JSON}")" | tee "${SUMMARY_PATH}"
