# Petclinic T5 Design

## Purpose

This document defines `T5` for [spring-petclinic/spring-petclinic-rest](https://github.com/spring-petclinic/spring-petclinic-rest) as a **benchmark-only conventional DAST baseline**.

It is intentionally **not** part of the ZeroDAST product architecture.
It exists only to answer a benchmark question:

> compared with a fair conventional public-repo DAST setup, is ZeroDAST near-lossless in signal while being easier to adapt, less noisy, and cleaner in trust posture?

## Non-Goals

`T5` is not:
- a ZeroDAST feature
- a ZeroDAST deployment mode
- part of the ZeroDAST adoption kit
- part of the ZeroDAST in-repo model
- a strawman baseline built to make ZeroDAST look better

If `T5` is not credible on its own, the comparison is not worth publishing.

## Boundary Rule

The benchmark boundary must stay explicit:

- `T4` = ZeroDAST
- `T5` = non-ZeroDAST conventional baseline

`T5` should never be described as “another ZeroDAST tier” in product terms.
It is only a comparison instrument inside the benchmark.

## What T5 Should Represent

For Petclinic, `T5` should represent:
- a serious in-repo/public-repo DAST setup
- a pattern recognizable to OSS maintainers or enterprise AppSec engineers
- the kind of workflow a strong engineer might actually add directly to the target repo today

That means:
- scanner logic lives in the target repo or in target-repo CI config
- no external ZeroDAST orchestrator repo
- no ZeroDAST trusted split
- no ZeroDAST-owned benchmark harness logic presented as if it were normal

## Fairness Criteria

To count as a valid `T5` baseline, the implementation must be:

### 1. Competent

It must use the target repo reasonably well:
- use the documented app startup path
- use the documented OpenAPI surface if available
- use a scanner/runtime setup a serious engineer would consider acceptable
- avoid obviously broken or intentionally weak defaults

### 2. Recognizable

A skeptical engineer should be able to look at it and say:

> yes, this is a fair normal baseline

It should resemble:
- a mainstream GitHub Actions DAST workflow
- or a normal enterprise/open-source style in-repo scanner setup

### 3. Non-ZeroDAST

It must not import the product architecture we are trying to compare against.

Avoid:
- trusted/untrusted workflow split copied from ZeroDAST
- ZeroDAST artifact handoff model
- ZeroDAST-specific runner structure
- ZeroDAST-specific benchmark helper abstractions

### 4. Truthful

If the baseline is weaker in some dimension, that weakness must be natural to the conventional pattern, not introduced on purpose.

## Recommended Petclinic T5 Shape

For Petclinic, the fairest first `T5` shape is:

- a target-repo-local GitHub Actions workflow
- direct scanner execution in the same repo/workflow context
- app build + runtime boot in the same CI lane
- ZAP scan driven by the repo’s own CI workflow
- report artifact upload and summary output

This is a recognizable mainstream baseline:
- easy to understand
- easy to compare against `T4`
- not artificially weak

## Implementation Choice

The first concrete Petclinic `T5` implementation uses:
- a fresh benchmark-only clone at the frozen Petclinic SHA
- a single target-repo-local GitHub Actions workflow: `.github/workflows/zap-api-scan.yml`
- the documented Maven/JAR startup path
- the official ZAP API Scan GitHub Action against `http://localhost:9966/petclinic/v3/api-docs`

This keeps the baseline conventional:
- no external orchestrator repo
- no trusted/untrusted workflow split
- no ZeroDAST helper folder inside the target repo
- no benchmark-specific runner abstraction disguised as “normal CI”

The workflow footprint is intentionally small so the comparison against `T4` remains about real tradeoffs, not about us padding the baseline.

## What T5 Should Measure Against T4

The benchmark comparison should focus on:

### Setup Burden
- time to first passing run
- number of files added
- how invasive the target-repo changes are

### Repo Noise
- how many files live in the target repo
- whether the setup feels intrusive or clean
- how easy it is to remove later

### Trust Posture
- whether untrusted code and privileged scan behavior are separated
- whether the baseline relies on broad in-repo trust assumptions

### Runtime Behavior
- cold run time
- repeatability
- flake rate

### Signal Quality
- API alert URI count
- presence of API-side findings
- whether the output is materially weaker, similar, or stronger than `T4`

## Success Criteria

Petclinic `T5` is successful when:
- the baseline is clearly non-ZeroDAST
- the setup is credible and recognizable
- it runs end to end on the frozen Petclinic SHA
- it produces benchmark-comparable artifacts and summary data
- we can compare it honestly against `T4`

## Failure Criteria

Petclinic `T5` should be rejected if:
- it quietly reuses ZeroDAST architecture and just renames it
- it is obviously underpowered or misconfigured
- it cannot be defended as a fair mainstream baseline
- it creates so much custom benchmark scaffolding that it stops being “normal”

## Recommendation

Implement Petclinic `T5` as a **clean in-repo conventional GitHub Actions DAST baseline**, and keep the benchmark wording explicit:

`T5` is a comparison baseline only.
It is not part of ZeroDAST itself.
