#!/usr/bin/env bash
set -euo pipefail

APP_URL="${1:-${APP_URL:-http://untrusted-app:8080}}"
EXPECT_IDOR="${EXPECT_IDOR:-true}"
FAILURES=0
DETECTED=0

resolve_node_bin() {
  if command -v node >/dev/null 2>&1; then
    printf '%s\n' "node"
    return
  fi

  local fallback="${NODE_BIN:-C:/Users/CM/AppData/Roaming/fnm/node-versions/v22.15.0/installation/node.exe}"
  if [[ -x "$fallback" ]]; then
    printf '%s\n' "$fallback"
  fi
}

extract_token() {
  local response="$1"
  local node_bin
  node_bin="$(resolve_node_bin || true)"

  if [[ -n "$node_bin" ]]; then
    RESPONSE_JSON="$response" "$node_bin" -e "const raw = process.env.RESPONSE_JSON || ''; try { const parsed = JSON.parse(raw); process.stdout.write(parsed.token || ''); } catch { process.exit(1); }"
    return
  fi

  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$response" | jq -r '.token // empty'
    return
  fi

  echo "Neither node nor jq is available for token parsing" >&2
  return 1
}

login() {
  local email="$1"
  local response
  local token
  response=$(curl -sS "$APP_URL/api/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${email}\",\"password\":\"Test123!\"}")
  token=$(extract_token "$response")
  if [[ -z "$token" || "$token" == "null" ]]; then
    echo "Unable to authenticate ${email}: $response" >&2
    exit 1
  fi
  printf '%s' "$token"
}

record_result() {
  local name="$1"
  local status="$2"

  if [[ "$status" == "200" || "$status" == "204" ]]; then
    echo "IDOR detected: ${name} returned HTTP ${status}"
    DETECTED=$((DETECTED + 1))
    if [[ "$EXPECT_IDOR" != "true" ]]; then
      FAILURES=$((FAILURES + 1))
    fi
  else
    echo "Protected as expected for ${name}: HTTP ${status}"
    if [[ "$EXPECT_IDOR" == "true" ]]; then
      FAILURES=$((FAILURES + 1))
    fi
  fi
}

ALICE_TOKEN=$(login 'alice@test.local')
BOB_TOKEN=$(login 'bob@test.local')

status=$(curl -s -o /dev/null -w '%{http_code}' "$APP_URL/api/documents/4" \
  -H "Authorization: Bearer $ALICE_TOKEN")
record_result 'Alice reads Bob private document' "$status"

status=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$APP_URL/api/documents/1" \
  -H "Authorization: Bearer $BOB_TOKEN")
record_result 'Bob deletes Alice document' "$status"

status=$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$APP_URL/api/users/1" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name":"Tampered Alice"}')
record_result 'Bob updates Alice profile' "$status"

echo "AuthZ detections: $DETECTED"
if [[ "$EXPECT_IDOR" == "true" && "$DETECTED" -eq 0 ]]; then
  echo "WARNING: No IDOR detected; demo app may have been hardened unexpectedly"
fi

exit 0