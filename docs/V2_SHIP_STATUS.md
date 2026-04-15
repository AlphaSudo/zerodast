# ZeroDAST V2 Ship Status

Date: April 15, 2026

## Current state

The V2 surgical-image/tooling path is implemented and locally runnable, and the refreshed `demo-core` proof now restores the Medium+ parity gate. The remaining work is to rerun the broader target set before making any fleet-wide V2 parity claim.

What is in place:

- `ZAP_IMAGE` override support in `security/run-dast-env.sh`
- `SCAN_PROFILE` merge support without overwriting the tracked automation file
- `CAPTURE_ZAP_INTERNALS` and `CAPTURE_MEMORY` hooks
- benchmark, parity, inventory, image-build, and surgical-evidence scripts
- safer host-side Node resolution for mixed Windows/WSL environments

What is still blocking a ready-to-ship V2 claim:

- only `demo-core` has been revalidated after the DOM XSS parity fix
- the broader target set still needs to be rerun under the same V2 proof flow

## Commands run locally

```bash
npm ci --prefix scripts
CONTAINER_ENGINE_BIN="/mnt/c/Users/CM/AppData/Local/Programs/Podman/podman.exe" bash scripts/inventory-zap-addons.sh
CONTAINER_ENGINE_BIN="/mnt/c/Users/CM/AppData/Local/Programs/Podman/podman.exe" bash scripts/build-surgical-image.sh
CONTAINER_ENGINE_BIN="/mnt/c/Users/CM/AppData/Local/Programs/Podman/podman.exe" RUNS=1 bash scripts/benchmark-ab.sh demo-core
bash scripts/verify-alert-parity.sh demo-core
CONTAINER_ENGINE_BIN="/mnt/c/Users/CM/AppData/Local/Programs/Podman/podman.exe" CAPTURE_ZAP_INTERNALS=true CAPTURE_MEMORY=true REPORTS_DIR="$(pwd)/reports/surgical-proof-demo-core" bash security/run-dast-env.sh
node scripts/build-surgical-evidence.js
```

## Measured outputs

- Stock image size: `2.23 GB`
- Surgical image size: `1.36 GB`
- Surgical installed addon inventory count: `45`
- Surgical demo-core benchmark parity: `PASS` for missing Medium+ alert types
- Surgical evidence summary parity vs frozen stock: `PASS`
- The DOM XSS fix came from exposing `firefox` in the surgical image so the browser-backed rule path matches stock

## Acceptance status

- Bash syntax checks: pass
- Node syntax checks: pass
- Surgical image build: pass
- `zap.sh -cmd -version`: pass
- Demo-core benchmark run: pass
- Surgical evidence generation: pass
- Medium+ parity on demo-core: **pass**

## Notes on semantics

- `CAPTURE_ZAP_INTERNALS` currently captures **installed addon inventory** from the scan image, not a live loaded-class inventory.
- The parity script treats **missing Medium+ alert types** as failures and records URI/count drift separately.
- Current workflows remain stock-image / no-profile by default; V2 behavior is opt-in.
- The surgical evidence run captures memory samples separately from the benchmark run, so timing data and peak memory come from different proof directories unless you standardize that flow later.
- `build-surgical-evidence.js` now reads the repo root from the current working directory instead of accepting an arbitrary path argument.
