#!/usr/bin/env bash
set -euo pipefail
# Compare alert plugin id + name between stock and surgical benchmark outputs.
TARGET="${1:?Usage: verify-alert-parity.sh <target-name>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${BENCHMARK_ROOT:-$ROOT_DIR/reports/benchmark}/${TARGET}"

STOCK_IMAGE="${STOCK_IMAGE:-zaproxy/zap-stable:2.17.0}"
SURGICAL_IMAGE="${SURGICAL_IMAGE:-zerodast-scanner:2.17.0}"
STOCK_TAG=$(echo "$STOCK_IMAGE" | tr '/:' '_')
SURGICAL_TAG=$(echo "$SURGICAL_IMAGE" | tr '/:' '_')

STOCK="${STOCK:-$BASE/${STOCK_TAG}/run-1/zap-report.json}"
SURGICAL="${SURGICAL:-$BASE/${SURGICAL_TAG}/run-1/zap-report.json}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for verify-alert-parity.sh" >&2
  exit 1
fi

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

echo "=== Alert parity check for $TARGET ==="

jq -r '.site[].alerts[]? | "\(.pluginid) \(.name)"' "$STOCK" 2>/dev/null | sort > "$TMPD/stock-alerts.txt"
jq -r '.site[].alerts[]? | "\(.pluginid) \(.name)"' "$SURGICAL" 2>/dev/null | sort > "$TMPD/surgical-alerts.txt"

echo "--- Stock alerts ($STOCK) ---"
cat "$TMPD/stock-alerts.txt"

echo "--- Surgical alerts ---"
cat "$TMPD/surgical-alerts.txt"

echo "--- Diff ---"
PARITY_OUT="${BASE}/parity.txt"
mkdir -p "$BASE"
if diff "$TMPD/stock-alerts.txt" "$TMPD/surgical-alerts.txt" | tee "$PARITY_OUT"; then
  echo "PARITY: PASS"
else
  echo "PARITY: FAIL (see $PARITY_OUT)"
  exit 1
fi
