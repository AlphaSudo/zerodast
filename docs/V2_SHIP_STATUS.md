# ZeroDAST V2 Ship Status

Date: April 14, 2026

## Current state

The V2 surgical-image/tooling path is implemented and locally runnable, but it is **not ready for a "parity achieved" claim yet**.

What is in place:

- `ZAP_IMAGE` override support in `security/run-dast-env.sh`
- `SCAN_PROFILE` merge support without overwriting the tracked automation file
- `CAPTURE_ZAP_INTERNALS` and `CAPTURE_MEMORY` hooks
- benchmark, parity, inventory, image-build, and surgical-evidence scripts
- safer host-side Node resolution for mixed Windows/WSL environments

What is still blocking a ready-to-ship V2 claim:

- `scripts/verify-alert-parity.sh demo-core` still reports missing Medium+ alert type `40026` (`Cross Site Scripting (DOM Based)`) in the surgical image run

## Commands run locally

```bash
npm ci --prefix scripts
CONTAINER_ENGINE_BIN="/mnt/c/Users/CM/AppData/Local/Programs/Podman/podman.exe" bash scripts/inventory-zap-addons.sh
CONTAINER_ENGINE_BIN="/mnt/c/Users/CM/AppData/Local/Programs/Podman/podman.exe" bash scripts/build-surgical-image.sh
CONTAINER_ENGINE_BIN="/mnt/c/Users/CM/AppData/Local/Programs/Podman/podman.exe" RUNS=1 bash scripts/benchmark-ab.sh demo-core
bash scripts/verify-alert-parity.sh demo-core
CONTAINER_ENGINE_BIN="/mnt/c/Users/CM/AppData/Local/Programs/Podman/podman.exe" CAPTURE_ZAP_INTERNALS=true CAPTURE_MEMORY=true REPORTS_DIR="$(pwd)/reports/surgical-proof-demo-core" bash security/run-dast-env.sh
node scripts/build-surgical-evidence.js "C:\\Java Developer\\DAST"
```

## Measured outputs

- Stock image size: `2.23 GB`
- Surgical image size: `1.37 GB`
- Surgical installed addon inventory count: `45`
- Surgical demo-core peak memory observed: `356.3 MiB`
- Surgical demo-core runtime from `reports/surgical-proof-demo-core/timing.json`: `421` seconds

## Acceptance status

- Bash syntax checks: pass
- Node syntax checks: pass
- Surgical image build: pass
- `zap.sh -cmd -version`: pass
- Demo-core benchmark run: pass
- Surgical evidence generation: pass
- Medium+ parity on demo-core: **fail**

## Notes on semantics

- `CAPTURE_ZAP_INTERNALS` currently captures **installed addon inventory** from the scan image, not a live loaded-class inventory.
- The parity script treats **missing Medium+ alert types** as failures and records URI/count drift separately.
- Current workflows remain stock-image / no-profile by default; V2 behavior is opt-in.
