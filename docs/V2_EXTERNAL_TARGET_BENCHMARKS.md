# ZeroDAST V2 External Target Benchmarks

Date: April 15, 2026

## Scope

This summary captures a same-environment stock-vs-surgical benchmark run for the four external Model 1 validation targets:

- `nocodb`
- `strapi`
- `directus`
- `medusa`

It reflects the current implemented V2 shape:

- one shared surgical scanner image
- no per-target scanner image generation
- target-specific app/auth setup from each target's existing `zerodast-install` branch

The goal here is narrow and conservative:

- measure stock ZAP vs the rebuilt shared V2 surgical image on the same targets
- confirm the Medium+ parity gate still holds
- separate scanner-phase timing from total wall-clock timing

## Environment

- Stock scanner image: `zaproxy/zap-stable:2.17.0`
- V2 scanner image: `localhost/zerodast-scanner:2.17.0`
- Shared surgical image size in this rebuilt form: `1.01 GB`
- Stock image size reference: `2.23 GB`
- Target source: each target's existing `zerodast-install` branch
- Scan mode: nightly-style target scan flow using each target repo's own `zerodast/run-scan.sh`

## Commands Used

Each target was run twice from its own `zerodast-install` branch checkout: once with stock ZAP and once with the rebuilt surgical image.

```bash
ZERODAST_MODE=nightly \
  ZAP_IMAGE="zaproxy/zap-stable:2.17.0" \
  bash zerodast/run-scan.sh

ZERODAST_MODE=nightly \
  ZAP_IMAGE="localhost/zerodast-scanner:2.17.0" \
  bash zerodast/run-scan.sh
```

Parity was then checked against the reports from those same runs:

```bash
BENCHMARK_ROOT="/mnt/c/Java Developer/DAST/.tmp/external-target-benchmarks" \
  STOCK_REPORT="/mnt/c/Java Developer/DAST/.tmp/external-target-benchmarks/<target>/stock/zap-report.json" \
  SURGICAL_REPORT="/mnt/c/Java Developer/DAST/.tmp/external-target-benchmarks/<target>/surgical/zap-report.json" \
  bash scripts/verify-alert-parity.sh "parity-<target>"
```

## Measured Results

### Scanner-Phase Time

This table uses the scan timing emitted by each target run's `metrics.json`. It is the best measure of scanner-path performance.

| Target | Stock scan seconds | V2 scan seconds | Delta | Change |
|---|---:|---:|---:|---:|
| `nocodb` | 174 | 133 | -41s | -23.6% |
| `strapi` | 133 | 135 | +2s | +1.5% |
| `directus` | 254 | 129 | -125s | -49.2% |
| `medusa` | 98 | 84 | -14s | -14.3% |

### Total Wall Time

This table includes target startup, seeding, auth/bootstrap, and post-scan handling in addition to the scan itself. It is the better measure of "how long the whole target validation flow took."

| Target | Stock wall seconds | V2 wall seconds | Delta | Change |
|---|---:|---:|---:|---:|
| `nocodb` | 237 | 196 | -41s | -17.3% |
| `strapi` | 293 | 185 | -108s | -36.9% |
| `directus` | 304 | 179 | -125s | -41.1% |
| `medusa` | 532 | 416 | -116s | -21.8% |

### Medium+ Parity

| Target | Result | Notes |
|---|---|---|
| `nocodb` | `PASS` | No missing Medium+ alert types; Medium+ detail drift on `10098` URI/count coverage |
| `strapi` | `PASS` | No missing Medium+ alert types; no Medium+ detail diff |
| `directus` | `PASS` | No missing Medium+ alert types; no Medium+ detail diff |
| `medusa` | `PASS` | No missing Medium+ alert types; no Medium+ detail diff |

## Interpretation

- The rebuilt shared surgical image preserved the Medium+ gate on all four external targets.
- The scanner path improved clearly on `nocodb`, `directus`, and `medusa`.
- `strapi` is the main nuance case: the scanner phase was effectively flat, but total wall time still improved substantially in the full target flow.
- The rebuilt shared surgical image stayed materially smaller than stock while restoring the Directus `10003` parity regression that had appeared in the earlier self-upgrading image.

## Evidence Location

The raw benchmark artifacts from this pass are intentionally kept out of the repo and were generated under the local temp workspace:

- `.tmp/external-target-benchmarks/summary.json`
- `.tmp/external-target-benchmarks/<target>/stock/`
- `.tmp/external-target-benchmarks/<target>/surgical/`
- `.tmp/external-target-benchmarks/parity-<target>/parity.txt`

## What This Proves

- the current shared V2 surgical image can be benchmarked successfully on the four external validation targets
- the rebuilt image preserves the Medium+ parity gate across `nocodb`, `strapi`, `directus`, and `medusa`
- the rebuilt image is not just demo-core-only evidence anymore; the broader target set now has same-environment benchmark data

## What It Does Not Prove Yet

- hosted GitHub Actions timing for the surgical image on each external target
- profiled-vs-unprofiled performance on the broader target set
- long-run stability across repeated hosted nightly executions
- that every future target will benefit equally from the shared surgical image
