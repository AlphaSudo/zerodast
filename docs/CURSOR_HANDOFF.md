# ZeroDAST Cursor Handoff

This file is a direct handoff for continuing work on ZeroDAST from the current repository state.

It is written so another coding agent can continue with minimal loss of context, tone, or engineering intent.

Current repo state:
- branch: `main`
- workspace: `C:\Java Developer\DAST`
- date context: `2026-04-11`
- Model 1 CI proof: `zerodast-install` branches on AlphaSudo/nocodb, AlphaSudo/strapi, AlphaSudo/directus (all GREEN)

## Working Style Requirements

The user does **not** want silent vibe-coding.

When implementing code:
- talk like a colleague software engineer
- explain what you think is happening
- explain what you are about to do
- keep the user involved in the reasoning and tradeoffs
- do not disappear into silent edits

Practical interaction style:
- short progress updates before substantial work
- explain why a step matters
- be honest about what is proven vs what is only implemented
- prefer conservative claims over optimistic ones

## Product Goal

ZeroDAST is being pushed toward:
- **enterprise-like CI DAST for OSS/public-repo-friendly web/API targets**
- with:
  - lower setup friction
  - lower repo noise
  - faster PR and nightly scans
  - honest, benchmark-backed claims

The realistic target is:
- **90-95% of Checkmarx-level capability for ZeroDAST's target niche**
- **not** full Checkmarx platform parity

Current scope is intentionally:
- REST-first
- CI-first
- OSS/public-repo-friendly
- documented APIs preferred
- auth bootstrapping preferred over browser/SAML/MFA complexity

GraphQL is currently **deferred**, not a current-scope blocker.

## Truthful Current State

ZeroDAST today is already:
1. a self-validating CI DAST system for the built-in demo app
2. an external-orchestrator benchmark/adaptation framework
3. an alpha in-repo adoption prototype

It is **not** just a ZAP wrapper.

It already has:
- two-profile CI DAST
- trusted/untrusted workflow separation
- isolated scan runtime
- seeded throwaway DB state
- authenticated path coverage
- admin-path coverage in the built-in demo path
- delta-scoped PR scanning
- nightly/full scanning
- API inventory and route-hint outputs
- external T4 benchmark workflows
- early operator/control-plane maturity artifacts

It does **not** yet justify claims like:
- full enterprise DAST parity
- broad SSO/SAML/OIDC/MFA support
- browser-driven auth parity
- GraphQL/SOAP/gRPC breadth
- shadow API discovery from live traffic
- full governance/compliance/RBAC platform parity

## Phase Status

### Phase 1: Role-Aware Auth Coverage
Status:
- effectively complete and proven

What is proven:
- admin bootstrap exists
- admin request seeding exists
- admin-route verification exists
- built-in demo proof exists
- external privileged/admin target proof exists

Important proof:
- authenticated + admin path coverage is proven, not assumed

### Phase 2: Scan-Quality Uplift Without PR Regression
Status:
- partially complete
- still open

Implemented/proven:
- better delta-to-route mapping
- route-aware request seeding from changed endpoints/OpenAPI
- route exercise vs alert signal distinction
- authenticated/public/admin requestor distinction
- better PR summaries

Still open:
- stronger per-profile scan budget controls
- re-run at least two external targets under the newer scan-quality model
- compare signal uplift vs timing impact
- sync benchmark docs around those newer scan-quality reruns

This phase should remain open until external rerun evidence is cleaner.

### Phase 3: Richer Authentication Adapters
Status:
- **closed for the current niche**

Implemented/proven:
- reusable auth adapter interface
- JSON token adapter (proven on NocoDB xc-auth, Strapi nested data.token, Directus nested data.access_token)
- form/cookie adapter
- JSON session adapter
- form-urlencoded token adapter (FastAPI auth profile)
- protected/admin route validation via adapter-supplied headers
- fast local auth smoke paths
- adapter CI smoke workflow
- external Django session-auth profile proof
- **Model 1 CI proof on 3 external repos with diverse auth configurations**

Still open (incremental, not blocking):
- multi-step login scripting
- refresh/session-refresh handling

### Phase 4: API Breadth and Discovery Improvements
Status:
- complete for the **current REST-first target slice**

Implemented/proven:
- OpenAPI normalization/import resilience improvements
- API inventory artifacts and summaries
- undocumented observed-route inventory
- code-hinted route inventory
- hard-target proof on FastAPI
- second hard-target proof on Petclinic

Explicitly deferred:
- GraphQL support

Important wording:
- Phase 4 is complete for the current REST-first scope
- not complete for all possible API breadth goals

### Phase 5: Lightweight Environment Model and Control Plane Maturity
Status:
- underway
- now has several proven slices

Implemented/proven:
- environment manifest artifacts
- result-state artifacts
- finding baseline comparison
- report policy controls
- remediation/retest guide
- operational reliability tracking

Still open:
- simple repo-fleet tracking for multiple onboarded targets
- updating comparison docs/operator-model docs more broadly
- UI-side proof for some GitHub comment/issue behaviors

## Important Proven Timing Envelope

Current working target remains:
- PR scans under `10 min`
- nightly scans under `15 min`

Most recent reality:
- these workflows remain comfortably under budget in the current shape

Examples from recent proven runs:
- `CI Tests #16`: `1m 6s`
- `DAST PR Scan #16`: `2m 53s`
- `DAST Nightly #62`: `4m 23s`
- operational reliability nightly proof:
  - runtime `203s`

Do not casually add work to PR scans that threatens this envelope.

## Critical Files To Understand First

Core runtime and scan logic:
- [run-dast-env.sh](C:/Java%20Developer/DAST/security/run-dast-env.sh)
- [automation.yaml](C:/Java%20Developer/DAST/security/zap/automation.yaml)
- [generate-delta-scan.sh](C:/Java%20Developer/DAST/scripts/generate-delta-scan.sh)
- [delta-detect.sh](C:/Java%20Developer/DAST/scripts/delta-detect.sh)
- [build-request-seeds.js](C:/Java%20Developer/DAST/scripts/build-request-seeds.js)
- [parse-zap-report.js](C:/Java%20Developer/DAST/scripts/parse-zap-report.js)

Operator model / Phase 5:
- [build-environment-manifest.js](C:/Java%20Developer/DAST/scripts/build-environment-manifest.js)
- [build-finding-baseline.js](C:/Java%20Developer/DAST/scripts/build-finding-baseline.js)
- [build-result-state.js](C:/Java%20Developer/DAST/scripts/build-result-state.js)
- [build-remediation-guide.js](C:/Java%20Developer/DAST/scripts/build-remediation-guide.js)
- [build-operational-reliability.js](C:/Java%20Developer/DAST/scripts/build-operational-reliability.js)
- [report-policy.json](C:/Java%20Developer/DAST/security/report-policy.json)
- [.zap-baseline.json](C:/Java%20Developer/DAST/security/zap/.zap-baseline.json)
- [.zap-result-baseline.json](C:/Java%20Developer/DAST/security/zap/.zap-result-baseline.json)

Auth adapter surface:
- [json-token-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/json-token-login.sh)
- [form-cookie-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/form-cookie-login.sh)
- [json-session-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/json-session-login.sh)
- [run-auth-adapter-smoke.sh](C:/Java%20Developer/DAST/scripts/run-auth-adapter-smoke.sh)
- [run-cookie-adapter-smoke.sh](C:/Java%20Developer/DAST/scripts/run-cookie-adapter-smoke.sh)

Workflows:
- [ci.yml](C:/Java%20Developer/DAST/.github/workflows/ci.yml)
- [dast-pr.yml](C:/Java%20Developer/DAST/.github/workflows/dast-pr.yml)
- [dast-nightly.yml](C:/Java%20Developer/DAST/.github/workflows/dast-nightly.yml)
- [auth-adapter-smoke.yml](C:/Java%20Developer/DAST/.github/workflows/auth-adapter-smoke.yml)
- [django-auth-profile.yml](C:/Java%20Developer/DAST/.github/workflows/django-auth-profile.yml)
- [petclinic-t4-scan.yml](C:/Java%20Developer/DAST/.github/workflows/petclinic-t4-scan.yml)
- [fullstack-fastapi-t4-scan.yml](C:/Java%20Developer/DAST/.github/workflows/fullstack-fastapi-t4-scan.yml)

Primary docs:
- [CHECKMARX_PARITY_CHECKLIST.md](C:/Java%20Developer/DAST/docs/CHECKMARX_PARITY_CHECKLIST.md)
- [CURRENT_CAPABILITIES.md](C:/Java%20Developer/DAST/docs/CURRENT_CAPABILITIES.md)
- [CHECKMARX_PARITY_ROADMAP.md](C:/Java%20Developer/DAST/docs/CHECKMARX_PARITY_ROADMAP.md)
- [POST_CHECKLIST_PROOF_ROADMAP.md](C:/Java%20Developer/DAST/docs/POST_CHECKLIST_PROOF_ROADMAP.md)
- [NEAR_LOSSLESS_COMPARISON.md](C:/Java%20Developer/DAST/docs/NEAR_LOSSLESS_COMPARISON.md)
- [CLAIM_READINESS.md](C:/Java%20Developer/DAST/docs/CLAIM_READINESS.md)

Benchmark docs:
- [full-stack-fastapi-template.md](C:/Java%20Developer/DAST/docs/benchmarks/full-stack-fastapi-template.md)
- [spring-petclinic-rest.md](C:/Java%20Developer/DAST/docs/benchmarks/spring-petclinic-rest.md)
- [django-styleguide-example.md](C:/Java%20Developer/DAST/docs/benchmarks/django-styleguide-example.md)

## Model 1 CI Fleet Proof (Latest Major Milestone)

Four open-source forks with ZeroDAST Model 1 installed and running autonomously in GitHub Actions:

| Target | Stars | Auth Style | Runtime | Findings | Seeds Hit | CI Status |
| --- | ---: | --- | --- | --- | --- | --- |
| NocoDB | 48k+ | xc-auth token | 242s | 4M / 3L / 3I | 4/4 | **PASS** |
| Strapi | 67k+ | Bearer JWT (nested data.token) | 171s | 2M / 3L / 3I | 4/4 | **PASS** |
| Directus | 29k+ | Bearer JWT (nested data.access_token) | 343s | 4M / 4L / 6I | 11/11 | **PASS** |
| Medusa | 27k+ (upstream) | Bearer JWT (`/auth/user/emailpass`) | 108s `coldRun` (~6m+ GHA job) | 4M / 2L / 0I | 5/5 | **PASS** |

Repos:
- [AlphaSudo/nocodb zerodast-install](https://github.com/AlphaSudo/nocodb/tree/zerodast-install)
- [AlphaSudo/strapi zerodast-install](https://github.com/AlphaSudo/strapi/tree/zerodast-install)
- [AlphaSudo/directus zerodast-install](https://github.com/AlphaSudo/directus/tree/zerodast-install)
- [AlphaSudo/medusa zerodast-install](https://github.com/AlphaSudo/medusa/tree/zerodast-install)

Frozen Medusa bundle + Actions log: [`tmp-ci-proof-medusa/`](../tmp-ci-proof-medusa/) — [run 24307557281](https://github.com/AlphaSudo/medusa/actions/runs/24307557281).

This closes the near-lossless comparison blocker and the adoption/operator proof blocker (fourth target added).

## What Has Been Proven Recently

### Operational reliability proof
From the nightly artifact that included:
- `reliability-metrics.json`
- `operational-reliability.json`
- `operational-reliability.md`

Reported:
- `State: healthy`
- `Total runtime seconds: 203`
- `Database ready seconds: 2`
- `Application ready seconds: 1`

Completed checks:
- protected/admin validation
- ZAP run
- report generation
- API inventory generation
- result-state generation
- remediation guidance generation
- AuthZ checks
- post-scan verification

### Operator model proof
Artifacts already proven in CI:
- `environment-manifest.json`
- `result-state.json`
- `remediation-guide.md`
- `operational-reliability.json`

### API discovery / inventory proof
FastAPI hard target:
- `OpenAPI route count: 15`
- `OpenAPI operation count: 23`
- `Observed OpenAPI routes: 9`
- `Unobserved OpenAPI routes: 6`
- `Code-hinted routes: 15`
- `Code-hinted observed routes: 9`

Petclinic hard target:
- `OpenAPI routes observed: 17 / 17`
- `Code-hinted routes: 17`
- `Code-hinted observed routes: 17`
- undocumented observed routes mostly operational/UI

### External richer-auth proof
Django session auth profile:
- `POST /api/auth/session/login/`
- `GET /api/auth/me/`
- `GET /api/users/`
- auth transport:
  - `Authorization: Session <sessionid>`
- CI proof:
  - `Django Auth Profile #1`: `92s`

## What Is Still Open Right Now

Most important open items, in practical order:

1. **Phase 5 repo-fleet tracking**
- there is still no lightweight multi-target registry/overview for onboarded repos
- the Model 1 CI fleet proof makes this more natural now

2. **PR-profile proof on Model 1 targets**
- current proof is nightly-only
- PR scans would strengthen the timing claim further

3. **Phase 2 external rerun debt**
- external reruns with the newer scan-quality model
- signal uplift vs timing comparison

4. **UI-side proof debt**
- PR comment rendering with `### Policy Summary`
- nightly issue dedupe/update behavior

## Recommended Next Move

If continuing from here without changing strategy, the best next engineering move is:

### Add simple repo-fleet tracking

Why:
- it is the cleanest remaining Phase 5 item
- it builds directly on the operator artifacts already in place
- it helps multiple onboarded targets be operated without ad hoc memory
- it is a better next step than widening protocol breadth again

Good shape for that feature:
- a lightweight tracked-target registry, likely under `docs/` or `security/`
- a generated fleet summary artifact or doc
- fields like:
  - target name
  - target type
  - auth mode
  - scan profiles supported
  - latest proof status
  - latest timing
  - known limitations

Keep it:
- simple
- file-based
- low-noise
- honest

Do **not** jump to:
- a heavy database-backed control plane
- broad UI/platform ambitions
- GitHub Apps / hosted service complexity

## Claims That Are Safe Right Now

Strongest safe current public-facing claim:

ZeroDAST is:
- an enterprise-like CI-first DAST system for documented REST-style APIs
- with near-lossless parity to enterprise DAST within its defined niche
- proven on 6 external targets across 3 language stacks (Java, Python, Node.js)
- including 3 high-profile repos (NocoDB 48k+, Strapi 67k+, Directus 29k+ stars) running autonomously in GitHub Actions
- with trusted/untrusted separation, authenticated/admin-path coverage, and full operator artifacts

Claims to avoid:
- full enterprise DAST parity (broader than the niche)
- broad enterprise auth parity (no SSO/SAML/OIDC/MFA)
- broad protocol parity (no GraphQL/SOAP/gRPC)
- shadow API discovery parity
- universal target support

## Practical Guardrails

Always preserve:
- trusted/untrusted workflow split
- low repo noise
- PR/nightly timing discipline
- honest benchmark-backed wording

Avoid:
- adding expensive PR-path behavior without explicit timing proof
- overclaiming based on implementation without CI/benchmark proof
- collapsing operational health and security findings into one concept
- pretending a narrow feature is generalized when it is still bounded

## Git / Workspace Notes

The working tree may contain many local scratch files and downloaded artifacts that are **not** repo-worthy.

Be careful to commit only intended repo changes.

Typical local clutter includes:
- downloaded report zips
- extracted `tmp-*` artifact directories
- notes and scratch scripts

Use narrow staging, not broad `git add .`.

## Short Restart Plan For Cursor

If starting fresh:

1. Read:
   - [CHECKMARX_PARITY_CHECKLIST.md](C:/Java%20Developer/DAST/docs/CHECKMARX_PARITY_CHECKLIST.md)
   - [CURRENT_CAPABILITIES.md](C:/Java%20Developer/DAST/docs/CURRENT_CAPABILITIES.md)
   - [run-dast-env.sh](C:/Java%20Developer/DAST/security/run-dast-env.sh)

2. Understand current Phase 5 artifacts:
   - environment manifest
   - result state
   - remediation guide
   - operational reliability

3. Keep Phase 2 and Phase 3 open.

4. Treat Phase 4 as complete for the current REST-first scope.

5. Start the next implementation from:
   - simple repo-fleet tracking

6. Keep the user involved in the reasoning while coding.

That is the closest current handoff to preserving continuity with the work already done here.
