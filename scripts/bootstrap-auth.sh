#!/usr/bin/env bash
set -euo pipefail

APP_URL="${1:-${APP_URL:-http://untrusted-app:8080}}"
ALICE_TOKEN_PATH="${ALICE_TOKEN_PATH:-/tmp/zap-auth-token.txt}"
BOB_TOKEN_PATH="${BOB_TOKEN_PATH:-/tmp/zap-auth-token-bob.txt}"
ADMIN_TOKEN_PATH="${ADMIN_TOKEN_PATH:-/tmp/zap-auth-token-admin.txt}"
AUTH_OUTPUT_PATH="${AUTH_OUTPUT_PATH:-/tmp/zerodast-auth-material.env}"
AUTH_ADAPTER_SCRIPT="${AUTH_ADAPTER_SCRIPT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/auth-adapters/json-token-login.sh}"
NODE_BIN="${NODE_BIN:-C:/Users/CM/AppData/Roaming/fnm/node-versions/v22.15.0/installation/node.exe}"

extract_token() {
  local response="$1"

  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$response" | jq -r '.token // empty'
    return
  fi

  if [[ -x "$NODE_BIN" ]]; then
    RESPONSE_JSON="$response" "$NODE_BIN" -e "const raw = process.env.RESPONSE_JSON || ''; try { const parsed = JSON.parse(raw); process.stdout.write(parsed.token || ''); } catch { process.exit(1); }"
    return
  fi

  echo "Neither jq nor NODE_BIN is available for token parsing" >&2
  return 1
}

login_and_extract() {
  local email="$1"
  local password="$2"
  local response
  local token

  response=$(curl -sS "$APP_URL/api/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${email}\",\"password\":\"${password}\"}")

  token=$(extract_token "$response")
  if [[ -z "$token" || "$token" == "null" ]]; then
    echo "Failed to obtain token for ${email}: $response" >&2
    exit 1
  fi

  printf '%s' "$token"
}

AUTH_BOOTSTRAP_EMAIL='alice@test.local' \
AUTH_BOOTSTRAP_PASSWORD='Test123!' \
ADMIN_AUTH_BOOTSTRAP_EMAIL='admin@test.local' \
ADMIN_AUTH_BOOTSTRAP_PASSWORD='Test123!' \
AUTH_OUTPUT_PATH="$AUTH_OUTPUT_PATH" \
bash "$AUTH_ADAPTER_SCRIPT" "$APP_URL"

if [[ ! -f "$AUTH_OUTPUT_PATH" ]]; then
  echo "Auth adapter did not produce output file: $AUTH_OUTPUT_PATH" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$AUTH_OUTPUT_PATH"

alice_token="${AUTH_HEADER_VALUE#Bearer }"
bob_token=$(login_and_extract 'bob@test.local' 'Test123!')
admin_token="${ADMIN_AUTH_HEADER_VALUE#Bearer }"

printf '%s' "$alice_token" > "$ALICE_TOKEN_PATH"
printf '%s' "$bob_token" > "$BOB_TOKEN_PATH"
printf '%s' "$admin_token" > "$ADMIN_TOKEN_PATH"

echo "Auth bootstrap complete"
