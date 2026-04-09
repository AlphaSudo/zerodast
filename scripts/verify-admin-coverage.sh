#!/usr/bin/env bash
set -euo pipefail

REPORT="${1:-reports/zap-report.json}"
EXPECTED_ROUTE="${2:-/api/users}"

if [[ ! -f "$REPORT" ]]; then
  echo "Report not found: $REPORT" >&2
  exit 1
fi

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

node_readable_path() {
  local path="$1"
  local node_bin="$2"
  if [[ "$node_bin" == *.exe ]] && command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$path"
  else
    printf '%s\n' "$path"
  fi
}

extract_matches() {
  local report_file="$1"
  local route="$2"
  local node_bin
  node_bin="$(resolve_node_bin || true)"

  if [[ -n "$node_bin" ]]; then
    local readable_path
    readable_path="$(node_readable_path "$report_file" "$node_bin")"
    "$node_bin" -e "
      const fs = require('fs');
      const route = process.argv[2];
      const report = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
      const matches = new Set();
      for (const site of report.site || []) {
        for (const alert of site.alerts || []) {
          for (const instance of alert.instances || []) {
            const uri = String(instance.uri || '');
            const nodeName = String(instance.nodeName || '');
            if (uri.includes(route) || nodeName.includes(route)) {
              matches.add(uri || nodeName);
            }
          }
        }
      }
      for (const match of matches) console.log(match);
    " "$readable_path" "$route"
    return
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -r --arg route "$route" '.site[].alerts[].instances[]? | select(((.uri // "") | contains($route)) or ((.nodeName // "") | contains($route))) | (.uri // .nodeName // empty)' "$report_file"
    return
  fi

  grep -o "${route}[^[:space:]]*" "$report_file" || true
}

MATCHES="$(extract_matches "$REPORT" "$EXPECTED_ROUTE")"

if [[ -z "$MATCHES" ]]; then
  echo "Admin route coverage missing: ${EXPECTED_ROUTE}" >&2
  exit 1
fi

echo "Admin route coverage found for ${EXPECTED_ROUTE}:"
echo "$MATCHES" | sort -u
