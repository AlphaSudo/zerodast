#!/usr/bin/env bash
set -euo pipefail
# Compare stock vs surgical benchmark outputs.
# Pass criteria:
# - No missing Medium/High/Critical alerts in the surgical image.
# - Informational/low diffs are allowed, but documented.
TARGET="${1:?Usage: verify-alert-parity.sh <target-name>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${BENCHMARK_ROOT:-$ROOT_DIR/reports/benchmark}/${TARGET}"

STOCK_IMAGE="${STOCK_IMAGE:-zaproxy/zap-stable:2.17.0}"
SURGICAL_IMAGE="${SURGICAL_IMAGE:-zerodast-scanner:2.17.0}"
PARITY_RUN="${PARITY_RUN:-1}"
STOCK_TAG=$(echo "$STOCK_IMAGE" | tr '/:' '_')
SURGICAL_TAG=$(echo "$SURGICAL_IMAGE" | tr '/:' '_')

STOCK="${STOCK:-$BASE/${STOCK_TAG}/run-${PARITY_RUN}/zap-report.json}"
SURGICAL="${SURGICAL:-$BASE/${SURGICAL_TAG}/run-${PARITY_RUN}/zap-report.json}"

resolve_node_bin() {
  local candidate=""
  if command -v node >/dev/null 2>&1; then
    command -v node
    return 0
  fi

  if [[ -n "${NODE_PATH:-}" && -x "${NODE_PATH:-}" ]]; then
    printf '%s\n' "$NODE_PATH"
    return 0
  fi

  for candidate in \
    /mnt/c/Users/CM/AppData/Local/fnm_multishells/*/node.exe \
    /mnt/c/Users/CM/AppData/Roaming/fnm/node-versions/*/installation/node.exe \
    "/mnt/c/Program Files/nodejs/node.exe"
  do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

NODE_BIN="${NODE_BIN:-$(resolve_node_bin || true)}"

host_node_path() {
  local path="$1"
  if [[ "${NODE_BIN:-}" == *.exe ]] && command -v wslpath >/dev/null 2>&1; then
    wslpath -w "$path"
  else
    printf '%s\n' "$path"
  fi
}

run_host_node() {
  local arg=""
  local converted=()
  if [[ -z "${NODE_BIN:-}" ]]; then
    echo "Node.js is required for verify-alert-parity.sh but was not found. Set NODE_BIN or NODE_PATH." >&2
    exit 1
  fi
  for arg in "$@"; do
    if [[ "$arg" == /* ]]; then
      converted+=("$(host_node_path "$arg")")
    else
      converted+=("$arg")
    fi
  done
  "$NODE_BIN" "${converted[@]}"
}

if [[ ! -f "$STOCK" ]]; then
  echo "Missing stock report: $STOCK" >&2
  exit 1
fi

if [[ ! -f "$SURGICAL" ]]; then
  echo "Missing surgical report: $SURGICAL" >&2
  exit 1
fi

TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

ALL_STOCK="$TMPD/stock-all.txt"
ALL_SURGICAL="$TMPD/surgical-all.txt"
HIGH_STOCK="$TMPD/stock-mediumplus.txt"
HIGH_SURGICAL="$TMPD/surgical-mediumplus.txt"
HIGH_TYPES_STOCK="$TMPD/stock-mediumplus-types.txt"
HIGH_TYPES_SURGICAL="$TMPD/surgical-mediumplus-types.txt"
PARITY_OUT="${BASE}/parity.txt"

extract_all() {
  local report="$1"
  run_host_node -e '
    const fs = require("fs");
    const report = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const sites = Array.isArray(report.site) ? report.site : report.site ? [report.site] : [];
    const rows = [];
    for (const site of sites) {
      for (const alert of site.alerts || []) {
        const uris = [...new Set((alert.instances || []).map((instance) => instance.uri).filter(Boolean))].sort();
        rows.push([
          String(alert.pluginid ?? ""),
          String(alert.name ?? ""),
          String(Number.parseInt(alert.riskcode, 10) || 0),
          String(alert.riskdesc ?? ""),
          String(Number.parseInt(alert.confidence, 10) || 0),
          String(Number.parseInt(alert.count, 10) || 0),
          uris.join(","),
        ].join("\t"));
      }
    }
    rows.sort();
    process.stdout.write(rows.join("\n"));
    if (rows.length) process.stdout.write("\n");
  ' "$report"
}

extract_medium_plus() {
  local report="$1"
  run_host_node -e '
    const fs = require("fs");
    const report = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const sites = Array.isArray(report.site) ? report.site : report.site ? [report.site] : [];
    const rows = [];
    for (const site of sites) {
      for (const alert of site.alerts || []) {
        const riskcode = Number.parseInt(alert.riskcode, 10) || 0;
        if (riskcode < 2) continue;
        const uris = [...new Set((alert.instances || []).map((instance) => instance.uri).filter(Boolean))].sort();
        rows.push([
          String(alert.pluginid ?? ""),
          String(alert.name ?? ""),
          String(riskcode),
          String(alert.riskdesc ?? ""),
          String(Number.parseInt(alert.count, 10) || 0),
          uris.join(","),
        ].join("\t"));
      }
    }
    rows.sort();
    process.stdout.write(rows.join("\n"));
    if (rows.length) process.stdout.write("\n");
  ' "$report"
}

extract_medium_plus_types() {
  local report="$1"
  run_host_node -e '
    const fs = require("fs");
    const report = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const sites = Array.isArray(report.site) ? report.site : report.site ? [report.site] : [];
    const rows = [];
    for (const site of sites) {
      for (const alert of site.alerts || []) {
        const riskcode = Number.parseInt(alert.riskcode, 10) || 0;
        if (riskcode < 2) continue;
        rows.push([
          String(alert.pluginid ?? ""),
          String(alert.name ?? ""),
          String(riskcode),
          String(alert.riskdesc ?? ""),
        ].join("\t"));
      }
    }
    const unique = [...new Set(rows)].sort();
    process.stdout.write(unique.join("\n"));
    if (unique.length) process.stdout.write("\n");
  ' "$report"
}

echo "=== Alert parity check for $TARGET (run $PARITY_RUN) ==="

extract_all "$STOCK" > "$ALL_STOCK"
extract_all "$SURGICAL" > "$ALL_SURGICAL"
extract_medium_plus "$STOCK" > "$HIGH_STOCK"
extract_medium_plus "$SURGICAL" > "$HIGH_SURGICAL"
extract_medium_plus_types "$STOCK" > "$HIGH_TYPES_STOCK"
extract_medium_plus_types "$SURGICAL" > "$HIGH_TYPES_SURGICAL"

ALL_DIFF="$TMPD/all.diff"
HIGH_DIFF="$TMPD/mediumplus.diff"
HIGH_TYPES_MISSING="$TMPD/mediumplus-missing-types.txt"
HIGH_TYPES_EXTRA="$TMPD/mediumplus-extra-types.txt"
diff -u "$ALL_STOCK" "$ALL_SURGICAL" > "$ALL_DIFF" || true
diff -u "$HIGH_STOCK" "$HIGH_SURGICAL" > "$HIGH_DIFF" || true
comm -23 "$HIGH_TYPES_STOCK" "$HIGH_TYPES_SURGICAL" > "$HIGH_TYPES_MISSING" || true
comm -13 "$HIGH_TYPES_STOCK" "$HIGH_TYPES_SURGICAL" > "$HIGH_TYPES_EXTRA" || true

stock_all_count=$(wc -l < "$ALL_STOCK")
surgical_all_count=$(wc -l < "$ALL_SURGICAL")
stock_high_count=$(wc -l < "$HIGH_STOCK")
surgical_high_count=$(wc -l < "$HIGH_SURGICAL")

{
  echo "# Alert Parity Report"
  echo
  echo "- Target: $TARGET"
  echo "- Run: $PARITY_RUN"
  echo "- Stock report: $STOCK"
  echo "- Surgical report: $SURGICAL"
  echo "- Stock alert entries: $stock_all_count"
  echo "- Surgical alert entries: $surgical_all_count"
  echo "- Stock Medium+ entries: $stock_high_count"
  echo "- Surgical Medium+ entries: $surgical_high_count"
  echo
  echo "## Missing Medium+ Alert Types"
  echo
  if [[ -s "$HIGH_TYPES_MISSING" ]]; then
    cat "$HIGH_TYPES_MISSING"
  else
    echo "No missing Medium/High/Critical alert types."
  fi
  echo
  echo "## Extra Medium+ Alert Types"
  echo
  if [[ -s "$HIGH_TYPES_EXTRA" ]]; then
    cat "$HIGH_TYPES_EXTRA"
  else
    echo "No extra Medium/High/Critical alert types."
  fi
  echo
  echo "## Medium+ Detail Diff"
  echo
  if [[ -s "$HIGH_DIFF" ]]; then
    cat "$HIGH_DIFF"
  else
    echo "No Medium/High/Critical detail diff."
  fi
  echo
  echo "## Full Diff"
  echo
  if [[ -s "$ALL_DIFF" ]]; then
    cat "$ALL_DIFF"
  else
    echo "No alert entry diff."
  fi
} > "$PARITY_OUT"

echo "--- Missing Medium+ alert types ---"
if [[ -s "$HIGH_TYPES_MISSING" ]]; then
  cat "$HIGH_TYPES_MISSING"
else
  echo "No missing Medium/High/Critical alert types."
fi

echo "--- Medium+ detail diff ---"
if [[ -s "$HIGH_DIFF" ]]; then
  cat "$HIGH_DIFF"
else
  echo "No Medium/High/Critical detail diff."
fi

echo "--- Full diff summary ---"
if [[ -s "$ALL_DIFF" ]]; then
  echo "Informational/low or metadata differences detected; see $PARITY_OUT"
else
  echo "No alert entry diff."
fi

if [[ -s "$HIGH_TYPES_MISSING" ]]; then
  echo "PARITY: FAIL (missing Medium+ alert types; see $PARITY_OUT)"
  exit 1
fi

echo "PARITY: PASS (no missing Medium+ alert types; see $PARITY_OUT for detail diffs)"
