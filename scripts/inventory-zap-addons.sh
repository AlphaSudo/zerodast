#!/usr/bin/env bash
set -euo pipefail
# Inventory the stock zap-stable image addons and output to JSON
IMAGE="${1:-zaproxy/zap-stable:2.17.0}"
OUTDIR="${2:-reports}"
mkdir -p "$OUTDIR"

echo "=== Inventorying $IMAGE ==="

# Count and list installed addons
docker run --rm "$IMAGE" sh -c '
  echo "=== /zap/plugin/ ==="
  ls -1 /zap/plugin/*.zap 2>/dev/null | sort
  echo "=== count ==="
  ls -1 /zap/plugin/*.zap 2>/dev/null | wc -l
' | tee "$OUTDIR/stock-addon-inventory.txt"

# Image size
docker image inspect "$IMAGE" --format='{{.Size}}' \
  > "$OUTDIR/stock-image-size.txt"

# Layer breakdown
docker history "$IMAGE" --no-trunc \
  > "$OUTDIR/stock-image-layers.txt"

echo "Inventory saved to $OUTDIR/"
