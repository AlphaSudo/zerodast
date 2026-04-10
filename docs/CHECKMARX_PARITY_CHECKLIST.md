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
- [ ] Add GraphQL support
- [ ] Add undocumented-route discovery using requestor/traffic evidence
- [ ] Add code/spec-hint-based route discovery where practical
- [x] Add API inventory outputs to artifacts and summaries
- [ ] Re-test hard targets where importer weakness previously limited coverage
- [ ] Compare API reach improvement vs timing cost
- [ ] Update benchmark docs with the improved API coverage model

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

### Phase 4 exit
- [x] PR remains under 10 minutes
- [x] Nightly remains under 15 minutes
- [x] API coverage improves materially on at least one hard target

---

## Phase 5: Lightweight Environment Model and Control Plane Maturity

- [ ] Define a lightweight environment model for onboarded targets
- [ ] Add better suppression and baseline management
- [ ] Add cleaner diff-aware result comparison
- [ ] Add richer issue/comment/report policy controls
- [ ] Add simple repo-fleet tracking for multiple onboarded targets
- [ ] Add explicit result-state / triage workflow model
- [ ] Add remediation + retest workflow guidance
- [ ] Add operational reliability tracking
- [ ] Update capability docs and comparison docs to reflect the new operator model

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
