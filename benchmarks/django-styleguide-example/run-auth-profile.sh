#!/usr/bin/env bash
set -euo pipefail

: "${TARGET_DIR:?TARGET_DIR is required}"

REPORTS_DIR="${REPORTS_DIR:-$(pwd)/benchmarks/django-styleguide-example/out}"
WORK_DIR="${REPORTS_DIR}/auth-profile"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-django-styleguide-auth-profile}"
HOST_PORT="${HOST_PORT:-18000}"
BASE_URL="${BASE_URL:-http://127.0.0.1:${HOST_PORT}}"
LOGIN_URL="${BASE_URL}/api/auth/session/login/"
ME_URL="${BASE_URL}/api/auth/me/"
USERS_URL="${BASE_URL}/api/users/"
AUTH_OUTPUT_PATH="${WORK_DIR}/auth-material.env"
SUMMARY_PATH="${WORK_DIR}/summary.md"
METRICS_PATH="${WORK_DIR}/metrics.json"
ENGINE_BIN="${CONTAINER_ENGINE_BIN:-docker}"
APP_IMAGE="${APP_IMAGE:-django-styleguide-auth-profile-app:local}"
APP_CONTAINER="${APP_CONTAINER:-django-styleguide-auth-profile-app}"
NETWORK_NAME="${COMPOSE_PROJECT_NAME}_default"
DATABASE_URL="${DATABASE_URL:-postgres://postgres:postgres@db:5432/styleguide_example_db}"
CELERY_BROKER_URL="${CELERY_BROKER_URL:-amqp://guest:guest@rabbitmq:5672//}"

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
  engine rm -f "${APP_CONTAINER}" >/dev/null 2>&1 || true
  (
    cd "${TARGET_DIR}"
    COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" engine compose down -v --remove-orphans >/dev/null 2>&1 || true
  )
}
trap cleanup EXIT

seed_users() {
  engine exec -i "${APP_CONTAINER}" python manage.py shell -c "from styleguide_example.users.models import BaseUser; from styleguide_example.users.services import user_create; emails = ['user@zerodast.local', 'admin@zerodast.local']; BaseUser.objects.filter(email__in=emails).delete(); user_create(email='user@zerodast.local', password='Test123!', is_admin=False); user_create(email='admin@zerodast.local', password='Test123!', is_admin=True)"
}

wait_for_route() {
  local attempts="${1:-60}"
  for ((i=0; i<attempts; i++)); do
    if curl -fsS "${USERS_URL}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
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

wait_for_app() {
  local attempts="${1:-90}"
  for ((i=0; i<attempts; i++)); do
    if curl -fsS "${USERS_URL}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

SECONDS=0

(
  cd "${TARGET_DIR}"
  COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}" engine compose up -d db rabbitmq >/dev/null
  engine build -t "${APP_IMAGE}" -f docker/local.Dockerfile .
)

engine run --rm --network "${NETWORK_NAME}" \
  -e DATABASE_URL="${DATABASE_URL}" \
  -e CELERY_BROKER_URL="${CELERY_BROKER_URL}" \
  "${APP_IMAGE}" python manage.py migrate >/dev/null

engine run -d --rm \
  --network "${NETWORK_NAME}" \
  --name "${APP_CONTAINER}" \
  -p "127.0.0.1:${HOST_PORT}:8000" \
  -e DATABASE_URL="${DATABASE_URL}" \
  -e CELERY_BROKER_URL="${CELERY_BROKER_URL}" \
  "${APP_IMAGE}" python manage.py runserver 0.0.0.0:8000 >/dev/null

if ! wait_for_app 90; then
  echo "Timed out waiting for Django benchmark target at ${USERS_URL}" >&2
  exit 1
fi

seed_users

AUTH_ADAPTER_SCRIPT="$(pwd)/scripts/auth-adapters/json-session-login.sh" \
AUTH_OUTPUT_PATH="${AUTH_OUTPUT_PATH}" \
AUTH_LOGIN_PATH="/api/auth/session/login/" \
AUTH_RESPONSE_SESSION_FIELD="session" \
AUTH_HEADER_NAME="Authorization" \
AUTH_HEADER_PREFIX="Session " \
AUTH_BOOTSTRAP_EMAIL="user@zerodast.local" \
AUTH_BOOTSTRAP_PASSWORD="Test123!" \
ADMIN_AUTH_BOOTSTRAP_EMAIL="admin@zerodast.local" \
ADMIN_AUTH_BOOTSTRAP_PASSWORD="Test123!" \
AUTH_PROTECTED_ROUTE_PATH="/api/auth/me/" \
AUTH_PROTECTED_ROUTE_EXPECTED_STATUS="200" \
ADMIN_PROTECTED_ROUTE_PATH="/api/users/" \
ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS="200" \
bash "$(pwd)/scripts/auth-adapters/json-session-login.sh" "${BASE_URL}" >/dev/null

# shellcheck disable=SC1090
source "${AUTH_OUTPUT_PATH}"

validate_with_header "${ME_URL}" "${AUTH_HEADER_NAME}" "${AUTH_HEADER_VALUE}" "${AUTH_PROTECTED_ROUTE_EXPECTED_STATUS}"
validate_with_header "${USERS_URL}" "${ADMIN_AUTH_HEADER_NAME}" "${ADMIN_AUTH_HEADER_VALUE}" "${ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS}"

cat > "${METRICS_PATH}" <<EOF
{
  "loginUrl": "${LOGIN_URL}",
  "protectedRouteUrl": "${ME_URL}",
  "adminRouteUrl": "${USERS_URL}",
  "userEmail": "user@zerodast.local",
  "adminEmail": "admin@zerodast.local",
  "authBootstrapStatus": 200,
  "protectedValidationStatus": ${AUTH_PROTECTED_ROUTE_EXPECTED_STATUS},
  "adminValidationStatus": ${ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS},
  "coldRunSeconds": ${SECONDS}
}
EOF

cat > "${SUMMARY_PATH}" <<EOF
# Django Session Auth Profile

- Session login URL: \`${LOGIN_URL}\`
- Protected route URL: \`${ME_URL}\`
- Admin route URL: \`${USERS_URL}\`
- Auth bootstrap status: \`200\`
- Protected route validation status: \`${AUTH_PROTECTED_ROUTE_EXPECTED_STATUS}\`
- Admin route validation status: \`${ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS}\`
- Cold run seconds: \`${SECONDS}\`
- Auth transport: \`Authorization: Session <sessionid>\`
EOF

echo "Django session auth profile completed in ${SECONDS}s"
