# ZeroDAST Current Coverage, Scope, and Capabilities

## Purpose

This document is the **current-state inventory** of the ZeroDAST repository.

It describes what the codebase supports **today**, based on the implementation that exists in this repository right now.
It is intentionally different from:
- roadmap documents
- benchmark aspirations
- parity estimates against commercial tools

If a capability is not implemented or not proven in the current repo, it should not be treated as present here.

## What ZeroDAST Is Today

ZeroDAST currently provides three related but distinct things:

1. **A self-validating CI DAST system for the built-in demo app**
2. **An external-orchestrator DAST benchmark and adaptation framework for public repositories**
3. **An alpha in-repo adoption prototype (Model 1)**

That means the repository is not just "a ZAP wrapper" and not just "a benchmark folder."
It already contains:
- real CI workflows
- real isolated scan runtime orchestration
- real auth-aware scan support
- real post-scan verification logic
- external-repo T4 demonstrations
- an installable in-repo prototype

## High-Level Coverage Map

| Area | Current State |
| --- | --- |
| Demo app + intentional vuln canaries | Implemented |
| Two-profile CI DAST | Implemented |
| Trusted/untrusted workflow split | Implemented |
| Isolated scan runtime | Implemented |
| Throwaway seeded DB runtime | Implemented |
| Authenticated scan support | Implemented |
| Scripted authz regression checks | Implemented |
| Canary verification | Implemented |
| Delta-scoped PR scanning | Implemented |
| Full nightly scanning | Implemented |
| API inventory outputs | Implemented |
| External-repo T4 demonstrations | Implemented |
| Model 1 in-repo prototype | Implemented |
| Admin-path coverage in core repo | Implemented for the core demo-app CI path |
| Complex enterprise auth (SSO/MFA/browser flows) | Not implemented |
| GraphQL/SOAP/gRPC support | Not implemented |
| Shadow API discovery | Not implemented |
| ASPM/compliance/RBAC platform features | Not implemented |

## Repository Surfaces

### 1. CI Workflows

Current workflow set under [.github/workflows](C:/Java%20Developer/DAST/.github/workflows):

- [ci.yml](C:/Java%20Developer/DAST/.github/workflows/ci.yml)
- [dast-pr.yml](C:/Java%20Developer/DAST/.github/workflows/dast-pr.yml)
- [dast-nightly.yml](C:/Java%20Developer/DAST/.github/workflows/dast-nightly.yml)
- [auth-adapter-smoke.yml](C:/Java%20Developer/DAST/.github/workflows/auth-adapter-smoke.yml)
- [django-auth-profile.yml](C:/Java%20Developer/DAST/.github/workflows/django-auth-profile.yml)
- [petclinic-t4-metadata.yml](C:/Java%20Developer/DAST/.github/workflows/petclinic-t4-metadata.yml)
- [petclinic-t4-scan.yml](C:/Java%20Developer/DAST/.github/workflows/petclinic-t4-scan.yml)
- [fullstack-fastapi-t4-metadata.yml](C:/Java%20Developer/DAST/.github/workflows/fullstack-fastapi-t4-metadata.yml)
- [fullstack-fastapi-t4-scan.yml](C:/Java%20Developer/DAST/.github/workflows/fullstack-fastapi-t4-scan.yml)

### 2. Scan Runtime and Security Scripts

Current script/runtime surface:

- [run-dast-env.sh](C:/Java%20Developer/DAST/security/run-dast-env.sh)
- [automation.yaml](C:/Java%20Developer/DAST/security/zap/automation.yaml)
- [bootstrap-auth.sh](C:/Java%20Developer/DAST/scripts/bootstrap-auth.sh)
- [json-token-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/json-token-login.sh)
- [form-cookie-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/form-cookie-login.sh)
- [json-session-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/json-session-login.sh)
- [authz-tests.sh](C:/Java%20Developer/DAST/scripts/authz-tests.sh)
- [authz-tests.js](C:/Java%20Developer/DAST/scripts/authz-tests.js)
- [verify-canaries.sh](C:/Java%20Developer/DAST/scripts/verify-canaries.sh)
- [verify-admin-coverage.sh](C:/Java%20Developer/DAST/scripts/verify-admin-coverage.sh)
- [delta-detect.sh](C:/Java%20Developer/DAST/scripts/delta-detect.sh)
- [generate-delta-scan.sh](C:/Java%20Developer/DAST/scripts/generate-delta-scan.sh)
- [parse-zap-report.js](C:/Java%20Developer/DAST/scripts/parse-zap-report.js)
- [build-environment-manifest.js](C:/Java%20Developer/DAST/scripts/build-environment-manifest.js)
- [build-result-state.js](C:/Java%20Developer/DAST/scripts/build-result-state.js)
- [build-api-inventory.js](C:/Java%20Developer/DAST/scripts/build-api-inventory.js)
- [build-request-seeds.js](C:/Java%20Developer/DAST/scripts/build-request-seeds.js)
- [run-dast-local.sh](C:/Java%20Developer/DAST/scripts/run-dast-local.sh)
- [run-auth-adapter-smoke.sh](C:/Java%20Developer/DAST/scripts/run-auth-adapter-smoke.sh)
- [run-cookie-adapter-smoke.sh](C:/Java%20Developer/DAST/scripts/run-cookie-adapter-smoke.sh)
- [run-auth-profile.sh](C:/Java%20Developer/DAST/benchmarks/django-styleguide-example/run-auth-profile.sh)

### 3. Model 1 Prototype Surface

Current in-repo prototype payload lives under [prototypes/model1-template](C:/Java%20Developer/DAST/prototypes/model1-template), especially:

- [config.json](C:/Java%20Developer/DAST/prototypes/model1-template/zerodast/config.json)
- [run-scan.sh](C:/Java%20Developer/DAST/prototypes/model1-template/zerodast/run-scan.sh)
- [prepare-openapi.js](C:/Java%20Developer/DAST/prototypes/model1-template/zerodast/prepare-openapi.js)
- [verify-report.js](C:/Java%20Developer/DAST/prototypes/model1-template/zerodast/verify-report.js)
- [zerodast-pr.yml](C:/Java%20Developer/DAST/prototypes/model1-template/.github/workflows/zerodast-pr.yml)
- [zerodast-nightly.yml](C:/Java%20Developer/DAST/prototypes/model1-template/.github/workflows/zerodast-nightly.yml)

## Current Capability Details

## A. Two-Profile CI DAST

### Status
Implemented.

### What exists
ZeroDAST currently supports a genuine two-profile CI scan model:

- **PR / delta-oriented scan path** in [dast-pr.yml](C:/Java%20Developer/DAST/.github/workflows/dast-pr.yml)
- **Nightly / full scan path** in [dast-nightly.yml](C:/Java%20Developer/DAST/.github/workflows/dast-nightly.yml)

### What the PR profile does
- waits for trusted CI completion using `workflow_run`
- downloads the artifactized image and delta metadata from the untrusted lane
- validates optional overlay SQL before scan
- generates a delta-scoped ZAP config from changed endpoints
- runs the isolated scan runtime
- uploads report artifacts and comments summary on the PR

### What the nightly profile does
- builds from trusted mainline state
- runs the full isolated scan runtime
- uploads reports
- parses threshold output
- opens an issue when findings exceed the configured threshold

### What this means
ZeroDAST already satisfies the core requirement of **two-profile CI DAST** in its own repo.

## B. Trusted / Untrusted Separation

### Status
Implemented.

### What exists
The core demo-app pipeline is intentionally split:

- untrusted PR lane in [ci.yml](C:/Java%20Developer/DAST/.github/workflows/ci.yml)
- trusted DAST lane in [dast-pr.yml](C:/Java%20Developer/DAST/.github/workflows/dast-pr.yml)

### Security properties implemented today
- PR code does not directly run the trusted scan lane
- trusted lane consumes artifacts rather than directly trusting PR execution state
- report commenting happens in a separate reporting step with scoped permissions

### What this gives ZeroDAST today
This is one of the strongest parts of the current system and a real differentiator from many ordinary in-repo DAST setups.

## C. Isolated Scan Runtime

### Status
Implemented.

### What exists
The scan runtime in [run-dast-env.sh](C:/Java%20Developer/DAST/security/run-dast-env.sh) currently provides:

- internal container network via `--internal`
- isolated app, DB, and ZAP containers
- read-only root filesystem for app container
- `tmpfs` writable scratch area
- dropped capabilities
- `no-new-privileges`
- memory and PID constraints
- post-run cleanup trap

### What this means
ZeroDAST already has a real isolated runtime model, not just a loose scanner invocation.

## D. Seeded Database and Throwaway Data Model

### Status
Implemented.

### What exists
The scan environment supports:
- schema SQL seeding
- mock data seeding
- optional overlay SQL seeding
- overlay validation in the trusted DAST lane before execution

### What this means
The repo already supports controlled seeded test state for scans and post-scan checks.

## E. ZAP Automation and Scan Policy

### Status
Implemented.

### What exists today in [automation.yaml](C:/Java%20Developer/DAST/security/zap/automation.yaml):
- OpenAPI import
- auth header replacer injection
- requestor jobs for known canary routes
- spider phase
- passive scan wait
- active scan phase
- JSON and HTML reporting
- tuned active rules for SQLi and XSS canaries

### ZAP version state
Current core runtime defaults to ZAP `2.17.0` via [run-dast-env.sh](C:/Java%20Developer/DAST/security/run-dast-env.sh).

### What this means
The repo already has a real scanner policy layer with repeatable configuration and report output.

## F. Authenticated Scan Support

### Status
Implemented.

### What exists today
The core runtime supports auth bootstrap and auth-header injection:

- default bootstrap credentials in [run-dast-env.sh](C:/Java%20Developer/DAST/security/run-dast-env.sh)
- auth bootstrap script in [bootstrap-auth.sh](C:/Java%20Developer/DAST/scripts/bootstrap-auth.sh)
- in-container auth bootstrap mode in [run-dast-env.sh](C:/Java%20Developer/DAST/security/run-dast-env.sh)
- adapter-driven auth header injection into ZAP config in [automation.yaml](C:/Java%20Developer/DAST/security/zap/automation.yaml)
- default JSON token adapter in [json-token-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/json-token-login.sh)
- initial form/cookie adapter in [form-cookie-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/form-cookie-login.sh)
- JSON session adapter in [json-session-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/json-session-login.sh)
- fast local adapter smoke in [run-auth-adapter-smoke.sh](C:/Java%20Developer/DAST/scripts/run-auth-adapter-smoke.sh)
- fast local cookie adapter smoke in [run-cookie-adapter-smoke.sh](C:/Java%20Developer/DAST/scripts/run-cookie-adapter-smoke.sh)
- dedicated adapter CI smoke in [auth-adapter-smoke.yml](C:/Java%20Developer/DAST/.github/workflows/auth-adapter-smoke.yml)
- external Django auth-profile runner in [run-auth-profile.sh](C:/Java%20Developer/DAST/benchmarks/django-styleguide-example/run-auth-profile.sh)

### What is proven in the repo's broader work
- authenticated user-path scanning exists
- external authenticated T4 work exists for FastAPI
- auth bootstrap and protected-route validation have already been exercised in benchmark code paths
- adapter-based PR/nightly CI execution is proven for the core demo app
- local fast auth-adapter smoke is proven for the core demo app
- matrix-backed CI smoke proof exists for both built-in adapter shapes:
  - JSON-token header path
  - form/cookie session path
- the built-in demo app now has a concrete session-cookie login path at `/api/auth/session-login`
- a first external Django/DRF session-auth proof exists using the repo-supported `Authorization: Session <sessionid>` transport
- that external auth profile proved:
  - `POST /api/auth/session/login/`
  - `GET /api/auth/me/`
  - `GET /api/users/`
  on a public non-demo repo in about `26s`
- that same external auth profile is now also proven in CI:
  - `Django Auth Profile #1`
  - `92s`
  - bootstrap, protected-route validation, and admin-route validation all returned `200`

### Important limitation
This is still **adapter-shaped authenticated coverage**, not full enterprise auth parity.
It does **not** currently mean:
- SSO
- SAML
- OIDC enterprise federation
- MFA/TOTP
- browser-recorded login flows

### What the adapter foundation means today
The repo is no longer hardwired to only `Authorization: Bearer <token>` semantics in the runtime.
Instead, the current runtime can:
- obtain auth material from an adapter
- pass header name/value pairs into ZAP replacers
- validate protected/admin routes using adapter-provided headers

That is a real Phase 3 foundation, but it is not yet the same as broad enterprise auth coverage.

## G. AuthZ / Ownership Regression Checks

### Status
Implemented.

### What exists
The repo contains scripted authz/IDOR-style validation:

- shell version: [authz-tests.sh](C:/Java%20Developer/DAST/scripts/authz-tests.sh)
- Node/network-safe version: [authz-tests.js](C:/Java%20Developer/DAST/scripts/authz-tests.js)

### What these do
They obtain multiple user tokens and test cross-user access attempts.

### Important limitation
These scripts validate user-to-user ownership / authz behavior, but they do **not** currently implement full admin-role scan coverage in the core repo.

## H. Admin / Role-Aware Coverage

### Status
Implemented for the core demo-app CI path.

### What exists today
The demo app contains role-aware logic:
- user role is carried in auth payloads in [demo-app/src/routes/auth.js](C:/Java%20Developer/DAST/demo-app/src/routes/auth.js)
- admin-only route exists in [demo-app/src/routes/users.js](C:/Java%20Developer/DAST/demo-app/src/routes/users.js)

The core DAST implementation now also includes:
- dedicated admin token bootstrap in [run-dast-env.sh](C:/Java%20Developer/DAST/security/run-dast-env.sh)
- admin token bootstrap in [bootstrap-auth.sh](C:/Java%20Developer/DAST/scripts/bootstrap-auth.sh)
- admin-specific ZAP request seeding in [automation.yaml](C:/Java%20Developer/DAST/security/zap/automation.yaml)
- bounded PR delta config support for the admin route in [generate-delta-scan.sh](C:/Java%20Developer/DAST/scripts/generate-delta-scan.sh)
- post-scan admin-route exercise verification in [verify-admin-coverage.sh](C:/Java%20Developer/DAST/scripts/verify-admin-coverage.sh)
- PR and nightly workflow enforcement in [dast-pr.yml](C:/Java%20Developer/DAST/.github/workflows/dast-pr.yml) and [dast-nightly.yml](C:/Java%20Developer/DAST/.github/workflows/dast-nightly.yml)

### What is proven today
The repo now has:
- authenticated path coverage: **yes**
- role-aware app surfaces: **yes**
- end-to-end admin path coverage in the core DAST implementation: **yes, for the built-in demo-app CI path**

### Important limitation
This is still a bounded role-aware implementation, not a complete generalized multi-role orchestration model for arbitrary external targets.

## I. Canary Verification

### Status
Implemented.

### What exists
Post-scan canary verification lives in [verify-canaries.sh](C:/Java%20Developer/DAST/scripts/verify-canaries.sh).

### What it currently checks
It validates that expected benchmark findings are still present in the report.

### What this means
The repo already has a self-checking scan confidence layer rather than relying only on raw scanner completion.

## J. Delta Detection and Delta-Scoped Scanning

### Status
Implemented.

### What exists
- changed-file route extraction in [delta-detect.sh](C:/Java%20Developer/DAST/scripts/delta-detect.sh)
- route-aware request seed generation in [build-request-seeds.js](C:/Java%20Developer/DAST/scripts/build-request-seeds.js)
- delta-scan config generation in [generate-delta-scan.sh](C:/Java%20Developer/DAST/scripts/generate-delta-scan.sh)

### What it supports today
- route regex extraction from common route/controller file patterns
- whole-file route extraction when a route/controller file changes
- scope-aware request seeding for:
  - public routes
  - authenticated user routes
  - admin routes when the delta surface calls for them
- fail-safe fallback to FULL scan when changes are too broad or unclear
- PR lane generation of reduced-scope scan configs

### What is proven today
The core repo now has GitHub-side evidence that a route-file PR delta can:
- run in `DELTA` mode
- generate bounded requestor traffic for the changed surface
- observe all reported delta endpoints in the PR summary artifact

Most recent proof point:
- search-route smoke PR reported:
  - `Delta endpoint count: 2`
  - `Delta endpoints observed: 2`
  - `Delta endpoints not observed: 0`
  - observed endpoints:
    - `/api/search`
    - `/api/search/preview`

### Current limitation
This is useful and real, but not a full AST-grade route analysis system.

## K. Report Parsing and Thresholding

### Status
Implemented.

### What exists
- threshold parser in [parse-zap-report.js](C:/Java%20Developer/DAST/scripts/parse-zap-report.js)
- PR summary artifact upload and comment flow in [dast-pr.yml](C:/Java%20Developer/DAST/.github/workflows/dast-pr.yml)
- nightly issue creation when threshold is exceeded in [dast-nightly.yml](C:/Java%20Developer/DAST/.github/workflows/dast-nightly.yml)

### What this means
ZeroDAST already has result interpretation and GitHub feedback loops, not just report files.

### What the current summaries include
The PR/nightly summary path now distinguishes:
- route exercise vs alert-bearing signal
- authenticated requestor reach vs public requestor reach
- admin requestor reach when present
- delta endpoint observation when delta metadata is available
- OpenAPI inventory visibility when the report artifact includes spec and log data

### What the current API inventory adds
The report path now emits:
- `api-inventory.json`
- `api-inventory.md`

Those outputs currently summarize:
- environment manifest / operator context
- OpenAPI route count
- OpenAPI operation count
- OpenAPI imported URL count
- spider discovered URL count
- requestor route count
- alert route count
- observed route count
- observed OpenAPI routes
- unobserved OpenAPI routes
- undocumented observed routes
- code-hinted routes
- code-hinted observed routes
- code-hinted unobserved routes
- code-hinted routes outside spec
- baseline-adjusted result state and suppression usage

### What is proven today
GitHub-side proof now exists that the PR lane can publish API inventory data in its artifacts and summary.

Most recent proof point:
- Phase 4 PR smoke reported:
  - `OpenAPI route count: 11`
  - `OpenAPI operation count: 14`
  - `OpenAPI imported URL count: 15`
  - `Observed OpenAPI routes: 3`
  - `Unobserved OpenAPI routes: 8`
- the summary artifact contained a dedicated `API Inventory` section
- the report artifact contained:
  - `api-inventory.json`
  - `api-inventory.md`
- external benchmark proof also now exists that this inventory model can surface undocumented-route counts in CI-backed benchmark artifacts
- current FastAPI hard-target evidence reports:
  - `Undocumented observed routes: 0`
  - which confirms the metric is active and sane on a real benchmark target
- external benchmark proof also now exists that the lightweight code-hint route model works in CI-backed benchmark artifacts
- current FastAPI hard-target evidence reports:
  - `Code-hinted routes: 15`
  - `Code-hinted observed routes: 9`
  - `Code-hinted unobserved routes: 6`
  - `Code-hinted routes outside spec: 0`
  - which confirms the hint model is active and aligned with the target's documented API surface on a real benchmark target
- a second hard-target proof now exists on Petclinic:
  - `OpenAPI routes observed: 17 / 17`
  - `Code-hinted routes: 17`
  - `Code-hinted observed routes: 17`
  - `Code-hinted unobserved routes: 0`
  - `Code-hinted routes outside spec: 1`
  - undocumented observed routes there are mostly operational/UI surface such as `/actuator/health` and `/swagger-ui/*`
  - which confirms the inventory/hint model can also align cleanly on a Java/Spring target rather than only on FastAPI

### Current limitation
This is inventory and visibility, not yet broader API coverage by itself.
It helps us see importer/discovery gaps clearly, but it does not yet solve them.
It is also not the same thing as full shadow API discovery from production traffic or passive network telemetry.
The current hint model is intentionally lightweight and regex-driven; it is not deep static route analysis across arbitrary frameworks.

## L. Lightweight Environment Model and Result-State Triage

### Status
Implemented as the first Phase 5 operator slice.

### What exists
- environment manifest generation in [build-environment-manifest.js](C:/Java%20Developer/DAST/scripts/build-environment-manifest.js)
- baseline-adjusted result-state generation in [build-result-state.js](C:/Java%20Developer/DAST/scripts/build-result-state.js)
- runtime wiring in [run-dast-env.sh](C:/Java%20Developer/DAST/security/run-dast-env.sh)
- PR and nightly workflow metadata injection in [dast-pr.yml](C:/Java%20Developer/DAST/.github/workflows/dast-pr.yml) and [dast-nightly.yml](C:/Java%20Developer/DAST/.github/workflows/dast-nightly.yml)

### What the core scan now emits
The report bundle now includes operator-facing artifacts:
- `environment-manifest.json`
- `environment-manifest.md`
- `result-state.json`
- `result-state.md`

### What they provide
- a stable description of the scanned environment:
  - target name
  - scan profile
  - scan trigger
  - auth bootstrap mode
  - protected/admin route validation paths
- a stable result-state model after baseline suppressions are applied:
  - `clean`
  - `baseline_only`
  - `needs_triage`

### What this means
ZeroDAST now has the start of an operator model rather than only raw scanner output.
This is the first real step toward:
- lighter-weight environment management
- repeatable triage semantics
- suppression-aware result interpretation

### Current limitation
This is still not:
- diff-aware result comparison
- repo-fleet management
- full remediation/retest workflow orchestration
- enterprise control-plane governance

## M. External-Repo T4 Demonstrations

### Status
Implemented.

### What exists
The repo contains CI-backed external demonstration workflows for:
- Petclinic
- authenticated FastAPI

Current workflow files:
- [petclinic-t4-metadata.yml](C:/Java%20Developer/DAST/.github/workflows/petclinic-t4-metadata.yml)
- [petclinic-t4-scan.yml](C:/Java%20Developer/DAST/.github/workflows/petclinic-t4-scan.yml)
- [fullstack-fastapi-t4-metadata.yml](C:/Java%20Developer/DAST/.github/workflows/fullstack-fastapi-t4-metadata.yml)
- [fullstack-fastapi-t4-scan.yml](C:/Java%20Developer/DAST/.github/workflows/fullstack-fastapi-t4-scan.yml)

### What these prove about current repo capability
- ZeroDAST can clone a frozen external target SHA
- build the target inside CI
- bootstrap auth when needed
- run isolated scans in a trusted second-stage workflow
- upload benchmark artifacts

### Current limitation
This is benchmark-oriented orchestration, not yet a general turnkey multi-repo SaaS/platform control plane.

## N. Model 1 In-Repo Adoption Prototype

### Status
Implemented as alpha prototype.

### What exists
The Model 1 prototype supports:
- thin workflows in target repo
- contained `zerodast/` payload
- config-driven target adaptation
- PR and nightly scan profiles
- artifact runtime mode
- compose runtime mode
- install/uninstall flow
- package/export flow

### What this means
The repo already contains a real in-repo adoption model, but it is still alpha.

### Current limitation
This is not yet a hardened, broad-compatibility product for arbitrary repos.

## O. Benchmarking Capability

### Status
Implemented.

### What exists
The repo contains:
- benchmark protocol
- benchmark results template
- roadmap
- comparison docs
- per-target benchmark result files
- T1-T5 benchmark framing

### What this means
ZeroDAST is already instrumented to compare itself honestly against lighter and more conventional baselines.

## P. Supported Target Classes Today

### Strongest current fit
ZeroDAST is strongest today for:
- small/medium documented REST APIs
- targets that can run in CI without paid infrastructure
- token-bootstrap-friendly authenticated APIs
- repos where OpenAPI exists or route seeding can be made explicit
- public-repo or OSS-friendly workflows where low-noise setup matters

### Moderate fit
- multi-service local stacks with explicit setup and request seeding
- harder benchmark targets where route exercise matters more than alert lift

### Weak or unsupported fit today
- browser-heavy auth flows
- MFA/SSO/SAML/OIDC enterprise identity flows
- GraphQL-first targets
- SOAP/gRPC targets
- large enterprise governance/compliance programs
- shadow API discovery / production traffic discovery

## Q. What ZeroDAST Does Not Currently Provide

The current repo does **not** yet provide:

- generalized multi-role coverage beyond the bounded built-in admin-path contract
- full enterprise authentication handling
- browser automation or recorded login replay
- SSO/SAML/OIDC/MFA support
- GraphQL scanning support
- SOAP or gRPC scanning support
- shadow API / undocumented API discovery from live traffic
- ASPM-style cross-signal correlation
- compliance reporting / policy mapping
- enterprise RBAC/governance control plane
- universal target support across arbitrary stacks

## R. Practical Summary

### Current-state bottom line
ZeroDAST currently **does** implement:
- two-profile CI DAST
- trusted/untrusted workflow separation
- isolated scan runtime
- authenticated scan support
- authz regression checks
- canary verification
- delta and full scan modes
- external-repo CI-backed demonstrations
- alpha in-repo adoption prototype

### Current-state bottom line on auth/admin
ZeroDAST currently **does** support:
- authenticated path coverage
- end-to-end admin path coverage in the core repo implementation for the built-in demo app

ZeroDAST currently **does not yet fully support**:
- generalized multi-role coverage across arbitrary target types

### Current-state bottom line on scope
ZeroDAST is already a serious alpha security engineering system for:
- CI-first DAST on documented REST-style targets
- low-noise OSS/public-repo adaptation
- trusted/isolated scan execution

It is **not yet** a full enterprise DAST platform, and the codebase does not currently justify that claim.
