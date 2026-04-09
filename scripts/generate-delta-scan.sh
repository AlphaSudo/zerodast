#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE="${1:-/tmp/delta-endpoints.txt}"
FULL_CONFIG="${2:-security/zap/automation.yaml}"
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/zap-config.yaml}"
TARGET_URL="${TARGET_URL:-http://untrusted-app:8080}"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Delta input file not found: $INPUT_FILE" >&2
  exit 1
fi

first_line=$(head -n 1 "$INPUT_FILE" | tr -d '\r')
if [[ "$first_line" == "FULL" ]]; then
  cp "$FULL_CONFIG" "$OUTPUT_FILE"
  echo "$OUTPUT_FILE"
  exit 0
fi

mapfile -t endpoints < <(grep -v '^$' "$INPUT_FILE")

{
  echo 'env:'
  echo '  vars:'
  echo '    AUTH_TOKEN: "${AUTH_TOKEN}"'
  echo '    ADMIN_AUTH_TOKEN: "${ADMIN_AUTH_TOKEN}"'
  echo '  contexts:'
  echo '    - name: "zerodast-target"'
  echo "      urls: [\"${TARGET_URL}\"]"
  echo '      includePaths:'
  for endpoint in "${endpoints[@]}"; do
    escaped=$(printf '%s' "$endpoint" | sed 's/[.[\*^$()+?{}|]/\\&/g')
    echo "        - \"${TARGET_URL}${escaped}.*\""
  done
  echo '  parameters:'
  echo '    failOnError: true'
  echo '    progressToStdout: true'
  echo 'jobs:'
  echo '  - type: openapi'
  echo '    parameters:'
  echo '      apiUrl: "http://untrusted-app:8080/v3/api-docs"'
  echo '  - type: replacer'
  echo '    parameters:'
  echo '      deleteAllRules: true'
  echo '    rules:'
  echo '      - description: "Auth token injection"'
  echo '        matchType: "REQ_HEADER_ADD"'
  echo '        matchString: "Authorization"'
  echo '        replacement: "Bearer ${AUTH_TOKEN}"'
  echo '        enabled: true'
  echo '  - type: replacer'
  echo '    parameters:'
  echo '      deleteAllRules: true'
  echo '    rules:'
  echo '      - description: "Admin auth token injection"'
  echo '        matchType: "REQ_HEADER_ADD"'
  echo '        matchString: "Authorization"'
  echo '        replacement: "Bearer ${ADMIN_AUTH_TOKEN}"'
  echo '        enabled: true'
  echo '  - type: requestor'
  echo '    requests:'
  echo "      - url: \"${TARGET_URL}/api/users\""
  echo '        method: "GET"'
  echo '  - type: replacer'
  echo '    parameters:'
  echo '      deleteAllRules: true'
  echo '    rules:'
  echo '      - description: "Restore user auth token injection"'
  echo '        matchType: "REQ_HEADER_ADD"'
  echo '        matchString: "Authorization"'
  echo '        replacement: "Bearer ${AUTH_TOKEN}"'
  echo '        enabled: true'
  echo '  - type: passiveScan-wait'
  echo '    parameters:'
  echo '      maxDuration: 2'
  echo '  - type: activeScan'
  echo '    parameters:'
  echo '      context: "zerodast-target"'
  echo '      maxRuleDurationInMins: 5'
  echo '      maxScanDurationInMins: 30'
  echo '      threadPerHost: 4'
  echo '      delayInMs: 50'
  echo '  - type: report'
  echo '    parameters:'
  echo '      template: "traditional-json"'
  echo '      reportDir: "/zap/wrk"'
  echo '      reportFile: "zap-report.json"'
} > "$OUTPUT_FILE"

echo "$OUTPUT_FILE"
