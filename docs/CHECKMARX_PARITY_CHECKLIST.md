# ZeroDAST Checkmarx-Parity Transition Checklist

This checklist turns [CHECKMARX_PARITY_ROADMAP.md](C:/Java%20Developer/DAST/docs/CHECKMARX_PARITY_ROADMAP.md) into an execution-oriented transition plan.

It is scoped to the realistic target already defined there:
- **90-95% parity for ZeroDAST's target niche**
- not full Checkmarx platform parity

---

## Phase 1: Role-Aware Auth Coverage

- [x] Confirm admin seed user exists in the demo path and can be bootstrapped in CI
- [x] Add dedicated admin token bootstrap alongside current user bootstrap
- [x] Add admin-only request seeding into the core scan config
- [x] Add post-scan verification that an admin-only route was actually exercised
- [x] Update PR profile to include bounded role-aware auth proof
- [x] Update nightly profile to include richer role-aware coverage
- [x] Prove the feature on the built-in demo app
- [x] Prove the feature on at least one external target with privileged/admin routes
- [x] Re-measure PR timing impact
- [x] Re-measure nightly timing impact
- [x] Update capability docs after implementation

### Phase 1 exit
- [x] PR remains under 10 minutes
- [x] Nightly remains under 15 minutes
- [x] Authenticated + admin path coverage is proven, not assumed

---

## Phase 2: Scan-Quality Uplift Without PR Regression

- [x] Improve delta-to-route mapping quality
- [x] Improve request seeding from OpenAPI and changed endpoints
- [ ] Add stronger per-profile scan budget controls
- [x] Distinguish route exercise from alert-bearing signal in summaries
- [x] Distinguish authenticated route exercise from unauthenticated reach
- [x] Improve artifact summaries for fast PR triage
- [ ] Re-run at least two external targets with the new scan-quality model
- [ ] Compare signal uplift vs timing impact
- [ ] Update benchmark docs with the new evidence

### Phase 2 progress note
- Proven on PR #39 smoke run:
  - `Delta mode: DELTA`
  - `Delta endpoint count: 2`
  - `Delta endpoints observed: 2`
  - `Delta endpoints not observed: 0`
  - observed delta endpoints:
    - `/api/search`
    - `/api/search/preview`
  - PR duration remained bounded:
    - `CI Tests`: `1m 4s`
    - `DAST PR Scan`: `2m 43s`

### Phase 2 exit
- [x] PR remains under 10 minutes
- [x] Nightly remains under 15 minutes
- [ ] Signal quality improves without flattening the time budget

---

## Phase 3: Richer Authentication Adapters

- [x] Define a reusable auth adapter interface
- [x] Add cookie/session auth support
- [ ] Add multi-step login scripting support
- [ ] Add refresh-token/session-refresh handling
- [x] Separate simple seeded auth from richer enterprise-style auth adapters in config/docs
- [x] Improve protected-route validation before scan launch
- [ ] Prove at least three auth styles cleanly
- [ ] Prove at least two non-demo external repos with nontrivial auth adapters
- [ ] Keep browser-grade auth out of PR unless timing proves acceptable
- [ ] Update capabilities and roadmap docs after implementation

### Phase 3 progress note
- Foundation proven in core CI:
  - reusable auth header/value adapter contract added
  - default JSON token adapter wired into PR/nightly/local runtime
  - initial form/cookie adapter added as a first richer auth shape
  - protected-route validation moved to adapter-provided headers
  - admin-route validation moved to adapter-provided headers
- CI proof:
  - `CI Tests #13`: `1m 6s`
  - `DAST PR Scan #13`: `3m 5s`
  - `DAST Nightly #33`: `3m 8s`
  - `DAST Nightly #34`: `4m 46s`
- local developer-loop proof:
  - fast auth-adapter smoke completed in about `46s`
  - validates protected route bootstrap and admin route bootstrap without running ZAP
- dedicated adapter CI smoke proof:
  - `Auth Adapter Smoke #1`: `23s`
  - matrix-backed CI validation now exists for:
    - `json-token-login.sh`
    - `form-cookie-login.sh`
  - both adapter shapes are CI-usable on the built-in demo target
- first external richer-auth proof:
  - Django session-auth profile succeeded on `HackSoftware/Django-Styleguide-Example`
  - new adapter:
    - `json-session-login.sh`
  - validated endpoints:
    - `POST /api/auth/session/login/`
    - `GET /api/auth/me/`
    - `GET /api/users/`
  - auth transport:
    - `Authorization: Session <sessionid>`
  - local cold run:
    - `26s`
  - CI proof:
    - `Django Auth Profile #1`: `92s`
    - auth bootstrap status: `200`
    - protected route validation status: `200`
    - admin route validation status: `200`
  - this proves one non-demo external richer-auth path, but not yet two

### Phase 3 exit
- [x] PR remains under 10 minutes
- [x] Nightly remains under 15 minutes
- [ ] Auth support is materially broader than bearer-token-only flows

---

## Phase 4: API Breadth and Discovery Improvements

- [x] Improve OpenAPI normalization and ingestion reliability
- [ ] Add GraphQL support (`deferred for the current REST-first target slice`)
- [x] Add undocumented-route discovery using requestor/traffic evidence
- [x] Add code/spec-hint-based route discovery where practical
- [x] Add API inventory outputs to artifacts and summaries
- [x] Re-test hard targets where importer weakness previously limited coverage
- [ ] Compare API reach improvement vs timing cost
- [x] Update benchmark docs with the improved API coverage model

### Phase 4 progress note
- Proven on PR #56 smoke run:
  - `CI Tests`: `55s`
  - `DAST PR Scan`: `2m 44s`
  - summary now includes an `API Inventory` section
  - report artifacts now include:
    - `api-inventory.json`
    - `api-inventory.md`
  - inventory signal from the PR artifact:
    - `OpenAPI route count: 11`
    - `OpenAPI operation count: 14`
    - `OpenAPI imported URL count: 15`
    - `Observed OpenAPI routes: 3`
    - `Unobserved OpenAPI routes: 8`
  - current unobserved spec routes were made explicit in the artifact, including:
    - `/api/auth/login`
    - `/api/auth/register`
    - `/api/debug/error`
    - `/api/documents`
    - `/api/documents/{id}`
    - `/api/users`
    - `/api/users/{id}`
    - `/health`
- Proven on the FastAPI hard target follow-up:
  - `Fullstack FastAPI T4 Scan #7`: `3m 44s`
  - seeded request count rose to `10`
  - API alert URI count rose to `14`
  - inventory output on the external target now reports:
    - `OpenAPI route count: 15`
    - `OpenAPI operation count: 23`
    - `Observed OpenAPI routes: 9`
    - `Unobserved OpenAPI routes: 6`
  - this is still not a fixed importer story:
    - `OpenAPI imported URL count: 0`
  - but it is a real hard-target API reach improvement driven by bounded spec-derived request seeding
- Proven on the FastAPI undocumented-route inventory follow-up:
  - `Fullstack FastAPI T4 Scan #9`: `3m 50s`
  - verification and artifact inventory now include:
    - `Undocumented observed routes: 0`
  - this proves the evidence-based undocumented-route inventory path is active in CI
  - it does **not** yet prove discovery of real undocumented API surface on this target
- Proven on the FastAPI code-hinted inventory follow-up:
  - `Fullstack FastAPI T4 Scan #10`: `3m 45s`
  - verification and artifact inventory now include:
    - `Code-hinted routes: 15`
    - `Code-hinted observed routes: 9`
    - `Code-hinted unobserved routes: 6`
    - `Code-hinted routes outside spec: 0`
  - this proves the lightweight code/spec-hint discovery path is active in CI and aligned with the target's documented API surface
  - it does **not** yet prove deep static route analysis across arbitrary frameworks
- Proven on the Petclinic second hard target follow-up:
  - `Petclinic T4 Scan #4`: `5m 9s`
  - verification and artifact inventory now include:
    - `OpenAPI route count: 17`
    - `OpenAPI operation count: 41`
    - `Observed OpenAPI routes: 17`
    - `Unobserved OpenAPI routes: 0`
    - `Undocumented observed routes: 6`
    - `Code-hinted routes: 17`
    - `Code-hinted observed routes: 17`
    - `Code-hinted unobserved routes: 0`
    - `Code-hinted routes outside spec: 1`
  - undocumented observed routes were primarily operational/UI surface:
    - `/actuator/health`
    - `/swagger-ui/*`
  - the one code-hinted route outside spec was:
    - `/api/oops`
  - this gives Phase 4 a second hard-target proof with a very different shape than FastAPI:
    - FastAPI showed partial observed spec reach with remaining gaps
    - Petclinic showed strong spec/hint alignment with operational undocumented surface

### Phase 4 exit
- [x] PR remains under 10 minutes
- [x] Nightly remains under 15 minutes
- [x] API coverage improves materially on at least one hard target
- [x] Phase 4 is complete for the current REST-first target slice

---

## Phase 5: Lightweight Environment Model and Control Plane Maturity

- [x] Define a lightweight environment model for onboarded targets
- [x] Add better suppression and baseline management
- [x] Add cleaner diff-aware result comparison
- [x] Add richer issue/comment/report policy controls
- [ ] Add simple repo-fleet tracking for multiple onboarded targets
- [x] Add explicit result-state / triage workflow model
- [x] Add remediation + retest workflow guidance
- [ ] Add operational reliability tracking
- [ ] Update capability docs and comparison docs to reflect the new operator model

### Phase 5 progress note
- Initial operator model is now implemented in the core PR/nightly path:
  - `environment-manifest.json`
  - `environment-manifest.md`
  - `result-state.json`
  - `result-state.md`
- the environment manifest captures:
  - target name
  - scan profile and trigger
  - fail level
  - auth bootstrap mode
  - protected/admin route paths
  - route-hint source directories
- the result-state artifact now applies baseline suppressions from:
  - `security/zap/.zap-baseline.json`
  and emits a stable operator-facing state:
  - `clean`
  - `baseline_only`
  - `needs_triage`
- PR/nightly summary output now includes:
  - `Operator Context`
  - `Result State`
- CI proof now exists on both core lanes:
  - nightly proof:
    - `DAST Nightly #56`: `4m 48s`
    - artifact bundle included:
      - `environment-manifest.json`
      - `result-state.json`
    - nightly result state:
      - `needs_triage`
  - PR proof:
    - `report-summary.md` now includes:
      - `## Operator Context`
      - `## Result State`
    - PR artifact bundle included:
      - `environment-manifest.json`
      - `result-state.json`
    - PR operator values confirmed:
      - profile: `pr-delta`
      - trigger: `workflow_run`
    - bootstrap mode: `adapter`
    - state: `needs_triage`
- local diff-aware comparison proof now exists:
  - committed finding baseline:
    - `security/zap/.zap-result-baseline.json`
  - current demo report now compares against that baseline and reports:
    - `New findings vs baseline: 0`
    - `Persisting findings vs baseline: 9`
    - `Resolved findings vs baseline: 0`
  - triage guidance now distinguishes:
    - new findings first
    - persisting findings
    - resolved findings
- CI proof now also exists on the PR lane:
    - `DAST PR Scan #16`: `2m 53s`
    - summary now includes:
      - `New findings vs baseline: 1`
      - `Persisting findings vs baseline: 8`
      - `Resolved findings vs baseline: 1`
    - this proves the diff-aware comparison is active in the real PR summary path, not just local tooling
- richer policy controls are now implemented:
  - committed policy file:
    - `security/report-policy.json`
  - PR comment policy now supports:
    - `always`
    - `actionable`
    - `new_findings`
  - nightly issue policy now supports:
    - `threshold_only`
    - `new_findings`
    - `threshold_or_new_findings`
    - `always`
  - nightly issue handling now deduplicates/upgrades an existing open issue by title prefix instead of always opening a fresh issue
  - nightly proof now exists for the policy-driven result shape:
    - `DAST Nightly #62`: `4m 23s`
    - nightly result state reported:
      - `New findings vs baseline: 21`
      - `Persisting findings vs baseline: 5`
      - `Resolved findings vs baseline: 4`
    - triage guidance shifted to:
      - `Review new findings relative to the baseline first.`
  - PR-path proof now also exists for the policy-driven summary shape:
    - PR summary reported:
      - `New findings vs baseline: 0`
      - `Persisting findings vs baseline: 9`
      - `Resolved findings vs baseline: 0`
    - PR result-state guidance reported:
      - `Review persisting active findings and decide remediation or acceptance.`
    - this proves the actionable-policy inputs are flowing through the real PR pipeline
  - what is still pending is explicit UI-side confirmation that:
    - the GitHub PR comment body renders the `### Policy Summary` block as configured
    - nightly issue dedupe/update behaves as configured
- remediation/retest guidance is now implemented:
  - generated artifact:
    - `remediation-guide.md`
  - built from:
    - `result-state.json`
  - guidance now distinguishes:
    - new findings to triage first
    - persisting findings to retest after fixes
    - recently resolved findings to guard against regression
  - this turns the diff-aware result model into a concrete maintainer loop instead of only a summary
- this is the beginning of Phase 5 operator maturity, not the full control-plane story

### Phase 5 exit
- [x] PR remains under 10 minutes
- [x] Nightly remains under 15 minutes
- [ ] Multiple repos can be operated without ad hoc manual triage

---

## Cross-Cutting Guardrails

- [ ] Do not overclaim beyond the target niche
- [ ] Keep the trusted/untrusted split intact
- [ ] Keep repo noise low for both Model 2 and Model 1 stories
- [ ] Keep benchmark evidence updated as capabilities change
- [ ] Re-check the ZeroDAST vs Checkmarx comparison after each phase
- [ ] Prefer measured timing numbers over qualitative labels
- [ ] Treat admin-path coverage as a real scan contract, not just a seeded user existing in DB

---

## Final Transition Goal

- [ ] ZeroDAST reaches 90-95% of Checkmarx-level capability for its realistic target niche
- [ ] PR scans remain under 10 minutes
- [ ] Nightly scans remain under 15 minutes
- [ ] Authenticated and admin path coverage are both proven
- [ ] Public comparison claims are still truthful
