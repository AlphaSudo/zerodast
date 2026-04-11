#!/usr/bin/env bash
set -euo pipefail

: "${TARGET_DIR:?TARGET_DIR is required}"

REPORTS_DIR="${REPORTS_DIR:-$(pwd)/benchmarks/fullstack-fastapi-template/out}"
WORK_DIR="${REPORTS_DIR}/auth-profile"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-fastapi-auth-profile}"
NETWORK_NAME="${COMPOSE_PROJECT_NAME}_default"
ENGINE_BIN="${CONTAINER_ENGINE_BIN:-docker}"
HELPER_IMAGE="${HELPER_IMAGE:-node:20-alpine}"
SCANNER_BASE_ROOT="${SCANNER_BASE_ROOT:-http://backend:8000}"
PUBLIC_BASE_ROOT="${PUBLIC_BASE_ROOT:-http://127.0.0.1:8000}"
API_BASE_PATH="${API_BASE_PATH:-/api/v1}"
API_BASE_URL="${SCANNER_BASE_ROOT}${API_BASE_PATH}"
PUBLIC_API_BASE_URL="${PUBLIC_BASE_ROOT}${API_BASE_PATH}"
HEALTH_URL="${API_BASE_URL}/utils/health-check/"
SIGNUP_URL="${PUBLIC_API_BASE_URL}/users/signup"
LOGIN_URL="${PUBLIC_API_BASE_URL}/login/access-token"
ME_URL="${PUBLIC_API_BASE_URL}/users/me"
USERS_URL="${PUBLIC_API_BASE_URL}/users/?skip=0&limit=10"
AUTH_OUTPUT_PATH="${WORK_DIR}/auth-material.env"
SUMMARY_PATH="${WORK_DIR}/summary.md"
METRICS_PATH="${WORK_DIR}/metrics.json"
USER_EMAIL="${USER_EMAIL:-user-zerodast@example.com}"
USER_PASSWORD="${USER_PASSWORD:-Test12345!}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-changethis}"

mkdir -p "${WORK_DIR}"
find "${WORK_DIR}" -maxdepth 1 -type f -delete

engine() {
  if [[ "$ENGINE_BIN" == *.exe ]]; then
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" "$ENGINE_BIN" "$@"
  else
    "$ENGINE_BIN" "$@"
  fi
}

cleanup() {
  (
    cd "${TARGET_DIR}"
    COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" engine compose down -v --remove-orphans >/dev/null 2>&1 || true
  )
}
trap cleanup EXIT

wait_for_backend() {
  local attempts="${1:-80}"
  for ((i=0; i<attempts; i++)); do
    if engine run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "fetch(process.argv[1]).then(async r => { if (!r.ok) process.exit(1); process.stdout.write(await r.text()); }).catch(() => process.exit(1));" "${HEALTH_URL}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done
  return 1
}

ensure_user_signup() {
  engine run --rm --network "${NETWORK_NAME}" "${HELPER_IMAGE}" node -e "
    const [url, email, password] = process.argv.slice(1);
    fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email, password, full_name: 'ZeroDAST User' })
    }).then(async (response) => {
      if (response.ok) {
        process.stdout.write('created');
        return;
      }
      const text = await response.text();
      if (response.status === 400 && /already exists/i.test(text)) {
        process.stdout.write('exists');
        return;
      }
      console.error(text);
      process.exit(response.status || 1);
    }).catch((error) => {
      console.error(error.message);
      process.exit(1);
    });
  " "${PUBLIC_API_BASE_URL}/users/signup" "${USER_EMAIL}" "${USER_PASSWORD}" >/dev/null
}

validate_with_header() {
  local url="$1"
  local header_name="$2"
  local header_value="$3"
  local expected_status="$4"

  local actual_status
  actual_status="$(curl -sS -o /dev/null -w '%{http_code}' -H "${header_name}: ${header_value}" "${url}")"
  if [[ "${actual_status}" != "${expected_status}" ]]; then
    echo "Unexpected status for ${url}: got ${actual_status}, expected ${expected_status}" >&2
    exit 1
  fi
}

SECONDS=0

(
  cd "${TARGET_DIR}"
  COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" engine compose up -d db prestart backend >/dev/null
)

if ! wait_for_backend 80; then
  echo "Timed out waiting for FastAPI benchmark target at ${HEALTH_URL}" >&2
  exit 1
fi

ensure_user_signup

AUTH_ADAPTER_SCRIPT="$(pwd)/scripts/auth-adapters/form-urlencoded-token-login.sh" \
AUTH_OUTPUT_PATH="${AUTH_OUTPUT_PATH}" \
AUTH_LOGIN_PATH="${API_BASE_PATH}/login/access-token" \
AUTH_RESPONSE_TOKEN_FIELD="access_token" \
AUTH_USERNAME_FIELD="username" \
AUTH_PASSWORD_FIELD="password" \
AUTH_HEADER_NAME="Authorization" \
AUTH_HEADER_PREFIX="Bearer " \
AUTH_BOOTSTRAP_EMAIL="${USER_EMAIL}" \
AUTH_BOOTSTRAP_PASSWORD="${USER_PASSWORD}" \
ADMIN_AUTH_BOOTSTRAP_EMAIL="${ADMIN_EMAIL}" \
ADMIN_AUTH_BOOTSTRAP_PASSWORD="${ADMIN_PASSWORD}" \
AUTH_PROTECTED_ROUTE_PATH="${API_BASE_PATH}/users/me" \
AUTH_PROTECTED_ROUTE_EXPECTED_STATUS="200" \
ADMIN_PROTECTED_ROUTE_PATH="${API_BASE_PATH}/users/?skip=0&limit=10" \
ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS="200" \
bash "$(pwd)/scripts/auth-adapters/form-urlencoded-token-login.sh" "${PUBLIC_BASE_ROOT}" >/dev/null

# shellcheck disable=SC1090
source "${AUTH_OUTPUT_PATH}"

validate_with_header "${ME_URL}" "${AUTH_HEADER_NAME}" "${AUTH_HEADER_VALUE}" "${AUTH_PROTECTED_ROUTE_EXPECTED_STATUS}"
validate_with_header "${USERS_URL}" "${ADMIN_AUTH_HEADER_NAME}" "${ADMIN_AUTH_HEADER_VALUE}" "${ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS}"

cat > "${METRICS_PATH}" <<EOF
{
  "signupUrl": "${SIGNUP_URL}",
  "loginUrl": "${LOGIN_URL}",
  "protectedRouteUrl": "${ME_URL}",
  "adminRouteUrl": "${USERS_URL}",
  "userEmail": "${USER_EMAIL}",
  "adminEmail": "${ADMIN_EMAIL}",
  "authBootstrapStatus": 200,
  "protectedValidationStatus": ${AUTH_PROTECTED_ROUTE_EXPECTED_STATUS},
  "adminValidationStatus": ${ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS},
  "coldRunSeconds": ${SECONDS}
}
EOF

cat > "${SUMMARY_PATH}" <<EOF
# Fullstack FastAPI Auth Profile

- Signup URL: \`${SIGNUP_URL}\`
- Login URL: \`${LOGIN_URL}\`
- Protected route URL: \`${ME_URL}\`
- Admin route URL: \`${USERS_URL}\`
- Auth bootstrap status: \`200\`
- Protected route validation status: \`${AUTH_PROTECTED_ROUTE_EXPECTED_STATUS}\`
- Admin route validation status: \`${ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS}\`
- Cold run seconds: \`${SECONDS}\`
- Auth transport: \`Authorization: Bearer <access_token>\`
- Login body mode: \`application/x-www-form-urlencoded\`
EOF

echo "Fullstack FastAPI auth profile completed in ${SECONDS}s"
