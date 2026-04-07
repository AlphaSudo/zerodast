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
  - git-ignored `benchmarks/petclinic/out/` artifact folder for runner output
- Files modified: No target-repository files modified; benchmark result sheet updated in ZeroDAST only
- Auth/bootstrap changes: None in T1/T2/T3 because the default path is unauthenticated; basic-auth variant remains a later extension scenario
- Scan policy changes:
  - T1 and T2 used a minimal Automation Framework plan with `/petclinic` base-path scoping, short spider/passive wait, bounded active scan, and a runner-side OpenAPI compatibility shim for cached ZAP `2.16.0`
  - T3 added isolated runtime orchestration, in-network helper fetching, request seeding for concrete API routes, and structured benchmark artifacts
- Any repo-specific compromises: Older cached ZAP `2.16.0` could not cleanly consume Petclinic's generated OpenAPI `3.1.0` document, so all tiers required a runner-side sanitized copy of the spec instead of using the raw `/v3/api-docs` output directly

## Execution Plan

### T1: Basic Scanner Only
- Boot the application in its default local mode using the repository's own documented path.
- Scan the documented OpenAPI JSON at `/petclinic/v3/api-docs`.
- Do not add workflow isolation, artifact handoff, or custom auth adaptation.
- Goal: measure lowest-friction reach, cold-start time, and usefulness of raw scanner output.

Expected T1 constraints:
- likely host-local execution only
- no trusted/untrusted CI separation
- output quality depends heavily on the default ZAP import/spider behavior

### T2: Scanner + Light CI Gating
- Wrap the T1 scan in a lightweight CI path.
- Capture artifacts and summary output.
- Keep setup modest and avoid the full ZeroDAST trusted-lane model.
- Goal: measure what a reasonable low-overhead OSS maintainer setup looks like without the full T3 architecture.

Expected T2 additions:
- simple workflow execution
- report artifact upload
- summary parsing
- minimal target-specific glue

### T3: ZeroDAST
- Adapt the full ZeroDAST pattern to Petclinic.
- Use artifact handoff, isolated scan runtime, and repo-specific path handling for `/petclinic`.
- Keep target-specific files as contained and reversible as possible.
- Goal: measure the actual value of ZeroDAST beyond plain scanner automation.

Expected T3 focus:
- trusted/untrusted workflow separation
- isolated runtime for app plus scanner
- OpenAPI import with correct target/base path handling
- stable report generation and reproducible artifacts

## First Execution Steps
1. Confirm the documented local boot command at the frozen SHA.
2. Confirm the app responds on `http://localhost:9966/petclinic/actuator/health`.
3. Confirm `http://localhost:9966/petclinic/v3/api-docs` is reachable.
4. Execute a T1 baseline scan and record cold-run timing plus route reach.
5. Only after T1 is stable, layer in T2 CI mechanics.
6. Use T1 and T2 observations to scope the least-invasive T3 adaptation.

## Tier Results

| Tier | Setup Time | Cold Run | Warm Run | Auth Coverage | Output Quality | Isolation Posture | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Low | ~4m 07s ZAP run after app was already up | Pending | N/A (unauthenticated baseline) | Low to moderate; report generated but findings stayed on shell/UI paths rather than `/petclinic/api/*` | Low | Partial |
| T2 | Low | ~243s with structured artifacts and summary output | Pending | N/A (unauthenticated baseline) | Moderate operationally, still low semantically; summary/metrics/report were generated cleanly but API alert URI count remained `0` | Low to moderate | Partial |
| T3 | Moderate | ~400s with isolated app + scanner runtime and seeded API requests | Pending | N/A (unauthenticated baseline) | Moderate; API alert URI count improved from `0` to `1`, and API-seeded request coverage produced an additional API-side signal | Moderate to high | Partial but clearly better |
| T4 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

## Findings Summary
- High-level result:
  - T1 and T2 both succeeded operationally.
  - T2 improved repeatability and artifact discipline.
  - T3 is the first tier that improved actual API reach rather than just packaging.
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
- T3-specific reach evidence:
  - seeded request count: `15`
  - API alert URIs observed: `1`
  - API-side alert instance seen on `http://petclinic-t3-app:9966/petclinic/api/owners/1/pets`
- Caveats:
  - The raw Petclinic OpenAPI document exposed a compatibility problem with ZAP `2.16.0` (`info.license.extensions` under OpenAPI `3.1.0`).
  - A runner-side sanitized OpenAPI copy removed the hard importer failure, but the importer still added `0` URLs in T1, T2, and T3.
  - T3 improved API reach, but only modestly; this is evidence of value, not yet evidence of strong comprehensive API coverage.
  - Real-repo findings are candidate findings until independently validated.

## Stability Notes
- Consecutive run behavior: Not yet measured for T3.
- Flaky steps:
  - OpenAPI import with cached ZAP `2.16.0`
  - spider starting from `http://petclinic-t3-app:9966` still produced a `404` warning before discovering child routes
- Workarounds used:
  - fetched the raw OpenAPI JSON into ZeroDAST-owned scratch space
  - removed `info.license.extensions`
  - downgraded the declared `openapi` version string from `3.1.0` to `3.0.3`
  - reran scans using the sanitized local spec copy while leaving the target repository untouched
  - packaged T2 as a single PowerShell harness that emits `zap-report.json`, `summary.md`, `metrics.json`, and `zap-run.log`
  - packaged T3 as an isolated PowerShell harness with a dedicated internal Podman network, in-network helper fetches, and seeded requestor coverage for concrete API routes

## Final Assessment
- Suitable / Suitable with caveats / Not suitable: Suitable with caveats
- Recommendation: Petclinic remains a strong external benchmark target because it is easy to boot and well documented, and it now shows a meaningful T1/T2/T3 gradient. T3 does improve actual reach, but the improvement is modest enough that we should keep our claims disciplined.
- What this repo should teach us about ZeroDAST: ZeroDAST adds real value beyond plain scanner execution on a well-documented target, but older scanner/version coupling can still cap coverage. The benchmark benefit here is visible, but not yet dramatic.
