# ZeroDAST V2 checklist (from `docs/blog/implementation_plan_2`)

Use this list to track the three phases. Out-of-scope for V2 per plan: reimplementing ZAP rules, validation layer, custom JRE/jlink.

## Phase 1 — Surgical image

- [x] Run `bash scripts/inventory-zap-addons.sh` (Docker/Podman) → `reports/stock-addon-inventory.txt` and related files
- [x] Build surgical image: `bash scripts/build-surgical-image.sh` → `zerodast-scanner:2.17.0`, `reports/benchmark/image-sizes.md`
- [x] Confirm `zap.sh -cmd -version` in container succeeds (script prints this)
- [x] Wire `ZAP_IMAGE` in `security/run-dast-env.sh` (default unchanged) — **done in repo**
- [~] Per target / environment: export fleet env for `security/run-dast-env.sh`, then `bash scripts/benchmark-ab.sh <target>` and `bash scripts/verify-alert-parity.sh <target>` — **demo-core rerun locally on April 15, 2026; broader target set still pending**
- [~] Record Medium/High/Critical parity (informational diffs acceptable if documented) — **demo-core now passes; broader target set still pending**

## Phase 2 — Full surgical scan evidence

- [~] Run fleet with `ZAP_IMAGE=zerodast-scanner:2.17.0`, `CAPTURE_ZAP_INTERNALS=true`, optional `CAPTURE_MEMORY=true`, per-target `REPORTS_DIR=reports/surgical-proof-<target>` — **hooks implemented in `run-dast-env.sh`; demo-core rerun completed locally and now shows PASS in `reports/surgical-evidence-summary.*`**
- [x] After runs: `node scripts/build-surgical-evidence.js` from the repo root → `reports/surgical-evidence-summary.json` / `.md`
- [ ] Optional: add `parity-vs-stock.diff` per target (not automated yet; compare to frozen `tmp-ci-proof-*` stock runs if available)
- [ ] Note: `CAPTURE_ZAP_INTERNALS` currently captures **installed addon inventory** from the scan image, not a live loaded-class inventory

## Phase 3 — Target profiles

- [ ] `npm ci --prefix scripts` where `build-profiled-automation.js` runs (CI: **done**)
- [ ] Base + target YAML under `security/profiles/` — **done in repo**
- [ ] Enable per environment: `SCAN_PROFILE=security/profiles/target-<name>.yaml` (empty = default automation only)
- [ ] Profiled vs unprofiled A/B on surgical image; document timing and Medium+ parity
- [ ] Optional: `node scripts/build-target-profile.js <name> <zap-report.json> <out.yaml>` to summarize fired rules from a report

## CI / ops notes

- Nightly and PR workflows set `ZAP_IMAGE` and `SCAN_PROFILE` explicitly (defaults match previous behavior: stock image, no profile).
- Matrix fleet (`demo-core`, `medusa`, …) is **not** in current workflows; add a matrix job when fleet scans are ready.
- Local April 15, 2026 proof summary:
  - Stock image size: `2.23 GB`
  - Surgical image size: `1.36 GB`
  - Surgical installed addon inventory: `45`
  - Surgical demo-core benchmark parity: `PASS` for missing Medium+ alert types
  - Surgical demo-core evidence summary: `PASS` for Medium+ parity vs frozen stock
  - Key fix: expose `firefox` in the surgical image so the DOM XSS rule can run the same browser-backed path as stock
