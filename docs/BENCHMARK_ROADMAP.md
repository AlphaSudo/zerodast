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
  - T1: complete
  - T2: complete
  - T3: complete
  - current verdict: T3 improved runtime quality and isolation, but not API-side findings

### Track C: Authenticated Public Repository Validation
- Repo 3: `fastapi/full-stack-fastapi-template`
  - frozen SHA: `bba8d07c0cb4ac0e38a99d1de38090048fab8dee`
  - current role: first authenticated showcase candidate
  - benchmark goal: prove ZeroDAST on a non-Java auth-protected target with documented Docker/OpenAPI/JWT flows

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
- ZeroDAST-style isolated local adaptation
- dedicated runtime isolation
- repo-aware request seeding and route handling
- contained artifacts
- measures whether ZeroDAST materially improves reach and usefulness

### T4
- first full CI-backed real-repo ZeroDAST demonstration
- justified now that T1-T3 are complete on benchmark repos
- expected to include trusted/untrusted workflow separation, artifact handling, isolated runtime orchestration, and public-friendly reporting semantics

### T5
- fair conventional public-repo DAST baseline
- scanner/workflows live in the target repo or follow the normal in-repo or enterprise-style pattern
- used to test the actual product thesis:
- whether ZeroDAST is near-lossless in signal while being easier to set up and lower-noise to maintain

## Phase Plan

## Phase 1: Lock Petclinic as the Reference External Baseline

### Goal
Use Petclinic as the completed first benchmark repository and reference point for comparison.

### Status
- complete through T3
- ready to serve as the first T4 candidate

## Phase 2: Profile EventDebug

### Goal
Turn EventDebug from a frozen target into a profiled benchmark target with real setup assumptions.

### Status
- complete

## Phase 3: Execute EventDebug T1

### Goal
Produce the plain-scanner baseline on EventDebug.

### Status
- complete

### Outcome
- operationally successful
- API-shallow
- required network-side access and sanitized OpenAPI

## Phase 4: Execute EventDebug T2

### Goal
Build the lightweight harness version for EventDebug.

### Status
- complete

### Outcome
- operationally cleaner than T1
- no finding-lift improvement over T1

## Phase 5: Execute EventDebug T3

### Goal
Build the ZeroDAST-style isolated adaptation for EventDebug.

### Status
- complete

### Outcome
- strongest runtime/isolation result on this repo
- no API-side finding lift over T1/T2

## Phase 6: Compare Petclinic and EventDebug

### Goal
Produce the first meaningful cross-repository interpretation.

### Status
- complete

### Deliverable
- [BENCHMARK_COMPARISON.md](C:/Java%20Developer/DAST/docs/BENCHMARK_COMPARISON.md)

### Conclusion
- Petclinic is the clearer value-demonstration repo.
- EventDebug is the stronger stress-test repo.
- T4 should be a full CI-backed demonstration on Petclinic first.

## Phase 7: Choose the CI Demonstration Target

### Goal
Pick one repository for the first full CI demonstration.

### Status
- completed on `spring-petclinic/spring-petclinic-rest`
- completed on `fastapi/full-stack-fastapi-template`

### Why this mattered
- it established the strongest ZeroDAST proof tier on both an unauthenticated Java target and an authenticated non-Java target

## Phase 8: Full CI Demonstration on Chosen Repos

### Goal
Move real repos beyond local T3 into actual GitHub workflow proof paths.

### Status
- complete for Petclinic T4
- complete for authenticated FastAPI T4

### Exit Criteria
- at least one real repository has a stable CI-backed ZeroDAST demonstration path

## Phase 9: Keep EventDebug as the Stress-Test Benchmark

### Goal
Avoid accidental overengineering while preserving a hard target in the benchmark set.

### Current recommendation
- defer full CI-backed EventDebug work for now
- keep EventDebug as the stress-test benchmark target

## Phase 10: Publish the Initial External Benchmark Set

### Goal
Produce the public evidence package.

### Deliverables
- completed benchmark result sheets for benchmark repos
- side-by-side comparison summary
- concise benchmark narrative in README or docs
- explicit caveats on scope and validation limits

### Claims This Stage Supports
- ZeroDAST works beyond its self-validating demo
- ZeroDAST can be adapted to multiple real repositories
- ZeroDAST-style adaptation can improve reach/usefulness over lighter tiers on real targets
- the form of the improvement is target-dependent

### Claims This Stage Does Not Yet Support
- universal ecosystem coverage
- broad superiority over all DAST approaches
- fully validated accuracy across arbitrary repos
- production readiness for all organizations

## Phase 11: Add the T5 Comparison Layer

### Goal
Make the benchmark answer “is ZeroDAST better than the normal way?” instead of only “does ZeroDAST work?”

### First T5 candidates
- `spring-petclinic/spring-petclinic-rest`
- `fastapi/full-stack-fastapi-template`

### Exit Criteria
- a fair T5 baseline exists for at least one Java target and one authenticated non-Java target
- T4 vs T5 comparison is documented with:
  - setup time
  - repo footprint
  - trust posture
  - runtime
  - signal/output comparison

## Phase 12: Expand Beyond the Initial Repo Set

### Goal
Earn stronger external claims over time.

### Suggested next expansion
- reach 10+ repos across multiple stacks
- include more auth-protected targets
- repeat CI-backed proofs on more than one repo
- start tracking false positives, false negatives, and maintainer validation where possible

### This is the phase required before stronger market-facing claims become credible.

## Immediate Next Steps

1. Use [BENCHMARK_COMPARISON.md](C:/Java%20Developer/DAST/docs/BENCHMARK_COMPARISON.md) as the reference interpretation.
2. Add `T5` as the fair conventional comparison layer for Petclinic and the authenticated FastAPI target.
3. Keep EventDebug frozen as the stress-test benchmark until we need a second CI-backed proof or better real-repo success metrics.
4. After T4/T5 comparisons exist, update README/public messaging to match the benchmark evidence.

## What "Done" Means For The Initial Benchmark

The initial benchmark is done when all of the following are true:
- Track A remains green and reproducible.
- Petclinic has completed T1-T4 with published results.
- FastAPI has completed T1-T4 with published results.
- EventDebug remains documented as the stress-test benchmark.
- A cross-repo comparison exists.
- At least one fair T5 baseline has been implemented for comparison.
- Public messaging is updated to match the real evidence and its limits.
