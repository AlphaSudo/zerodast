# ZeroDAST Benchmark Result: spring-petclinic-rest

## Repository
- Name: spring-petclinic/spring-petclinic-rest
- URL: https://github.com/spring-petclinic/spring-petclinic-rest
- Commit SHA: 155f89a08828386493c27b5584cd2a93d0dcfc39
- Stack summary: Java 17+, Spring Boot, Maven build, REST-only backend
- API surface summary: Swagger UI at `/petclinic/swagger-ui.html`, OpenAPI JSON at `/petclinic/v3/api-docs`, broad CRUD API surface under `/petclinic/api/*`
- Auth model: Default mode is unauthenticated; optional basic auth can be enabled with `petclinic.security.enable=true`

## Setup Assumptions
- Local runtime assumptions: Java 17+, Maven wrapper, default in-memory H2 database, app expected on port 9966 with `/petclinic` base path
- CI/runtime assumptions: Docker-capable environment or direct JVM run; no paid infrastructure required; default mode should boot without external DB services
- Required secrets: None for the first unauthenticated benchmark pass
- Mock/seed assumptions: Repository ships with built-in sample data through its default H2 startup path

## Adaptation Summary
- Files created:
  - `benchmarks/petclinic/run-t2.ps1`
  - `benchmarks/petclinic/run-t3.ps1`
  - `benchmarks/petclinic/run-t4.sh`
  - `benchmarks/petclinic/prepare-openapi.js`
  - `benchmarks/petclinic/verify-t4.js`
  - git-ignored `benchmarks/petclinic/out/` artifact folder for runner output
- Files modified: No target-repository files modified; benchmark result sheet updated in ZeroDAST only
- Auth/bootstrap changes: None in T1/T2/T3/T4 because the default path is unauthenticated; basic-auth variant remains a later extension scenario
- Scan policy changes:
  - T1 and T2 used a minimal Automation Framework plan with `/petclinic` base-path scoping, short spider/passive wait, bounded active scan, and a runner-side OpenAPI compatibility shim for cached ZAP `2.16.0`
  - T3 added isolated runtime orchestration, in-network helper fetching, request seeding for concrete API routes, and structured benchmark artifacts
  - T4 preserved the T3 route/request strategy and moved it into a CI-backed trusted workflow pair with source-based build, isolated runtime orchestration, artifact upload, and maintainer-readable verification output
- Any repo-specific compromises:
  - Older cached ZAP `2.16.0` could not cleanly consume Petclinic's generated OpenAPI `3.1.0` document, so T1-T3 required a runner-side sanitized copy of the spec
  - T4 on ZAP `2.17.0` accepted the raw spec directly in CI, which is a meaningful improvement over the local older-version baseline

## Tier Results

| Tier | Setup Time | Cold Run | Warm Run | Auth Coverage | Output Quality | Isolation Posture | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Low | ~4m 07s ZAP run after app was already up | Pending | N/A (unauthenticated baseline) | Low to moderate; report generated but findings stayed on shell/UI paths rather than `/petclinic/api/*` | Low | Partial |
| T2 | Low | ~243s with structured artifacts and summary output | Pending | N/A (unauthenticated baseline) | Moderate operationally, still low semantically; summary/metrics/report were generated cleanly but API alert URI count remained `0` | Low to moderate | Partial |
| T3 | Moderate | ~400s with isolated app + scanner runtime and seeded API requests | Pending | N/A (unauthenticated baseline) | Moderate; API alert URI count improved from `0` to `1`, and API-seeded request coverage produced an additional API-side signal | Moderate to high | Partial but clearly better |
| T4 | Moderate in CI | 145s initial run, 209s clean rerun | Pending | N/A (unauthenticated baseline) | Strongest so far; CI artifact package included raw/sanitized spec copies, generated request list, automation plan, report, metrics, and verification summary | High | Successful full CI-backed demonstration |
| T5 | Low to moderate | Pending | Pending | N/A (unauthenticated baseline) | Pending; benchmark-only conventional baseline implemented as a target-repo-local GitHub Actions ZAP API scan workflow | Moderate | Implemented, run pending |

## Findings Summary
- High-level result:
  - T1 and T2 both succeeded operationally.
  - T2 improved repeatability and artifact discipline.
  - T3 is the first local tier that improved actual API reach rather than just packaging.
  - T4 preserved that API-side signal inside a real CI-backed ZeroDAST workflow.
  - A second T4 rerun completed cleanly with `zapExitCode: 0` and no spider-root warning.
- Candidate findings of note across the tiers:
  - `Content Security Policy (CSP) Header Not Set`
  - `Missing Anti-clickjacking Header`
  - `Application Error Disclosure`
  - `Timestamp Disclosure - Unix`
  - `X-Content-Type-Options Header Missing`
  - `Information Disclosure - Suspicious Comments`
  - `Modern Web Application`
  - `User Agent Fuzzer`
- Confirmed findings (if any): None yet
- T3/T4 reach evidence:
  - seeded request count: `15`
  - API alert URIs observed: `1`
  - API-side alert instance seen on `http://petclinic-t3-app:9966/petclinic/api/owners/1/pets` locally and `http://petclinic-t4-app:9966/petclinic/api/owners/1/pets` in CI
- T5 implementation evidence:
  - benchmark-only conventional baseline is implemented in a fresh Petclinic clone
  - baseline shape is a single in-repo workflow using the official ZAP API Scan action
  - local sanity validation passed for the repo's normal `./mvnw ... package -> java -jar target/*.jar` startup path and OpenAPI endpoint
- T4 artifact evidence:
  - raw spec mode on ZAP `2.17.0`
  - initial cold run duration: `145s`
  - clean rerun duration: `209s`
  - clean rerun metrics recorded `zapExitCode: 0`
  - artifact package included `zap-report.json`, `verification.md`, `metrics.json`, generated request URLs, and the resolved automation plan
- Caveats:
  - T3 improved API reach, but only modestly; this is evidence of value, not yet evidence of strong comprehensive API coverage.
  - Real-repo findings are candidate findings until independently validated.

## Stability Notes
- Consecutive run behavior: One clean T4 rerun now exists in CI.
- Flaky steps:
  - T1-T3 on ZAP `2.16.0` had OpenAPI import fragility.
  - The first T4 CI run showed a non-fatal spider-root warning; the second run removed it after tightening the scan base path.
- Workarounds used:
  - fetched the raw OpenAPI JSON into ZeroDAST-owned scratch space
  - removed `info.license.extensions` and downgraded the declared `openapi` version string from `3.1.0` to `3.0.3` for T1-T3
  - reran scans using the sanitized local spec copy while leaving the target repository untouched
  - packaged T2 as a single PowerShell harness that emits `zap-report.json`, `summary.md`, `metrics.json`, and `zap-run.log`
  - packaged T3 as an isolated PowerShell harness with a dedicated internal Podman network, in-network helper fetches, and seeded requestor coverage for concrete API routes
  - packaged T4 as a two-workflow CI-backed ZeroDAST demonstration that clones the frozen target SHA, builds it from source, runs the scan in an isolated runtime, and uploads a verification-friendly artifact bundle

## Final Assessment
- Suitable / Suitable with caveats / Not suitable: Suitable with caveats
- Recommendation: Petclinic is now the strongest external benchmark target and the first successful full CI-backed ZeroDAST demonstration. It is the right repo to use when explaining the practical value of ZeroDAST beyond the self-validating demo.
- What this repo should teach us about ZeroDAST: ZeroDAST can move from local benchmark harnesses into a real CI-backed external-repo demonstration while keeping target-repo noise low and preserving meaningful API-side signal.
