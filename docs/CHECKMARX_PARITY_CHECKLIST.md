# ZeroDAST Checkmarx-Parity Transition Checklist

This checklist turns [CHECKMARX_PARITY_ROADMAP.md](C:/Java%20Developer/DAST/docs/CHECKMARX_PARITY_ROADMAP.md) into an execution-oriented transition plan.

It is scoped to the realistic target already defined there:
- **90-95% parity for ZeroDAST's target niche**
- not full Checkmarx platform parity

---

## Phase 1: Role-Aware Auth Coverage

- [ ] Confirm admin seed user exists in the demo path and can be bootstrapped in CI
- [ ] Add dedicated admin token bootstrap alongside current user bootstrap
- [ ] Add admin-only request seeding into the core scan config
- [ ] Add post-scan verification that an admin-only route was actually exercised
- [ ] Update PR profile to include bounded role-aware auth proof
- [ ] Update nightly profile to include richer role-aware coverage
- [ ] Prove the feature on the built-in demo app
- [ ] Prove the feature on at least one external target with privileged/admin routes
- [ ] Re-measure PR timing impact
- [ ] Re-measure nightly timing impact
- [ ] Update capability docs after implementation

### Phase 1 exit
- [ ] PR remains under 10 minutes
- [ ] Nightly remains under 15 minutes
- [ ] Authenticated + admin path coverage is proven, not assumed

---

## Phase 2: Scan-Quality Uplift Without PR Regression

- [ ] Improve delta-to-route mapping quality
- [ ] Improve request seeding from OpenAPI and changed endpoints
- [ ] Add stronger per-profile scan budget controls
- [ ] Distinguish route exercise from alert-bearing signal in summaries
- [ ] Distinguish authenticated route exercise from unauthenticated reach
- [ ] Improve artifact summaries for fast PR triage
- [ ] Re-run at least two external targets with the new scan-quality model
- [ ] Compare signal uplift vs timing impact
- [ ] Update benchmark docs with the new evidence

### Phase 2 exit
- [ ] PR remains under 10 minutes
- [ ] Nightly remains under 15 minutes
- [ ] Signal quality improves without flattening the time budget

---

## Phase 3: Richer Authentication Adapters

- [ ] Define a reusable auth adapter interface
- [ ] Add cookie/session auth support
- [ ] Add multi-step login scripting support
- [ ] Add refresh-token/session-refresh handling
- [ ] Separate simple seeded auth from richer enterprise-style auth adapters in config/docs
- [ ] Improve protected-route validation before scan launch
- [ ] Prove at least three auth styles cleanly
- [ ] Prove at least two non-demo external repos with nontrivial auth adapters
- [ ] Keep browser-grade auth out of PR unless timing proves acceptable
- [ ] Update capabilities and roadmap docs after implementation

### Phase 3 exit
- [ ] PR remains under 10 minutes
- [ ] Nightly remains under 15 minutes
- [ ] Auth support is materially broader than bearer-token-only flows

---

## Phase 4: API Breadth and Discovery Improvements

- [ ] Improve OpenAPI normalization and ingestion reliability
- [ ] Add GraphQL support
- [ ] Add undocumented-route discovery using requestor/traffic evidence
- [ ] Add code/spec-hint-based route discovery where practical
- [ ] Add API inventory outputs to artifacts and summaries
- [ ] Re-test hard targets where importer weakness previously limited coverage
- [ ] Compare API reach improvement vs timing cost
- [ ] Update benchmark docs with the improved API coverage model

### Phase 4 exit
- [ ] PR remains under 10 minutes
- [ ] Nightly remains under 15 minutes
- [ ] API coverage improves materially on at least one hard target

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
- [ ] PR remains under 10 minutes
- [ ] Nightly remains under 15 minutes
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
