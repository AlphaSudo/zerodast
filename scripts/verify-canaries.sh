#!/usr/bin/env bash
set -euo pipefail

REPORT="${1:-reports/zap-report.json}"
MISSING=0
EXPECTED=("SQL Injection" "Cross Site Scripting" "Application Error Disclosure")

if [[ ! -f "$REPORT" ]]; then
  echo "Report not found: $REPORT" >&2
  exit 1
fi

# Extract alert names without requiring jq.
# We use Node.js first (always available in this project), then jq, then grep.
extract_alert_names() {
  local report_file="$1"

  # Try Node.js (available on CI and locally)
  if command -v node >/dev/null 2>&1; then
    node -e "
      const rpt = JSON.parse(require('fs').readFileSync('$report_file','utf8'));
      (rpt.site||[]).forEach(s => (s.alerts||[]).forEach(a => console.log(a.name)));
    "
    return
  fi

  # Try custom NODE_BIN path (Windows / local dev)
  local NODE_BIN="${NODE_BIN:-C:/Users/CM/AppData/Roaming/fnm/node-versions/v22.15.0/installation/node.exe}"
  if [[ -x "$NODE_BIN" ]]; then
    "$NODE_BIN" -e "
      const rpt = JSON.parse(require('fs').readFileSync('$report_file','utf8'));
      (rpt.site||[]).forEach(s => (s.alerts||[]).forEach(a => console.log(a.name)));
    "
    return
  fi

  # Fallback to jq if available
  if command -v jq >/dev/null 2>&1; then
    jq -r '.site[].alerts[].name' "$report_file"
    return
  fi

  # Last-resort grep (fragile but works for our JSON layout)
  grep -oP '"name"\s*:\s*"\K[^"]+' "$report_file"
}

ALERT_NAMES=$(extract_alert_names "$REPORT")

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
