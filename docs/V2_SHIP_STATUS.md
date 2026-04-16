# ZeroDAST V2 Ship Status

Date: April 16, 2026

## Current state

The V2 surgical-image/tooling path is implemented and locally runnable. The refreshed `demo-core` proof restores the Medium+ parity gate, and the rebuilt shared surgical image now also passes the same Medium+ gate on the four external targets `nocodb`, `strapi`, `directus`, and `medusa`.

For the dedicated measured before/after benchmark on merged `main`, see [V2_BENCHMARK_SUMMARY.md](V2_BENCHMARK_SUMMARY.md). For the same-environment stock-vs-surgical benchmark on the four external validation targets, see [V2_EXTERNAL_TARGET_BENCHMARKS.md](V2_EXTERNAL_TARGET_BENCHMARKS.md).

What is in place:

- one shared surgical scanner image (`zerodast-scanner:2.17.0`) used across targets
- `ZAP_IMAGE` override support in `security/run-dast-env.sh`
- `SCAN_PROFILE` merge support without overwriting the tracked automation file
- `CAPTURE_ZAP_INTERNALS` and `CAPTURE_MEMORY` hooks
- benchmark, parity, inventory, image-build, and surgical-evidence scripts
- safer host-side Node resolution for mixed Windows/WSL environments

What is still blocking a ready-to-ship V2 claim:

- profiled-vs-unprofiled validation now passes the Medium+ gate on the broader target set both locally and on GitHub-hosted runners, and the tuned `directus` profile is back to being a positive hosted result rather than a regression
- public messaging should continue to distinguish the shared surgical image that exists today from any future per-target image generation idea

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

External-target confirmation flow on April 15, 2026 used the existing `zerodast-install` target branches with the rebuilt shared surgical image forced through `ZAP_IMAGE`:

```bash
ZAP_IMAGE="localhost/zerodast-scanner:2.17.0" bash zerodast/run-scan.sh
```

Targets revalidated under that flow:

- `nocodb`
- `strapi`
- `directus`
- `medusa`

## Measured outputs

- Stock image size: `2.23 GB`
- Rebuilt surgical image size after add-on realignment: `1.01 GB`
- Rebuilt surgical installed addon inventory count: `42`
- Surgical demo-core benchmark parity: `PASS` for missing Medium+ alert types
- Surgical evidence summary parity vs frozen stock: `PASS`
- The DOM XSS fix came from exposing `firefox` in the surgical image so the browser-backed rule path matches stock
- The Directus `10003` parity regression was fixed by removing add-on self-upgrades and keeping the stock `2.17.0` add-on set in the surgical image
- External-target Medium+ parity after the rebuild: `4/4 PASS` on `nocodb`, `strapi`, `directus`, and `medusa`
- External-target stock-vs-surgical benchmark pass now exists for `nocodb`, `strapi`, `directus`, and `medusa`, with same-environment timing plus Medium+ parity results
- Hosted GitHub Actions stock-vs-surgical benchmark pass now also exists for `nocodb`, `strapi`, `directus`, and `medusa`, with `4/4 PASS` on the Medium+ parity gate
- Profiled-vs-unprofiled surgical benchmark pass now also exists for `nocodb`, `strapi`, `directus`, and `medusa`, with `4/4 PASS` on the Medium+ parity gate in both local and hosted GitHub Actions runs

## Acceptance status

- Bash syntax checks: pass
- Node syntax checks: pass
- Surgical image build: pass
- `zap.sh -cmd -version`: pass
- Demo-core benchmark run: pass
- Surgical evidence generation: pass
- Medium+ parity on demo-core: **pass**
- Medium+ parity on external target reruns: **pass** (`4/4`)

## Notes on semantics

- `CAPTURE_ZAP_INTERNALS` currently captures **installed addon inventory** from the scan image, not a live loaded-class inventory.
- The parity script treats **missing Medium+ alert types** as failures and records URI/count drift separately.
- Current workflows remain stock-image / no-profile by default; V2 behavior is opt-in.
- The surgical evidence run captures memory samples separately from the benchmark run, so timing data and peak memory come from different proof directories unless you standardize that flow later.
- `build-surgical-evidence.js` now reads the repo root from the current working directory instead of accepting an arbitrary path argument.
- The current implementation uses one shared surgical scanner image across targets. Per-target dynamic scanner image generation is still architecture direction, not implemented behavior.
