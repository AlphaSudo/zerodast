#!/usr/bin/env bash
set -euo pipefail

APP_URL="${1:-${APP_URL:-http://127.0.0.1:8080}}"
AUTH_OUTPUT_PATH="${AUTH_OUTPUT_PATH:-/tmp/zerodast-auth-material.env}"
AUTH_LOGIN_PATH="${AUTH_LOGIN_PATH:-/api/auth/session/login/}"
AUTH_CONTENT_TYPE="${AUTH_CONTENT_TYPE:-application/json}"
AUTH_ADAPTER_EXEC_MODE="${AUTH_ADAPTER_EXEC_MODE:-host}"
AUTH_HEADER_NAME_VALUE="${AUTH_HEADER_NAME:-Authorization}"
AUTH_HEADER_PREFIX="${AUTH_HEADER_PREFIX:-Session }"
AUTH_RESPONSE_SESSION_FIELD="${AUTH_RESPONSE_SESSION_FIELD:-session}"
AUTH_BOOTSTRAP_EMAIL="${AUTH_BOOTSTRAP_EMAIL:-alice@test.local}"
AUTH_BOOTSTRAP_PASSWORD="${AUTH_BOOTSTRAP_PASSWORD:-Test123!}"
ADMIN_AUTH_BOOTSTRAP_EMAIL="${ADMIN_AUTH_BOOTSTRAP_EMAIL:-admin@test.local}"
ADMIN_AUTH_BOOTSTRAP_PASSWORD="${ADMIN_AUTH_BOOTSTRAP_PASSWORD:-Test123!}"
AUTH_PROTECTED_ROUTE_PATH="${AUTH_PROTECTED_ROUTE_PATH:-/api/auth/me/}"
AUTH_PROTECTED_ROUTE_EXPECTED_STATUS="${AUTH_PROTECTED_ROUTE_EXPECTED_STATUS:-200}"
ADMIN_PROTECTED_ROUTE_PATH="${ADMIN_PROTECTED_ROUTE_PATH:-/api/users/}"
ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS="${ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS:-200}"
NODE_BIN="${NODE_BIN:-C:/Users/CM/AppData/Roaming/fnm/node-versions/v22.15.0/installation/node.exe}"

extract_session() {
  local response="$1"

  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$response" | jq -r --arg field "$AUTH_RESPONSE_SESSION_FIELD" '.[$field] // empty'
    return
  fi

  if [[ -x "$NODE_BIN" ]]; then
    RESPONSE_JSON="$response" SESSION_FIELD="$AUTH_RESPONSE_SESSION_FIELD" "$NODE_BIN" -e "const raw = process.env.RESPONSE_JSON || ''; const field = process.env.SESSION_FIELD || 'session'; try { const parsed = JSON.parse(raw); process.stdout.write(parsed[field] || ''); } catch { process.exit(1); }"
    return
  fi

  echo "Neither jq nor NODE_BIN is available for session parsing" >&2
  return 1
}

login_and_extract_session() {
  local email="$1"
  local password="$2"
  local response
  local session

  if [[ "$AUTH_ADAPTER_EXEC_MODE" != "host" ]]; then
    echo "json-session-login.sh currently supports AUTH_ADAPTER_EXEC_MODE=host only" >&2
    exit 1
  fi

  response=$(curl -sS "$APP_URL$AUTH_LOGIN_PATH" \
    -H "Content-Type: $AUTH_CONTENT_TYPE" \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\"}")

  session=$(extract_session "$response")
  if [[ -z "$session" || "$session" == "null" ]]; then
    echo "Failed to obtain session for ${email}: $response" >&2
    exit 1
  fi

  printf '%s' "$session"
}

auth_session="$(login_and_extract_session "$AUTH_BOOTSTRAP_EMAIL" "$AUTH_BOOTSTRAP_PASSWORD")"
admin_auth_session="$(login_and_extract_session "$ADMIN_AUTH_BOOTSTRAP_EMAIL" "$ADMIN_AUTH_BOOTSTRAP_PASSWORD")"

emit_var() {
  local name="$1"
  local value="$2"
  printf '%s=%q\n' "$name" "$value"
}

{
  emit_var AUTH_HEADER_NAME "$AUTH_HEADER_NAME_VALUE"
  emit_var AUTH_HEADER_VALUE "${AUTH_HEADER_PREFIX}${auth_session}"
  emit_var ADMIN_AUTH_HEADER_NAME "$AUTH_HEADER_NAME_VALUE"
  emit_var ADMIN_AUTH_HEADER_VALUE "${AUTH_HEADER_PREFIX}${admin_auth_session}"
  emit_var AUTH_PROTECTED_ROUTE_PATH "$AUTH_PROTECTED_ROUTE_PATH"
  emit_var AUTH_PROTECTED_ROUTE_EXPECTED_STATUS "$AUTH_PROTECTED_ROUTE_EXPECTED_STATUS"
  emit_var ADMIN_PROTECTED_ROUTE_PATH "$ADMIN_PROTECTED_ROUTE_PATH"
  emit_var ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS "$ADMIN_PROTECTED_ROUTE_EXPECTED_STATUS"
} > "$AUTH_OUTPUT_PATH"

echo "JSON session auth adapter bootstrap complete"
