# ZeroDAST V2 External Target Benchmarks

Date: April 16, 2026

## Scope

This summary captures two benchmark passes for the four external Model 1 validation targets:

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

The two benchmark modes are intentionally kept separate:

- a **local same-environment** pass using the target branches directly from the local machine
- a **hosted GitHub Actions** pass using dedicated benchmark branches and GitHub-hosted runners

## Local Same-Environment Benchmark

### Environment

- Stock scanner image: `zaproxy/zap-stable:2.17.0`
- V2 scanner image: `localhost/zerodast-scanner:2.17.0`
- Shared surgical image size in this rebuilt form: `1.01 GB`
- Stock image size reference: `2.23 GB`
- Target source: each target's existing `zerodast-install` branch
- Scan mode: nightly-style target scan flow using each target repo's own `zerodast/run-scan.sh`

### Commands Used

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

### Measured Results

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

### Interpretation

- The rebuilt shared surgical image preserved the Medium+ gate on all four external targets.
- The scanner path improved clearly on `nocodb`, `directus`, and `medusa`.
- `strapi` is the main nuance case: the scanner phase was effectively flat, but total wall time still improved substantially in the full target flow.
- The rebuilt shared surgical image stayed materially smaller than stock while restoring the Directus `10003` parity regression that had appeared in the earlier self-upgrading image.

### Evidence Location

The raw benchmark artifacts from this pass are intentionally kept out of the repo and were generated under the local temp workspace:

- `.tmp/external-target-benchmarks/summary.json`
- `.tmp/external-target-benchmarks/<target>/stock/`
- `.tmp/external-target-benchmarks/<target>/surgical/`
- `.tmp/external-target-benchmarks/parity-<target>/parity.txt`

## Hosted GitHub Actions Benchmark

### Environment

- Branch used in each target repo: `codex/gha-benchmark`
- Scanner selection: `workflow_dispatch` input `zap_variant`
- Stock scanner image: `zaproxy/zap-stable:2.17.0`
- Hosted V2 scanner image: `zerodast-scanner:ci-benchmark`
- Runner type: GitHub-hosted `ubuntu-22.04`

### Hosted Runner Time

This table uses the GitHub Actions job start/finish timestamps for the hosted benchmark branches. It is the best measure of total hosted wall time for the target workflow.

| Target | Stock hosted wall seconds | V2 hosted wall seconds | Delta | Change |
|---|---:|---:|---:|---:|
| `nocodb` | 388 | 320 | -68s | -17.5% |
| `strapi` | 401 | 383 | -18s | -4.5% |
| `directus` | 365 | 327 | -38s | -10.4% |
| `medusa` | 329 | 335 | +6s | +1.8% |

### Hosted Scanner-Phase Time

This table uses each hosted run's `metrics.json` `coldRunSeconds` value.

| Target | Stock hosted scan seconds | V2 hosted scan seconds | Delta | Change |
|---|---:|---:|---:|---:|
| `nocodb` | 311 | 213 | -98s | -31.5% |
| `strapi` | 223 | 208 | -15s | -6.7% |
| `directus` | 315 | 256 | -59s | -18.7% |
| `medusa` | 90 | 76 | -14s | -15.6% |

### Hosted Medium+ Parity

| Target | Result | Notes |
|---|---|---|
| `nocodb` | `PASS` | No missing Medium+ alert types; Medium+ detail drift remains present |
| `strapi` | `PASS` | No missing Medium+ alert types; no Medium+ detail diff |
| `directus` | `PASS` | No missing Medium+ alert types; no Medium+ detail diff |
| `medusa` | `PASS` | No missing Medium+ alert types; no Medium+ detail diff |

### Hosted Interpretation

- The hosted GitHub Actions benchmark also preserved the Medium+ gate on all four external targets.
- The hosted scanner path improved on all four targets.
- `medusa` is the main hosted nuance case: scan time improved, but total GitHub-runner wall time was slightly worse in this measured pass.
- `nocodb` still shows acceptable Medium+ detail drift in hosted runs, but no missing Medium+ alert types.

### Hosted Evidence Location

The hosted benchmark artifacts were downloaded locally for analysis under:

- `.tmp/gha-hosted-benchmark/summary.json`
- `.tmp/gha-hosted-benchmark/parity-summary.json`
- `.tmp/gha-hosted-benchmark/<target>/<variant>/`

Hosted workflow runs used for this benchmark:

- `nocodb` stock: [run 24506957601](https://github.com/AlphaSudo/nocodb/actions/runs/24506957601)
- `nocodb` surgical: [run 24506958587](https://github.com/AlphaSudo/nocodb/actions/runs/24506958587)
- `strapi` stock: [run 24506959810](https://github.com/AlphaSudo/strapi/actions/runs/24506959810)
- `strapi` surgical: [run 24506960955](https://github.com/AlphaSudo/strapi/actions/runs/24506960955)
- `directus` stock: [run 24506962271](https://github.com/AlphaSudo/directus/actions/runs/24506962271)
- `directus` surgical: [run 24506963354](https://github.com/AlphaSudo/directus/actions/runs/24506963354)
- `medusa` stock: [run 24506964537](https://github.com/AlphaSudo/medusa/actions/runs/24506964537)
- `medusa` surgical: [run 24506965841](https://github.com/AlphaSudo/medusa/actions/runs/24506965841)

## Profiled vs Unprofiled Benchmark

### Environment

- Scanner image: `localhost/zerodast-scanner:2.17.0`
- Comparison mode:
  - unprofiled surgical
  - profiled surgical using `security/profiles/target-*.yaml`
- Profile merge source: `scripts/build-profiled-automation.js`
- Runner context: local same-environment target runs on the existing `zerodast-install` branches

### Profiled Scanner-Phase Time

This table compares profiled surgical runs against unprofiled surgical runs.

| Target | Unprofiled scan seconds | Profiled scan seconds | Delta | Change |
|---|---:|---:|---:|---:|
| `nocodb` | 179 | 154 | -25s | -14.0% |
| `strapi` | 467 | 180 | -287s | -61.5% |
| `directus` | 197 | 239 | +42s | +21.3% |
| `medusa` | 99 | 80 | -19s | -19.2% |

### Profiled Wall Time

| Target | Unprofiled wall seconds | Profiled wall seconds | Delta | Change |
|---|---:|---:|---:|---:|
| `nocodb` | 245 | 213 | -32s | -13.1% |
| `strapi` | 637 | 226 | -411s | -64.5% |
| `directus` | 247 | 293 | +46s | +18.6% |
| `medusa` | 581 | 391 | -190s | -32.7% |

### Profiled Medium+ Parity

| Target | Result | Notes |
|---|---|---|
| `nocodb` | `PASS` | No missing Medium+ alert types; Medium+ detail drift remains present |
| `strapi` | `PASS` | No missing Medium+ alert types; no Medium+ detail diff |
| `directus` | `PASS` | No missing Medium+ alert types; no Medium+ detail diff |
| `medusa` | `PASS` | No missing Medium+ alert types; Medium+ detail drift remains present |

### Profiled Interpretation

- Profiled mode preserved the Medium+ gate on all four external targets versus unprofiled surgical runs.
- `nocodb`, `strapi`, and `medusa` all improved materially in the measured pass.
- `directus` is the current exception: it preserved parity, but got slower in both scan time and total wall time.
- That means the profile system is now **correctness-validated**, but not yet **universally performance-validated** across the full external target set.

### Profiled Evidence Location

- `.tmp/profiled-target-benchmarks/summary.json`
- `.tmp/profiled-target-benchmarks/parity-summary.json`
- `.tmp/profiled-target-benchmarks/<target>/<variant>/`

Profiled benchmark provenance note:

- This pass was executed locally from the existing `zerodast-install` target branches, not from GitHub-hosted runners.
- There are therefore **no GitHub Actions run links for the profiled-vs-unprofiled runs themselves** yet.
- The closest hosted comparison we currently have is the stock-vs-surgical benchmark above, which used these GitHub Actions runs:
- `nocodb` stock: [run 24506957601](https://github.com/AlphaSudo/nocodb/actions/runs/24506957601)
- `nocodb` surgical: [run 24506958587](https://github.com/AlphaSudo/nocodb/actions/runs/24506958587)
- `strapi` stock: [run 24506959810](https://github.com/AlphaSudo/strapi/actions/runs/24506959810)
- `strapi` surgical: [run 24506960955](https://github.com/AlphaSudo/strapi/actions/runs/24506960955)
- `directus` stock: [run 24506962271](https://github.com/AlphaSudo/directus/actions/runs/24506962271)
- `directus` surgical: [run 24506963354](https://github.com/AlphaSudo/directus/actions/runs/24506963354)
- `medusa` stock: [run 24506964537](https://github.com/AlphaSudo/medusa/actions/runs/24506964537)
- `medusa` surgical: [run 24506965841](https://github.com/AlphaSudo/medusa/actions/runs/24506965841)
- If we want run URLs here later, we need a dedicated hosted benchmark lane for profiled vs unprofiled similar to the hosted stock-vs-surgical benchmark above.

## What This Proves

- the current shared V2 surgical image can be benchmarked successfully on the four external validation targets
- the rebuilt image preserves the Medium+ parity gate across `nocodb`, `strapi`, `directus`, and `medusa`
- the rebuilt image is not just demo-core-only evidence anymore; the broader target set now has both same-environment and hosted-runner benchmark data
- the profile system preserves the Medium+ gate across the four external validation targets when compared to unprofiled surgical runs

## What It Does Not Prove Yet

- long-run stability across repeated hosted nightly executions
- that the current target profiles are performance wins on every target without further tuning
- that every future target will benefit equally from the shared surgical image
