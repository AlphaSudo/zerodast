# Petclinic T4 Design

## Purpose

This document defines `T4` for [spring-petclinic/spring-petclinic-rest](https://github.com/spring-petclinic/spring-petclinic-rest) as the **first full CI-backed ZeroDAST demonstration on an external repository**.

It is deliberately narrower than “every possible ZeroDAST feature ever built.”
The goal is to prove the real operating model on a public repo with:
- minimal repo mess
- explicit trust boundaries
- contained runtime orchestration
- understandable workflow semantics

## Why Petclinic First

Petclinic is the right first `T4` target because:
- it already showed a real `T1 -> T2 -> T3` improvement gradient
- it has a stable documented REST surface
- it does not require auth for the first credible demonstration
- it is easier to explain publicly than EventDebug
- it gives us a better chance of a clean CI-backed proof before we tackle harder stress-test repos

## T4 Definition

For this benchmark, `T4` means:

> a GitHub CI-backed ZeroDAST workflow on Petclinic that preserves the main ZeroDAST architectural ideas: trust separation, contained orchestration, reproducible artifacts, repo-aware scanning, and maintainer-friendly result semantics.

## What T4 Must Include

## 1. Trusted / Untrusted Execution Split

The design should separate the low-trust trigger path from the higher-trust scan execution path.

The practical goal is:
- avoid blindly executing the full scan logic directly from untrusted PR context
- make the boundary reviewable and minimal

Expected shape:
- workflow A: low-trust metadata/trigger lane
- workflow B: trusted scan lane consuming the minimum necessary handoff

This does **not** have to copy the demo repo’s workflows line for line.
It does have to preserve the security intent.

## 2. Contained Target Runtime

Petclinic should be launched in a contained scan runtime rather than relying on arbitrary runner host state.

Expected properties:
- app boot is scripted and reproducible
- scan runtime owns the app lifecycle for the job
- report generation does not depend on leftovers from previous jobs

## 3. Repo-Aware Path Handling

The implementation must preserve the Petclinic-specific target shape:
- app base path: `/petclinic`
- OpenAPI JSON: `/petclinic/v3/api-docs`
- API routes: `/petclinic/api/*`

This includes preserving any OpenAPI compatibility shim needed for scanner stability.

## 4. Request Seeding

T4 should preserve the request seeding that improved `T3` reach.
That means the CI-backed design should not regress to the shallower `T1/T2` route reach profile.

## 5. CI Artifacts and Summary Output

The scan should emit:
- machine-readable report artifact(s)
- short summary output for maintainers
- enough metadata to understand whether the pipeline was healthy even when findings are expected

## 6. Maintainer-Friendly Semantics

The workflow result should mean something clear.

For this benchmark repo, the best semantic is:
- green = the ZeroDAST pipeline executed correctly and produced the expected benchmark signal
- not green = runtime failure, artifact failure, or major benchmark regression

Because Petclinic is a benchmark target, a green run does **not** mean “no findings exist.”

## What T4 Should Not Include Yet

To keep the first external full demonstration disciplined, `T4` should not try to include everything.

Not in scope for first Petclinic `T4` unless clearly needed:
- auth bootstrap flows
- authz/IDOR verification logic
- overlay validation or untrusted SQL seeding machinery
- delta-vs-full scan branching
- issue creation and complex GitHub comment automation
- enterprise-style policy matrices

Those may be valid later.
They are not required for the first external full proof.

## Recommended File/Folder Shape

To preserve the low-noise adaptation goal, the implementation should prefer:
- ZeroDAST-owned logic in [benchmarks/petclinic](C:/Java%20Developer/DAST/benchmarks/petclinic)
- workflow templates or benchmark docs in [docs/benchmarks](C:/Java%20Developer/DAST/docs/benchmarks)
- only the minimum GitHub workflow files needed for the demonstration in `.github/workflows`

The principle is:

> keep the target-specific demonstration understandable and removable without spraying benchmark files across the repo.

## Proposed Workflow Shape

## Workflow 1: Petclinic T4 Trigger / Metadata Lane

Responsibilities:
- detect the benchmark target/ref
- define safe runtime inputs
- package the minimal handoff artifact

Expected outputs:
- ref / SHA metadata
- benchmark mode metadata
- scan configuration inputs needed by the trusted lane

## Workflow 2: Petclinic T4 Trusted Scan Lane

Responsibilities:
- check out the target at the frozen or selected ref
- boot Petclinic in a controlled runtime
- fetch and sanitize the OpenAPI spec if needed
- generate seeded request list
- run the scanner in contained runtime
- upload artifacts
- emit summary

## Success Criteria

T4 is successful when all of the following are true:
- CI-backed scan completes reproducibly on Petclinic
- trust separation is explicit and reviewable
- runtime orchestration is contained and does not depend on ambient host setup
- scan artifacts are uploaded and readable
- request seeding and repo-aware routing are preserved
- the result semantics are understandable for maintainers
- the target repo still feels clean and minimally disturbed by the adaptation

## Failure Criteria

T4 should be considered unsuccessful or incomplete if any of these happen:
- the CI path only works by collapsing the trust boundary into one privileged workflow
- the runtime depends on manual runner state not encoded in the workflow
- the scan regresses to the shallower T1/T2 route reach without explanation
- the workflow becomes permanently red for expected benchmark findings
- the adaptation requires messy, scattered target-repo changes

## Metrics We Should Record

For the first Petclinic `T4` run, record at minimum:
- total workflow duration
- scan runtime duration
- artifact generation success
- whether the spec shim was needed
- request seed count
- API alert URI count
- whether the expected `T3` API-side signal is preserved
- number of workflow files added
- number of target-repo files changed outside the main ZeroDAST-owned area

## Open Design Decisions

These should be decided deliberately before implementation drifts:

1. Should the trusted/untrusted split use `workflow_run`, `workflow_call`, or a minimal artifact handoff pattern?
2. Should the scanner run in Podman/Docker directly in GitHub Actions, or should the app run in one container and the scanner in another through a shared bridge network?
3. Should T4 preserve cached ZAP `2.16.0` for continuity with the benchmark, or should external-repo T4 use `2.17.0` and explicitly record the version change?
4. Should the Petclinic T4 path be benchmark-only in this repo, or should it be written in a way that can later be transplanted more directly into the target repo?

## Recommended Immediate Implementation Plan

1. Define the T4 workflow pair and their responsibilities.
2. Decide the ZAP version for external-repo T4 and write that choice down.
3. Build a CI-safe Petclinic scan runner that preserves the current `T3` lessons.
4. Wire artifacts and summary semantics.
5. Run the first end-to-end T4 proof.
6. Only after the first green run, evaluate whether comments/issues/polish are worth adding.

## Recommendation

Proceed with Petclinic `T4` as a **clean, minimal, full ZeroDAST demonstration**, not as a kitchen-sink benchmark.

The first win we need is credibility, not feature count.
