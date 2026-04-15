# ZeroDAST V2 Benchmark Summary

Date: April 15, 2026

## Scope

This summary captures the post-merge V2 benchmark validation run for the built-in `demo-core` target on merged `main`.

It is intentionally conservative:

- it reports measured results only
- it reflects a single validated `demo-core` proof run
- it does **not** claim fleet-wide V2 validation

## Environment

- Repo state: merged `main`
- Demo app image: `zerodast-demo-app:main-validate`
- Stock scanner image: `zaproxy/zap-stable:2.17.0`
- V2 scanner image: `zerodast-scanner:2.17.0`
- Scan config: `security/zap/automation.yaml`
- Profile override: none (`SCAN_PROFILE=""`)

## Commands Used

```bash
CONTAINER_ENGINE_BIN="/mnt/c/Users/CM/AppData/Local/Programs/Podman/podman.exe" \
  bash scripts/build-surgical-image.sh

CONTAINER_ENGINE_BIN="/mnt/c/Users/CM/AppData/Local/Programs/Podman/podman.exe" \
  WORKSPACE_DIR="$(pwd)" \
  APP_IMAGE="zerodast-demo-app:main-validate" \
  ZAP_CONFIG_PATH="$(pwd)/security/zap/automation.yaml" \
  SCHEMA_SQL="$(pwd)/db/seed/schema.sql" \
  MOCK_DATA_SQL="$(pwd)/db/seed/mock_data.sql" \
  AUTH_BOOTSTRAP_MODE="adapter" \
  AUTH_ADAPTER_SCRIPT="$(pwd)/scripts/auth-adapters/json-token-login.sh" \
  AUTH_TOKEN_PATH="/tmp/zap-auth-token.txt" \
  ADMIN_AUTH_TOKEN_PATH="/tmp/zap-auth-token-admin.txt" \
  REPORTS_DIR="$(pwd)/reports" \
  RUNS=1 \
  bash scripts/benchmark-ab.sh demo-core

bash scripts/verify-alert-parity.sh demo-core
```

## Measured Results

### Runtime

| Variant | Seconds |
|---|---:|
| Stock ZAP (`zaproxy/zap-stable:2.17.0`) | 527 |
| V2 surgical image (`zerodast-scanner:2.17.0`) | 478 |

Runtime delta:

- Absolute improvement: `49` seconds
- Relative improvement: about `9.3%`

### Image Size

| Variant | Size |
|---|---:|
| Stock ZAP (`zaproxy/zap-stable:2.17.0`) | 2.23 GB |
| V2 surgical image (`zerodast-scanner:2.17.0`) | 1.36 GB |

Image-size delta:

- Absolute reduction: about `0.87 GB`
- Relative reduction: about `39%`

### Parity

The validated `demo-core` benchmark run preserved the Medium+ acceptance gate:

- `verify-alert-parity.sh demo-core`: `PASS`
- missing Medium+ alert types: `0`
- extra Medium+ alert types: `0`

The specific parity regression that previously blocked V2, ZAP rule `40026` (`Cross Site Scripting (DOM Based)`), was restored after exposing `firefox` in the surgical image so the browser-backed DOM XSS path matched stock behavior.

## Evidence Files

The validation run produced these artifacts:

- `reports/benchmark/image-sizes.md`
- `reports/benchmark/demo-core/zaproxy_zap-stable_2.17.0/run-1/timing.json`
- `reports/benchmark/demo-core/zerodast-scanner_2.17.0/run-1/timing.json`
- `reports/benchmark/demo-core/parity.txt`

The corresponding surgical proof run also produced:

- `reports/surgical-proof-demo-core/installed-addon-inventory.txt`
- `reports/surgical-proof-demo-core/memory-samples.txt`
- `reports/surgical-proof-demo-core/zap-report.json`
- `reports/surgical-evidence-summary.json`
- `reports/surgical-evidence-summary.md`

## What This Proves

- the V2 surgical image builds on merged `main`
- the demo-core scan path works on merged `main`
- the V2 surgical image is materially smaller than stock
- the demo-core proof run was faster than stock in this measured run
- the demo-core proof run preserved the Medium+ parity gate

## What It Does Not Prove Yet

- fleet-wide V2 parity across external targets
- profiled-vs-unprofiled behavior on the broader target set
- long-run stability across repeated nightly executions
- generalized performance gains outside `demo-core`
