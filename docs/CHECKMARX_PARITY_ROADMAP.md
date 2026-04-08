# ZeroDAST to 90-95% Checkmarx Parity Roadmap

## Scope

This roadmap is **not** a claim that ZeroDAST can realistically reach 90-95% of the full Checkmarx platform in the short term.

It is a roadmap for reaching **90-95% of Checkmarx-level capability for ZeroDAST's target niche**:
- CI-first DAST
- public-repo and OSS-friendly workflows
- small/medium web apps and documented APIs
- mostly REST-first targets
- fast pull-request scans
- bounded nightly scans
- lower setup and operational overhead than enterprise platforms

This is a narrower and more honest target than:
- full enterprise AppSec platform parity
- broad SSO/MFA/browser-automation parity
- full governance/compliance/RBAC/ASPM parity

## Current Estimate

### Where ZeroDAST stands today

Estimated relative to Checkmarx-style enterprise DAST:

- **Overall enterprise parity:** `45-55%`
- **Within ZeroDAST's target niche:** `65-75%`

The repo already proves:
- two-profile CI DAST
- strong trusted/untrusted workflow separation
- authenticated CI-backed DAST on at least one non-Java target
- low-noise external orchestration
- early in-repo adoption model

The biggest current gaps are:
- admin/role-aware scan coverage
- richer auth handling beyond simple seeded token flows
- better API breadth and discovery
- stronger environment, result-management, and operational control-plane features

## Time Budget Constraint

To preserve the product thesis, every phase must protect these budgets:

- **PR scan target:** under `10 minutes`
- **Nightly/full target:** under `15 minutes`, with `15` as a hard ceiling

That means new capability must be split deliberately between profiles:

### PR Profile
- delta-focused
- shallow but meaningful auth proof
- limited active scan time
- route-seeded rather than broad crawl-led
- optimized for useful signal, not exhaustive depth

### Nightly Profile
- broader coverage
- richer auth and role coverage
- heavier active scan policy
- more route exploration
- still bounded tightly enough to stay inside the nightly budget

## Phase Plan

## Phase 1: Role-Aware Auth Coverage

### Goal
Turn ZeroDAST from "authenticated user coverage" into "role-aware authenticated coverage" for token-bootstrap-friendly targets.

### What to build
- admin seed user in the demo path if not already present
- admin token bootstrap alongside existing seeded users
- admin-only request seeding into scan config
- post-scan verification that an admin-only route was exercised
- benchmark proof on at least one real target with privileged/admin routes

### What this adds
- closes the biggest credibility gap in the current CI DAST model
- moves ZeroDAST much closer to enterprise-style authenticated scanning
- makes the repo materially more credible against role-aware enterprise DAST expectations

### Time estimate
- `2-4 weeks`

### PR impact
- likely `+15s` to `+60s`
- central estimate: `+25s` to `+40s`

### Nightly impact
- likely `+15s` to `+90s`
- central estimate: `+30s` to `+60s`

### Exit criteria
- PR and nightly both preserve timing budgets
- admin route exercise is explicitly proven in CI
- benchmark docs distinguish user-path and admin-path coverage

### Estimated parity gain
- **Overall:** `+5-8%`
- **Target niche:** `+8-10%`

## Phase 2: Scan-Quality Uplift Without PR Regression

### Goal
Improve signal quality without turning the PR lane into a slow full scan.

### What to build
- smarter delta-to-route mapping
- better request seeding from OpenAPI and changed endpoints
- stronger per-profile scan budgets
- per-target success modes that distinguish:
  - route exercise
  - authenticated route exercise
  - alert-bearing signal
- improved artifact summaries for fast PR triage

### What this adds
- better evidence that ZeroDAST is near-lossless for practical CI gating
- less ambiguity about whether a scan was weak because the target was hard, the routes were not reached, or the findings were not present

### Time estimate
- `3-5 weeks`

### PR impact
- likely net impact: `0s` to `+45s`
- central estimate: `+15s` to `+30s`

### Nightly impact
- likely net impact: `+10s` to `+90s`
- central estimate: `+30s` to `+60s`

### Exit criteria
- better benchmark outcomes on at least two external targets
- no PR budget regression past `10 min`
- clearer signal reporting in artifacts and summaries

### Estimated parity gain
- **Overall:** `+4-6%`
- **Target niche:** `+5-8%`

## Phase 3: Richer Authentication Adapters

### Goal
Expand beyond simple seeded bearer-token login.

### What to build
- reusable auth adapter interface
- cookie/session support
- multi-step login scripting
- refresh-token/session-refresh handling
- target-specific auth profiles
- better protected-route validation before scan launch
- explicit separation between simple seeded auth and richer enterprise-style auth adapters

### What this adds
- support for many more real public repos
- stronger resemblance to serious enterprise authenticated DAST

### What this does not yet mean
- not full SSO/MFA/browser-recorded parity
- not full enterprise identity-platform parity

### Time estimate
- `4-8 weeks`

### PR impact
- likely `+20s` to `+75s`
- central estimate: `+30s` to `+50s`
- browser-grade auth in PR should be avoided because it could exceed this

### Nightly impact
- likely `+45s` to `+180s`
- central estimate: `+60s` to `+120s`

### Exit criteria
- at least 3 auth styles supported cleanly
- at least 2 non-demo external repos use nontrivial auth adapters
- PR lane still stays under budget

### Estimated parity gain
- **Overall:** `+6-10%`
- **Target niche:** `+8-12%`

## Phase 4: API Breadth and Discovery Improvements

### Goal
Reduce the current gap around API coverage breadth.

### What to build
- stronger OpenAPI normalization and ingestion
- GraphQL support
- better undocumented-route discovery using:
  - traffic/requestor evidence
  - code/spec hints
  - route extraction hints
- better API inventory in artifacts

### What this adds
- stronger API-centric DAST story
- better real-repo coverage on targets where the current OpenAPI import is weak

### Time estimate
- `6-10 weeks`

### PR impact
- likely `+20s` to `+90s`
- central estimate: `+30s` to `+60s`
- must be tightly budgeted in PR

### Nightly impact
- likely `+60s` to `+240s`
- central estimate: `+90s` to `+180s`, while still staying inside the `15 min` cap

### Exit criteria
- API discovery quality improves on hard targets
- GraphQL-capable path exists
- OpenAPI/importer fragility is reduced materially

### Estimated parity gain
- **Overall:** `+5-8%`
- **Target niche:** `+6-10%`

## Phase 5: Lightweight Environment Model and Control Plane Maturity

### Goal
Approach enterprise usability without becoming enterprise-bloated, especially around environment management, triage, and operator workflow.

### What to build
- lightweight environment model for onboarded targets
- better suppression and baseline management
- cleaner diff-aware result comparison
- richer issue/comment/report policies
- simple repo-fleet tracking for multiple onboarded targets
- explicit result-state / triage workflow model
- remediation + retest workflow guidance
- operational reliability tracking

### What this adds
- stronger day-2 usability
- a more serious product surface for maintainers and teams
- closer alignment with the environment-centric and triage-centric shape visible in enterprise DAST products

### What it still does not add
- full ASPM parity
- enterprise compliance mapping parity
- full RBAC/governance platform parity
- full enterprise organization model parity

### Time estimate
- `4-8 weeks`

### PR impact
- likely `+5s` to `+25s`
- central estimate: `+10s` to `+15s`

### Nightly impact
- likely `+15s` to `+60s`
- central estimate: `+20s` to `+40s`

### Exit criteria
- multiple repos can be managed without ad hoc manual triage
- repeated runs and result deltas are easy to reason about
- maintainers get more actionable outputs with less noise

### Estimated parity gain
- **Overall:** `+4-7%`
- **Target niche:** `+4-7%`

## Phase Summary

| Phase | Est. Time | Primary Gain | Expected Niche Parity |
| --- | --- | --- | --- |
| Phase 1 | `2-4 weeks` | user/admin role-aware auth coverage | `73-85%` |
| Phase 2 | `3-5 weeks` | better scan quality within CI budgets | `78-88%` |
| Phase 3 | `4-8 weeks` | richer auth adapters | `84-92%` |
| Phase 4 | `6-10 weeks` | API breadth and discovery | `88-95%` |
| Phase 5 | `4-8 weeks` | operational maturity and control-plane polish | `90-95%` |

## Realistic Totals

- **Lean path:** `4-6 months`
- **Realistic path:** `6-9 months`

These estimates assume focused implementation work and benchmark validation, not casual spare-time iteration.

## What 90-95% Means Here

If the roadmap succeeds, the 90-95% claim should be phrased like this:

> ZeroDAST reaches roughly 90-95% of enterprise-grade DAST capability for CI-first scanning of small/medium documented web apps and APIs, especially REST-first targets with simple-to-moderate auth, while staying lower-noise and easier to adopt than enterprise platforms.

That is a very different claim from:

> ZeroDAST is 90-95% of the full Checkmarx platform.

The latter would not be honest.

## What This Roadmap Does Not Promise

Even at roadmap completion, ZeroDAST would still likely remain behind Checkmarx on:
- SSO/SAML/OIDC/MFA depth
- browser-recorded auth complexity
- shadow/zombie API discovery maturity
- SOAP/gRPC breadth
- ASPM-style risk correlation
- compliance and governance reporting
- enterprise RBAC and organizational policy enforcement

Those are likely **later-stage** efforts, not part of the near-term 90-95% niche-parity roadmap.

## Knowledge Boundary

This roadmap is based on:
- public Checkmarx product and documentation material
- public DAST best practices
- the actual ZeroDAST repository and benchmark evidence

It is **not** based on private Checkmarx implementation details.

So the roadmap is:
- informed
- credible
- actionable

but not based on proprietary internal knowledge.


