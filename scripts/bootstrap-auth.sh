#!/usr/bin/env bash
set -euo pipefail

APP_URL="${1:-${APP_URL:-http://untrusted-app:8080}}"
ALICE_TOKEN_PATH="${ALICE_TOKEN_PATH:-/tmp/zap-auth-token.txt}"
BOB_TOKEN_PATH="${BOB_TOKEN_PATH:-/tmp/zap-auth-token-bob.txt}"
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

alice_token=$(login_and_extract 'alice@test.local' 'Test123!')
bob_token=$(login_and_extract 'bob@test.local' 'Test123!')

printf '%s' "$alice_token" > "$ALICE_TOKEN_PATH"
printf '%s' "$bob_token" > "$BOB_TOKEN_PATH"

echo "Auth bootstrap complete"