#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="${ROOT_DIR}/config.json"
REPORT_DIR="${ROOT_DIR}/reports"
MODE="${ZERODAST_MODE:-pr}"

mkdir -p "${REPORT_DIR}"
find "${REPORT_DIR}" -maxdepth 1 -type f -delete

node "${ROOT_DIR}/prepare-openapi.js" "${CONFIG_PATH}" "${MODE}" > "${REPORT_DIR}/prepared-config.json"

cat > "${REPORT_DIR}/summary.md" <<EOF
# ZeroDAST Prototype Summary

- Mode: ${MODE}
- Config: ${CONFIG_PATH}
- Status: prototype runner executed

This prototype intentionally stops at proving install shape and orchestration ownership.
EOF

node "${ROOT_DIR}/verify-report.js" "${REPORT_DIR}/summary.md"
