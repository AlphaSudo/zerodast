#!/usr/bin/env bash
set -euo pipefail

REPORT="${1:-reports/zap-report.json}"
MISSING=0
EXPECTED=("SQL Injection" "Cross Site Scripting" "Application Error Disclosure")

if [[ ! -f "$REPORT" ]]; then
  echo "Report not found: $REPORT" >&2
  exit 1
fi

for vuln in "${EXPECTED[@]}"; do
  if jq -r '.site[].alerts[].name' "$REPORT" | grep -qi "$vuln"; then
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
