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
- Files created: Temporary runner-side scratch files only in the ZeroDAST workspace during T1 (`tmp-petclinic/` raw and sanitized OpenAPI files plus a temporary automation YAML)
- Files modified: Pending benchmark execution
- Auth/bootstrap changes: Expected to be minimal in the first pass because the default path is unauthenticated; basic-auth variant can be benchmarked later as an extension scenario
- Scan policy changes: T1 used a minimal Automation Framework plan with `/petclinic` base-path scoping, short spider/passive wait, and a bounded active scan
- Any repo-specific compromises: Older cached ZAP `2.16.0` could not cleanly consume Petclinic's generated OpenAPI `3.1.0` document, so T1 required a runner-side sanitized copy of the spec instead of using the raw `/v3/api-docs` output directly

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
| T2 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T3 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T4 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

## Findings Summary
- High-level result: T1 is an operational success but a semantic partial. The target booted, docs were reachable, and ZAP generated a report, but the cached older scanner did not achieve useful API-centric coverage from the OpenAPI route.
- Candidate findings of note:
  - `Content Security Policy (CSP) Header Not Set`
  - `Timestamp Disclosure - Unix`
  - `X-Content-Type-Options Header Missing`
  - `Information Disclosure - Suspicious Comments`
  - `User Agent Fuzzer`
- Confirmed findings (if any): None yet
- Caveats:
  - The raw Petclinic OpenAPI document exposed a compatibility problem with ZAP `2.16.0` (`info.license.extensions` under OpenAPI `3.1.0`).
  - A runner-side sanitized OpenAPI copy removed the importer failure, but the importer still added `0` URLs in T1.
  - Alert instances in the generated report did not land on `/petclinic/api/*`, so T1 output should be treated as shallow coverage rather than meaningful REST API assessment.
  - Real-repo findings are candidate findings until independently validated.

## Stability Notes
- Consecutive run behavior: Not yet measured.
- Flaky steps:
  - OpenAPI import with cached ZAP `2.16.0`
  - spider starting from `http://host.containers.internal:9966` produced an expected `404` warning before discovering child routes
- Workarounds used:
  - fetched the raw OpenAPI JSON into ZeroDAST-owned scratch space
  - removed `info.license.extensions`
  - downgraded the declared `openapi` version string from `3.1.0` to `3.0.3`
  - reran the scan using the sanitized local spec copy while leaving the target repository untouched

## Final Assessment
- Suitable / Suitable with caveats / Not suitable: Suitable with caveats
- Recommendation: Execute this repository first because it is the cleaner external adaptation target and gives us a strong Java/Spring data point with low setup friction
- What this repo should teach us about ZeroDAST: How much real value ZeroDAST adds beyond plain scanner execution when the target is well documented but the scanner/version coupling still causes shallow coverage and OpenAPI import friction
