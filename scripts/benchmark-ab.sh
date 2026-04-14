#!/usr/bin/env bash
set -euo pipefail
# A/B benchmark: same automation run on stock vs surgical image.
# Prerequisite: caller must export WORKSPACE_DIR, APP_IMAGE, ZAP_CONFIG_PATH, and other
# env vars required by security/run-dast-env.sh for the target under test.
TARGET="${1:?Usage: benchmark-ab.sh <target-name>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export WORKSPACE_DIR="${WORKSPACE_DIR:-$ROOT_DIR}"

STOCK_IMAGE="${STOCK_IMAGE:-zaproxy/zap-stable:2.17.0}"
SURGICAL_IMAGE="${SURGICAL_IMAGE:-zerodast-scanner:2.17.0}"
RUNS="${RUNS:-3}"

for IMAGE in "$STOCK_IMAGE" "$SURGICAL_IMAGE"; do
  TAG=$(echo "$IMAGE" | tr '/:' '_')
  for i in $(seq 1 "$RUNS"); do
    OUTDIR="${OUTDIR_ROOT:-$ROOT_DIR/reports/benchmark}/${TARGET}/${TAG}/run-${i}"
    mkdir -p "$OUTDIR"

    echo "=== $IMAGE run $i for $TARGET ==="
    START=$(date +%s)

    ZAP_IMAGE="$IMAGE" \
    REPORTS_DIR="$OUTDIR" \
    bash "$ROOT_DIR/security/run-dast-env.sh"

    END=$(date +%s)
    printf '{"image":"%s","target":"%s","run":%s,"seconds":%s}\n' \
      "$IMAGE" "$TARGET" "$i" "$((END - START))" \
      > "$OUTDIR/timing.json"
  done
done
