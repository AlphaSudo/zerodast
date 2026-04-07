# ZeroDAST Benchmark Roadmap

## Purpose

This roadmap defines the path from the current state of ZeroDAST to a completed initial external benchmark and the first public-ready evidence set.

It is intentionally staged.
We are optimizing for honest proof, low-noise adaptation, and reusable engineering work rather than rushing to broad claims.

## Where We Are Now

### Track A: Controlled Self-Validation
- Status: complete and green enough for benchmark use
- What is already proven:
  - local end-to-end ZeroDAST run works on the self-validating demo app
  - SQL Injection is detected
  - Cross Site Scripting is detected
  - Application Error Disclosure is detected
  - IDOR/authz behavior is detected by the authz checks
  - repeated local runs have succeeded
  - GitHub nightly path works and preserves findings visibility

### Track B: Real Public Repository Validation
- Repo 1: `spring-petclinic/spring-petclinic-rest`
  - frozen SHA: `155f89a08828386493c27b5584cd2a93d0dcfc39`
  - T1: complete
  - T2: complete
  - T3: complete
  - current verdict: T3 improved API reach over T1/T2, but only modestly
- Repo 2: `AlphaSudo/EventDebug`
  - frozen SHA: `090e249dbbb6d63f8a6d28e8c9bfe3e105b7def6`
  - T1: not started
  - T2: not started
  - T3: not started

## Guiding Principles

- Keep target repositories clean.
  ZeroDAST-specific benchmark machinery should stay in a contained root-level folder on the ZeroDAST side whenever possible.
- Prefer reusable adaptation patterns over one-off hacks.
- Record failure and friction honestly.
- Treat real-repo findings as candidate findings unless independently validated.
- Do not overclaim from two repositories.

## Benchmark Tiers We Are Using

### T1
- plain scanner baseline
- minimal setup
- no trusted/untrusted split
- measures lowest-friction reach

### T2
- lightweight scripted or CI-like harness
- structured artifacts and summary output
- still not the full ZeroDAST framework
- measures low-overhead maintainable automation

### T3
- ZeroDAST-style isolated adaptation
- dedicated runtime isolation
- repo-aware request seeding and route handling
- contained artifacts
- measures whether ZeroDAST materially improves reach and usefulness

### T4
- optional extended/full-framework port
- only justified after T1-T3 comparison on both real repositories
- may include full GitHub workflow separation, artifact handoff, auth/bootstrap, and repo-specific higher-order features

## Phase Plan

## Phase 1: Lock Petclinic as the Reference External Baseline

### Goal
Use Petclinic as the completed first benchmark repository and reference point for comparison.

### Status
- complete through T3

### Remaining work in this phase
1. Run one repeat T3 execution for stability confirmation.
2. Decide whether to perform a light T3 refinement pass on Petclinic.
3. Freeze the Petclinic result as the comparison baseline before moving into interpretation drift.

### Decision Gate
- If a repeat T3 run is materially unstable, fix T3 before comparing EventDebug.
- If repeat T3 is stable, do not keep polishing Petclinic indefinitely.

## Phase 2: Profile EventDebug

### Goal
Turn EventDebug from a frozen target into a profiled benchmark target with real setup assumptions.

### Deliverables
- stack summary
- API surface summary
- auth model summary
- runtime prerequisites
- benchmark execution assumptions added to `docs/benchmarks/eventdebug.md`

### Exit Criteria
- We know how to boot it.
- We know where the HTTP API lives.
- We know whether auth is required.
- We know whether secrets or local services are required.

## Phase 3: Execute EventDebug T1

### Goal
Produce the plain-scanner baseline on EventDebug.

### Deliverables
- benchmark notes for T1
- raw timing
- route reach notes
- first report artifacts

### What We Are Measuring
- fastest time to first report
- whether scanner reaches documented routes at all
- whether auth is a blocker
- whether any immediate compatibility problems appear

### Exit Criteria
- T1 either completes with usable artifacts or fails with a clearly documented blocker

## Phase 4: Execute EventDebug T2

### Goal
Build the lightweight harness version for EventDebug.

### Deliverables
- contained T2 runner under a benchmark folder
- structured artifacts and summary output
- updated `docs/benchmarks/eventdebug.md`

### What We Are Measuring
- engineering effort to move from manual T1 to repeatable low-overhead automation
- artifact quality
- whether T2 improves usability even if scanner depth does not improve yet

### Exit Criteria
- single-command T2 harness exists and produces summary + report artifacts

## Phase 5: Execute EventDebug T3

### Goal
Build the ZeroDAST-style isolated adaptation for EventDebug.

### Deliverables
- isolated runtime harness
- target-aware route/auth/bootstrap handling as needed
- structured T3 artifacts
- updated benchmark result sheet

### What We Are Measuring
- whether ZeroDAST materially improves authenticated coverage, route reach, or output quality on EventDebug
- how much target-specific adaptation is needed
- whether EventDebug or Petclinic is the stronger benchmark demonstration target

### Exit Criteria
- T3 either shows measurable value over T1/T2 or we document precisely why it does not

## Phase 6: Compare Petclinic and EventDebug

### Goal
Produce the first meaningful cross-repository interpretation.

### Deliverables
- side-by-side comparison section or dedicated comparison doc
- adaptation effort comparison
- runtime comparison
- reach/output comparison
- clear statement of where ZeroDAST helped and where it did not

### Questions To Answer
- Did T3 beat T1/T2 on both repositories?
- Did the improvement show up in reach, output quality, or both?
- Which repo better demonstrates the value of ZeroDAST?
- Which repo exposed the hardest friction point?

### Exit Criteria
- We can explain the cross-repo story in a disciplined public way

## Phase 7: Choose the CI Demonstration Target

### Goal
Pick one repository for the first full CI demonstration.

### Recommendation
- choose the repository where T3 most clearly demonstrates value with acceptable setup effort

### Why only one first
- keeps engineering cost contained
- avoids duplicating GitHub-specific plumbing before we know where it helps most
- keeps the benchmark story clean

### Exit Criteria
- one repo is selected as the first CI proof target

## Phase 8: Full CI Demonstration on the Chosen Repo

### Goal
Move one real repo beyond local T3 into an actual GitHub workflow proof path.

### Scope
Potential features, depending on repo needs:
- trusted/untrusted workflow separation
- artifact handoff between lanes
- isolated app + scanner runtime
- auth/bootstrap automation if needed
- report artifact upload
- PR/nightly summary behavior
- findings visibility without misleading hard-failure semantics

### This phase is the first place where we may benchmark something close to the full ZeroDAST framework port.

### Exit Criteria
- one real repository has a stable CI-backed ZeroDAST demonstration path

## Phase 9: Decide Whether We Need T4 / Full Framework Port on the Second Repo

### Goal
Avoid accidental overengineering.

### Decision Rule
Only do this if at least one of the following is true:
- the first CI-backed repo is not enough to demonstrate the value convincingly
- the second repo has materially different auth/runtime characteristics that matter to the product story
- we need broader evidence before public messaging

### Exit Criteria
- either explicitly skip T4 for now or define a second full-framework target

## Phase 10: Publish the Initial Two-Repo Benchmark Set

### Goal
Produce the public evidence package.

### Deliverables
- completed benchmark result sheets for both repos
- side-by-side comparison summary
- concise benchmark narrative in README or docs
- explicit caveats on scope and validation limits

### Claims This Stage Supports
- ZeroDAST works beyond its self-validating demo
- ZeroDAST can be adapted to at least two real repositories
- ZeroDAST-style adaptation can improve reach/usefulness over lighter tiers on real targets

### Claims This Stage Does Not Yet Support
- universal ecosystem coverage
- broad superiority over all DAST approaches
- fully validated accuracy across arbitrary repos
- production readiness for all organizations

## Phase 11: Expand Beyond the Initial Two Repos

### Goal
Earn stronger external claims over time.

### Suggested next expansion
- reach 10+ repos across multiple stacks
- include more auth-protected targets
- repeat CI-backed proofs on more than one repo
- start tracking false positives, false negatives, and maintainer validation where possible

### This is the phase required before stronger market-facing claims become credible.

## Immediate Next Steps

1. Run one repeat Petclinic T3 stability check.
2. Profile EventDebug and fill in its benchmark assumptions.
3. Execute EventDebug T1.
4. Execute EventDebug T2.
5. Execute EventDebug T3.
6. Compare Petclinic vs EventDebug.
7. Choose one repo for the first full CI-backed ZeroDAST demonstration.

## What “Done” Means For The Initial Benchmark

The initial benchmark is done when all of the following are true:
- Track A remains green and reproducible.
- Petclinic has completed T1-T3 with published results.
- EventDebug has completed T1-T3 with published results.
- A cross-repo comparison exists.
- At least one real repository has a credible CI-backed ZeroDAST demonstration path or we explicitly document why that step is deferred.
- Public messaging is updated to match the real evidence and its limits.
