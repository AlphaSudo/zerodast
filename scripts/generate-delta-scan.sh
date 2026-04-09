#!/usr/bin/env bash
set -euo pipefail

INPUT_FILE="${1:-/tmp/delta-endpoints.txt}"
FULL_CONFIG="${2:-security/zap/automation.yaml}"
OUTPUT_FILE="${OUTPUT_FILE:-/tmp/zap-config.yaml}"
TARGET_URL="${TARGET_URL:-http://untrusted-app:8080}"
NODE_BIN="${NODE_BIN:-node}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
REQUEST_SEEDS_JSON="$("${NODE_BIN}" "${SCRIPT_DIR}/build-request-seeds.js" "$INPUT_FILE" "$TARGET_URL")"

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
  REQUEST_SEEDS_JSON="$REQUEST_SEEDS_JSON" "${NODE_BIN}" - <<'EOF'
const seeds = JSON.parse(process.env.REQUEST_SEEDS_JSON || "[]");

function printReplacer(description, tokenVar) {
  console.log('  - type: replacer');
  console.log('    parameters:');
  console.log('      deleteAllRules: true');
  console.log('    rules:');
  console.log(`      - description: "${description}"`);
  console.log('        matchType: "REQ_HEADER"');
  console.log('        matchString: "Authorization"');
  console.log(`        replacementString: "Bearer \${${tokenVar}}"`);
}

function printRequest(seed) {
  console.log('  - type: requestor');
  console.log('    requests:');
  console.log(`      - url: "${seed.url}"`);
  console.log(`        method: "${seed.method}"`);
}

const publicSeeds = seeds.filter((seed) => seed.scope === "public");
const userSeeds = seeds.filter((seed) => seed.scope === "user");
const adminSeeds = seeds.filter((seed) => seed.scope === "admin");

for (const seed of publicSeeds) {
  printRequest(seed);
}

if (userSeeds.length > 0) {
  printReplacer("Auth token injection", "AUTH_TOKEN");
  for (const seed of userSeeds) {
    printRequest(seed);
  }
}

if (adminSeeds.length > 0) {
  printReplacer("Admin auth token injection", "ADMIN_AUTH_TOKEN");
  for (const seed of adminSeeds) {
    printRequest(seed);
  }
}

if (userSeeds.length > 0 && adminSeeds.length > 0) {
  printReplacer("Restore user auth token injection", "AUTH_TOKEN");
}
EOF
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
