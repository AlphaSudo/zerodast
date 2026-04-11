#!/usr/bin/env bash
set -euo pipefail

APP_URL="${1:-${APP_URL:-http://127.0.0.1:8080}}"
AUTH_OUTPUT_PATH="${AUTH_OUTPUT_PATH:-/tmp/zerodast-auth-material.env}"
AUTH_LOGIN_PATH="${AUTH_LOGIN_PATH:-/api/auth/session-login}"
AUTH_ADAPTER_EXEC_MODE="${AUTH_ADAPTER_EXEC_MODE:-auto}"
ENGINE_BIN="${ENGINE_BIN:-docker}"
APP_CONTAINER="${APP_CONTAINER:-}"
AUTH_FORM_EMAIL_FIELD="${AUTH_FORM_EMAIL_FIELD:-email}"
AUTH_FORM_PASSWORD_FIELD="${AUTH_FORM_PASSWORD_FIELD:-password}"
AUTH_BOOTSTRAP_EMAIL="${AUTH_BOOTSTRAP_EMAIL:-alice@test.local}"
AUTH_BOOTSTRAP_PASSWORD="${AUTH_BOOTSTRAP_PASSWORD:-Test123!}"
ADMIN_AUTH_BOOTSTRAP_EMAIL="${ADMIN_AUTH_BOOTSTRAP_EMAIL:-admin@test.local}"
ADMIN_AUTH_BOOTSTRAP_PASSWORD="${ADMIN_AUTH_BOOTSTRAP_PASSWORD:-Test123!}"
AUTH_PROTECTED_ROUTE_PATH="${AUTH_PROTECTED_ROUTE_PATH:-/api/documents}"
AUTH_PROTECTED_ROUTE_EXPECTED_STATUS="${AUTH_PROTECTED_ROUTE_EXPECTED_STATUS:-200}"
ADMIN_PROTECTED_ROUTE_PATH="${ADMIN_PROTECTED_ROUTE_PATH:-/api/users}"
ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS="${ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS:-200}"

engine() {
  if [[ "$ENGINE_BIN" == *.exe ]]; then
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" "$ENGINE_BIN" "$@"
  else
    "$ENGINE_BIN" "$@"
  fi
}

login_and_extract_cookie_in_container() {
  local email="$1"
  local password="$2"

  engine exec \
    -e BOOTSTRAP_EMAIL="$email" \
    -e BOOTSTRAP_PASSWORD="$password" \
    -e AUTH_LOGIN_PATH="$AUTH_LOGIN_PATH" \
    -e AUTH_FORM_EMAIL_FIELD="$AUTH_FORM_EMAIL_FIELD" \
    -e AUTH_FORM_PASSWORD_FIELD="$AUTH_FORM_PASSWORD_FIELD" \
    "$APP_CONTAINER" \
    node -e "const params = new URLSearchParams(); params.set(process.env.AUTH_FORM_EMAIL_FIELD || 'email', process.env.BOOTSTRAP_EMAIL || ''); params.set(process.env.AUTH_FORM_PASSWORD_FIELD || 'password', process.env.BOOTSTRAP_PASSWORD || ''); fetch('http://127.0.0.1:8080' + process.env.AUTH_LOGIN_PATH, { method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' }, body: params.toString(), redirect: 'manual' }).then(async (response) => { const setCookie = response.headers.get('set-cookie'); if (!setCookie) { const body = await response.text(); console.error(body); process.exit(1); } process.stdout.write(setCookie.split(';')[0]); }).catch((error) => { console.error(error.stack || error.message); process.exit(1); });"
}

login_and_extract_cookie() {
  local email="$1"
  local password="$2"
  local headers_file
  local cookie

  if [[ "$AUTH_ADAPTER_EXEC_MODE" == "container" ]] || { [[ "$AUTH_ADAPTER_EXEC_MODE" == "auto" ]] && [[ -n "$APP_CONTAINER" ]]; }; then
    login_and_extract_cookie_in_container "$email" "$password"
    return
  fi

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

emit_var() {
  local name="$1"
  local value="$2"
  printf '%s=%q\n' "$name" "$value"
}

{
  emit_var AUTH_HEADER_NAME "Cookie"
  emit_var AUTH_HEADER_VALUE "$auth_cookie"
  emit_var ADMIN_AUTH_HEADER_NAME "Cookie"
  emit_var ADMIN_AUTH_HEADER_VALUE "$admin_cookie"
  emit_var AUTH_PROTECTED_ROUTE_PATH "$AUTH_PROTECTED_ROUTE_PATH"
  emit_var AUTH_PROTECTED_ROUTE_EXPECTED_STATUS "$AUTH_PROTECTED_ROUTE_EXPECTED_STATUS"
  emit_var ADMIN_PROTECTED_ROUTE_PATH "$ADMIN_PROTECTED_ROUTE_PATH"
  emit_var ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS "$ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS"
} > "$AUTH_OUTPUT_PATH"

echo "Cookie auth adapter bootstrap complete"
