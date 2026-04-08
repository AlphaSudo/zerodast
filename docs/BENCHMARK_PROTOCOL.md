# ZeroDAST Benchmark Protocol

## Purpose

This document defines the first public benchmark protocol for ZeroDAST.
It is intentionally conservative: two real public repositories are enough for an initial validation pass, but not enough to justify broad universal claims.

This benchmark exists to answer two different questions:
- Can ZeroDAST reliably detect the intentional benchmark vulnerabilities on a controlled target?
- Can ZeroDAST be adapted to real public repositories with acceptable setup cost, stable execution, and useful output?

## Claims This Benchmark Can Support

If the benchmark succeeds, we may reasonably claim:
- ZeroDAST works end-to-end locally and on GitHub Actions.
- ZeroDAST can be adapted to at least two real public repositories.
- ZeroDAST can preserve CI isolation boundaries while producing useful DAST artifacts and triage output.
- ZeroDAST is a credible T3 reference implementation for documented REST-style applications.

This benchmark does **not** by itself justify claims such as:
- universal coverage across arbitrary stacks
- superior detection accuracy across the ecosystem
- production readiness for all organizations
- proof that any scanner findings are true positives unless independently validated

## Benchmark Structure

The benchmark has two tracks.

### Track A: Controlled Self-Validation

Track A uses the built-in demo app and proves that the benchmark harness itself still works.
This is the only track where we have ground-truth vulnerabilities.

Required outcomes:
- SQL Injection is detected.
- Cross Site Scripting is detected.
- Application Error Disclosure is detected.
- IDOR/authz behavior is detected by the scripted authz checks.
- three consecutive local full runs succeed.
- GitHub nightly succeeds while preserving findings visibility.

Track A is the harness-validation track.
It measures benchmark integrity, not product generality.

### Track B: Real Public Repository Validation

Track B measures whether ZeroDAST can be adapted to real public repositories with bounded effort and stable behavior.
Because we usually do not know ground-truth vulnerabilities in advance, this track measures operational quality and output quality rather than recall.

Initial repository set:
- Repo 1: `AlphaSudo/EventDebug`
- Repo 2: one additional public repository selected using the repository selection rules below

## Repository Selection Rules for Repo 2

The second public repository should satisfy most of the following:
- public GitHub repository
- documented HTTP API or Swagger/OpenAPI surface
- runnable locally or in GitHub Actions with reasonable setup effort
- active enough to be realistic, but small/medium enough to finish within benchmark time budgets
- not intentionally vulnerable by design
- not dependent on paid SaaS or inaccessible infrastructure just to boot the app

Avoid repositories that are:
- only frontend applications
- monoliths with opaque manual setup and no API documentation
- intentionally vulnerable training apps
- dependent on unavailable credentials or private cloud infrastructure

## Tier Definitions

The five tiers must be run using the same target repository snapshot and documented setup assumptions.

### T1: Basic Scanner Only

Definition:
- run a scanner against the target app with minimal setup
- no trusted/untrusted workflow split
- no overlay validation
- no special auth scripting beyond the bare minimum needed to reach the app

Measures:
- fastest time to first report
- lowest isolation
- lowest engineering effort

### T2: Scanner + Light CI Gating

Definition:
- scanner integrated into CI with modest policy controls
- some setup automation and artifact handling
- still broad trust in the CI path
- no strong separation between untrusted code handling and privileged scan steps

Measures:
- moderate setup cost
- moderate repeatability
- moderate safety posture

### T3: ZeroDAST-Style Local Adaptation

Definition:
- trusted/untrusted workflow separation
- artifact handoff between CI lanes
- isolated scan runtime
- auth adaptation
- seed/overlay validation where applicable
- delta/full scan strategy
- canary or capability verification where applicable

Measures:
- strongest local ZeroDAST posture in this repository
- moderate/high engineering complexity with zero software licensing cost

### T4: Full CI-Backed ZeroDAST

Definition:
- trusted/untrusted workflow separation
- artifact handoff between workflow lanes
- isolated runtime orchestration in CI
- auth/bootstrap automation where needed
- benchmark artifacts and maintainer-friendly reporting

Measures:
- strongest proven ZeroDAST posture
- stronger proof than local tiers
- higher engineering cost than T1-T3, but still zero direct tooling license cost

### T5: Conventional Public-Repo DAST Baseline

Definition:
- the fair, competent normal way a serious engineer would add DAST to the target repo today without ZeroDAST
- scanner/workflow logic lives in the target repository
- no ZeroDAST-specific trusted orchestrator repo
- may use the target repo's normal CI, conventional marketplace actions, or a mainstream enterprise-style pattern
- must be implemented honestly, not as a strawman

Measures:
- setup burden in the repo maintainers' normal world
- typical trust assumptions for in-repo/public-repo DAST
- whether ZeroDAST is near-lossless in signal while reducing setup noise and operational overhead

## Benchmark Metrics

### 1. Adaptation Effort

Record:
- engineer hours to first passing run
- files created or modified
- manual target-specific knowledge required
- whether auth/bootstrap adaptation was needed

### 2. Runtime and Stability

Record:
- cold-run duration
- warm-run duration
- three consecutive run success rate where feasible
- flaky step count
- retries or manual intervention required

### 3. Coverage Reach

Record:
- number of documented routes reached
- whether authenticated endpoints were reached
- whether protected endpoints were scanned with valid session/auth context
- whether post-scan authz checks could be executed

### 4. Output Usefulness

Record:
- number of findings by severity
- whether output included actionable file/endpoint context
- whether results were reproducible on rerun
- whether issue/comment/report artifacts were easy to consume

### 5. Security Posture of the Pipeline

Record:
- whether untrusted code executed in a privileged context
- whether workflow separation was preserved
- whether artifact handoff was used
- whether the app/DB/scanner were isolated in the runtime network
- whether target-specific secrets were required

## Ground-Truth Rules

Ground truth exists only for Track A unless a real repository maintainer explicitly confirms a finding.

For Track B:
- treat findings as candidate findings, not confirmed vulnerabilities
- measure stability, reach, and usefulness
- do not score "missed vulns" unless there is external evidence of a known issue
- do not turn unverified alerts into marketing claims

## Execution Rules

For each real repository:
1. Freeze a target commit SHA.
2. Record prerequisites and local run assumptions.
3. Run T1 through T5 against the same snapshot where feasible.
4. Capture exact runtime logs, artifact outputs, and configuration deltas.
5. Record failures honestly, including setup dead ends.
6. Repeat the best-performing tier at least once to check reproducibility.

## Required Deliverables

For each repository, publish:
- repository profile summary
- adaptation diff summary
- benchmark table with all tier results
- setup notes and blockers
- raw timing numbers
- finding summary with explicit caveats
- final recommendation: suitable / suitable with caveats / not suitable

## Pass Criteria for the Initial Two-Repo Benchmark

The initial benchmark is a success if:
- Track A remains fully green
- ZeroDAST completes on both real repositories
- authenticated coverage is demonstrated where the target requires auth
- GitHub workflow execution is stable on at least one real repository
- the published results are honest about unknowns and false-positive risk

## Failure Criteria

The benchmark should be considered failed or incomplete if:
- ZeroDAST cannot be adapted to one of the two real repositories within the documented effort budget
- authenticated routes cannot be reached and there is no fallback evaluation plan
- workflow isolation must be weakened to make the scan work
- the benchmark results rely on unverified vulnerability claims

## Initial Messaging Guidance

If the two-repo benchmark succeeds, describe it as:
- an initial external validation set
- a two-repo benchmark pass
- evidence that ZeroDAST can be adapted beyond its self-validating demo

Do not describe it as:
- comprehensive proof
- universal benchmark leadership
- broad ecosystem validation
