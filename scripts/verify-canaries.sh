#!/usr/bin/env bash
set -euo pipefail

REPORT="${1:-reports/zap-report.json}"
MISSING=0
EXPECTED=("SQL Injection" "Cross Site Scripting" "Application Error Disclosure")

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

extract_alert_names() {
  local report_file="$1"
  local node_bin
  node_bin="$(resolve_node_bin || true)"

  if [[ -n "$node_bin" ]]; then
    local readable_path
    readable_path="$(node_readable_path "$report_file" "$node_bin")"
    "$node_bin" -e "
      const rpt = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
      (rpt.site || []).forEach((site) => (site.alerts || []).forEach((alert) => console.log(alert.name)));
    " "$readable_path"
    return
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -r '.site[].alerts[].name' "$report_file"
    return
  fi

  grep -oP '"name"\s*:\s*"\K[^"]+' "$report_file"
}

ALERT_NAMES="$(extract_alert_names "$REPORT")"

for vuln in "${EXPECTED[@]}"; do
  if echo "$ALERT_NAMES" | grep -qi "$vuln"; then
    echo "Canary found: $vuln"
  else
    echo "CANARY MISSING: $vuln"
    MISSING=$((MISSING + 1))
  fi
done

if [[ "$MISSING" -gt 0 ]]; then
  echo "Coverage gap detected in ZAP canaries" >&2
  exit 1
fi

echo "All canaries verified"