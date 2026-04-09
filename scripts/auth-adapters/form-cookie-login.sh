#!/usr/bin/env bash
set -euo pipefail

APP_URL="${1:-${APP_URL:-http://127.0.0.1:8080}}"
AUTH_OUTPUT_PATH="${AUTH_OUTPUT_PATH:-/tmp/zerodast-auth-material.env}"
AUTH_LOGIN_PATH="${AUTH_LOGIN_PATH:-/login}"
AUTH_FORM_EMAIL_FIELD="${AUTH_FORM_EMAIL_FIELD:-email}"
AUTH_FORM_PASSWORD_FIELD="${AUTH_FORM_PASSWORD_FIELD:-password}"
AUTH_BOOTSTRAP_EMAIL="${AUTH_BOOTSTRAP_EMAIL:-user@example.com}"
AUTH_BOOTSTRAP_PASSWORD="${AUTH_BOOTSTRAP_PASSWORD:-changeme}"
ADMIN_AUTH_BOOTSTRAP_EMAIL="${ADMIN_AUTH_BOOTSTRAP_EMAIL:-admin@example.com}"
ADMIN_AUTH_BOOTSTRAP_PASSWORD="${ADMIN_AUTH_BOOTSTRAP_PASSWORD:-changeme}"
AUTH_PROTECTED_ROUTE_PATH="${AUTH_PROTECTED_ROUTE_PATH:-/}"
AUTH_PROTECTED_ROUTE_EXPECTED_STATUS="${AUTH_PROTECTED_ROUTE_EXPECTED_STATUS:-200}"
ADMIN_PROTECTED_ROUTE_PATH="${ADMIN_PROTECTED_ROUTE_PATH:-/admin}"
ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS="${ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS:-200}"

login_and_extract_cookie() {
  local email="$1"
  local password="$2"
  local headers_file
  local cookie

  headers_file="$(mktemp)"
  trap 'rm -f "$headers_file"' RETURN

  curl -sS -D "$headers_file" -o /dev/null \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "${AUTH_FORM_EMAIL_FIELD}=${email}" \
    --data-urlencode "${AUTH_FORM_PASSWORD_FIELD}=${password}" \
    "$APP_URL$AUTH_LOGIN_PATH"

  cookie="$(awk 'BEGIN { IGNORECASE=1 } /^Set-Cookie:/ { print $2; exit }' "$headers_file" | tr -d '\r')"
  if [[ -z "$cookie" ]]; then
    echo "Failed to capture session cookie for ${email}" >&2
    exit 1
  fi

  printf '%s' "$cookie"
}

auth_cookie="$(login_and_extract_cookie "$AUTH_BOOTSTRAP_EMAIL" "$AUTH_BOOTSTRAP_PASSWORD")"
admin_cookie="$(login_and_extract_cookie "$ADMIN_AUTH_BOOTSTRAP_EMAIL" "$ADMIN_AUTH_BOOTSTRAP_PASSWORD")"

cat > "$AUTH_OUTPUT_PATH" <<EOF
AUTH_HEADER_NAME=Cookie
AUTH_HEADER_VALUE=${auth_cookie}
ADMIN_AUTH_HEADER_NAME=Cookie
ADMIN_AUTH_HEADER_VALUE=${admin_cookie}
AUTH_PROTECTED_ROUTE_PATH=${AUTH_PROTECTED_ROUTE_PATH}
AUTH_PROTECTED_ROUTE_EXPECTED_STATUS=${AUTH_PROTECTED_ROUTE_EXPECTED_STATUS}
ADMIN_PROTECTED_ROUTE_PATH=${ADMIN_PROTECTED_ROUTE_PATH}
ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS=${ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS}
EOF

echo "Cookie auth adapter bootstrap complete"
