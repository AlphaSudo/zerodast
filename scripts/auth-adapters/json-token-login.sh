#!/usr/bin/env bash
set -euo pipefail

APP_URL="${1:-${APP_URL:-http://127.0.0.1:8080}}"
AUTH_OUTPUT_PATH="${AUTH_OUTPUT_PATH:-/tmp/zerodast-auth-material.env}"
AUTH_LOGIN_PATH="${AUTH_LOGIN_PATH:-/api/auth/login}"
AUTH_CONTENT_TYPE="${AUTH_CONTENT_TYPE:-application/json}"
AUTH_ADAPTER_EXEC_MODE="${AUTH_ADAPTER_EXEC_MODE:-auto}"
ENGINE_BIN="${ENGINE_BIN:-docker}"
APP_CONTAINER="${APP_CONTAINER:-}"
AUTH_HEADER_NAME_VALUE="${AUTH_HEADER_NAME:-Authorization}"
AUTH_HEADER_PREFIX="${AUTH_HEADER_PREFIX:-Bearer }"
AUTH_RESPONSE_TOKEN_FIELD="${AUTH_RESPONSE_TOKEN_FIELD:-token}"
AUTH_BOOTSTRAP_EMAIL="${AUTH_BOOTSTRAP_EMAIL:-alice@test.local}"
AUTH_BOOTSTRAP_PASSWORD="${AUTH_BOOTSTRAP_PASSWORD:-Test123!}"
ADMIN_AUTH_BOOTSTRAP_EMAIL="${ADMIN_AUTH_BOOTSTRAP_EMAIL:-admin@test.local}"
ADMIN_AUTH_BOOTSTRAP_PASSWORD="${ADMIN_AUTH_BOOTSTRAP_PASSWORD:-Test123!}"
AUTH_PROTECTED_ROUTE_PATH="${AUTH_PROTECTED_ROUTE_PATH:-/api/documents}"
AUTH_PROTECTED_ROUTE_EXPECTED_STATUS="${AUTH_PROTECTED_ROUTE_EXPECTED_STATUS:-200}"
ADMIN_PROTECTED_ROUTE_PATH="${ADMIN_PROTECTED_ROUTE_PATH:-/api/users}"
ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS="${ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS:-200}"
NODE_BIN="${NODE_BIN:-C:/Users/CM/AppData/Roaming/fnm/node-versions/v22.15.0/installation/node.exe}"

extract_token() {
  local response="$1"

  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$response" | jq -r --arg field "$AUTH_RESPONSE_TOKEN_FIELD" '.[$field] // empty'
    return
  fi

  if [[ -x "$NODE_BIN" ]]; then
    RESPONSE_JSON="$response" TOKEN_FIELD="$AUTH_RESPONSE_TOKEN_FIELD" "$NODE_BIN" -e "const raw = process.env.RESPONSE_JSON || ''; const field = process.env.TOKEN_FIELD || 'token'; try { const parsed = JSON.parse(raw); process.stdout.write(parsed[field] || ''); } catch { process.exit(1); }"
    return
  fi

  echo "Neither jq nor NODE_BIN is available for token parsing" >&2
  return 1
}

engine() {
  if [[ "$ENGINE_BIN" == *.exe ]]; then
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*" "$ENGINE_BIN" "$@"
  else
    "$ENGINE_BIN" "$@"
  fi
}

login_and_extract_in_container() {
  local email="$1"
  local password="$2"

  engine exec \
    -e BOOTSTRAP_EMAIL="$email" \
    -e BOOTSTRAP_PASSWORD="$password" \
    -e AUTH_LOGIN_PATH="$AUTH_LOGIN_PATH" \
    -e TOKEN_FIELD="$AUTH_RESPONSE_TOKEN_FIELD" \
    "$APP_CONTAINER" \
    node -e "fetch('http://127.0.0.1:8080' + process.env.AUTH_LOGIN_PATH, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ email: process.env.BOOTSTRAP_EMAIL, password: process.env.BOOTSTRAP_PASSWORD }) }).then(async (response) => { const body = await response.text(); if (!response.ok) { console.error(body); process.exit(1); } const parsed = JSON.parse(body); const token = parsed[process.env.TOKEN_FIELD || 'token']; if (!token) { console.error(body); process.exit(1); } process.stdout.write(token); }).catch((error) => { console.error(error.stack || error.message); process.exit(1); });"
}

login_and_extract() {
  local email="$1"
  local password="$2"
  local response
  local token

  if [[ "$AUTH_ADAPTER_EXEC_MODE" == "container" ]] || { [[ "$AUTH_ADAPTER_EXEC_MODE" == "auto" ]] && [[ -n "$APP_CONTAINER" ]]; }; then
    login_and_extract_in_container "$email" "$password"
    return
  fi

  response=$(curl -sS "$APP_URL$AUTH_LOGIN_PATH" \
    -H "Content-Type: $AUTH_CONTENT_TYPE" \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\"}")

  token=$(extract_token "$response")
  if [[ -z "$token" || "$token" == "null" ]]; then
    echo "Failed to obtain token for ${email}: $response" >&2
    exit 1
  fi

  printf '%s' "$token"
}

auth_token="$(login_and_extract "$AUTH_BOOTSTRAP_EMAIL" "$AUTH_BOOTSTRAP_PASSWORD")"
admin_auth_token="$(login_and_extract "$ADMIN_AUTH_BOOTSTRAP_EMAIL" "$ADMIN_AUTH_BOOTSTRAP_PASSWORD")"

emit_var() {
  local name="$1"
  local value="$2"
  printf '%s=%q\n' "$name" "$value"
}

{
  emit_var AUTH_HEADER_NAME "$AUTH_HEADER_NAME_VALUE"
  emit_var AUTH_HEADER_VALUE "${AUTH_HEADER_PREFIX}${auth_token}"
  emit_var ADMIN_AUTH_HEADER_NAME "$AUTH_HEADER_NAME_VALUE"
  emit_var ADMIN_AUTH_HEADER_VALUE "${AUTH_HEADER_PREFIX}${admin_auth_token}"
  emit_var AUTH_PROTECTED_ROUTE_PATH "$AUTH_PROTECTED_ROUTE_PATH"
  emit_var AUTH_PROTECTED_ROUTE_EXPECTED_STATUS "$AUTH_PROTECTED_ROUTE_EXPECTED_STATUS"
  emit_var ADMIN_PROTECTED_ROUTE_PATH "$ADMIN_PROTECTED_ROUTE_PATH"
  emit_var ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS "$ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS"
} > "$AUTH_OUTPUT_PATH"

echo "Auth adapter bootstrap complete"
