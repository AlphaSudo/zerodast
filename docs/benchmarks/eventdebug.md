# ZeroDAST Benchmark Result: EventDebug

## Repository
- Name: AlphaSudo/EventDebug
- URL: https://github.com/AlphaSudo/EventDebug
- Commit SHA: 090e249dbbb6d63f8a6d28e8c9bfe3e105b7def6
- Stack summary: Java 21 multi-module Gradle application with bundled UI, Javalin REST API, PostgreSQL backend, and optional Kafka integration
- API surface summary: Main app on `http://localhost:9090`, readiness at `/api/v1/health/ready`, legacy health alias at `/api/health`, OpenAPI JSON at `/api/v1/openapi.json`, and primary product routes under `/api/v1/*`
- Auth model: Benchmark first pass should run unauthenticated with `server.auth.enabled: false` and `security.auth.provider: disabled`; auth-capable routes and OIDC/basic flows exist but should be deferred until the baseline is established

## Setup Assumptions
- Local runtime assumptions: Gradle Java 21 build, Docker/Podman-capable environment, Postgres required, Kafka present in default `docker-compose.yml` and likely started for the simplest documented boot path
- CI/runtime assumptions: App can likely be benchmarked either from source via Gradle/JAR or via the root Dockerfile / compose stack; the least-risk first pass is the documented compose path on port `9090`
- Required secrets: None for the first unauthenticated benchmark pass if example/local defaults are used
- Mock/seed assumptions: Root `seed.sql` is mounted into the Postgres container in `docker-compose.yml`, so local benchmark runs should inherit seeded sample data through the standard compose startup path

## Adaptation Summary
- Files created: [run-t1.ps1](C:/Java%20Developer/DAST/benchmarks/eventdebug/run-t1.ps1), [out/.gitignore](C:/Java%20Developer/DAST/benchmarks/eventdebug/out/.gitignore)
- Files modified: none in the target repo; benchmark clone received only a local `eventlens.yaml` for disabled-auth runtime boot
- Auth/bootstrap changes: None for T1 beyond keeping the benchmark clone on `server.auth.enabled: false` and `security.auth.provider: disabled`
- Scan policy changes: Route scoping to `/api/v1/*`, OpenAPI import from `/api/v1/openapi.json`, and scanner targeting shifted to the compose network instead of Windows host `localhost`
- Any repo-specific compromises: Cached ZAP `2.16.0` could not consume the raw EventDebug spec cleanly enough for the benchmark, so T1 fell back to a runner-side sanitized copy with `openapi: 3.0.3` and network-local server metadata

## Tier Results

| Tier | Setup Time | Cold Run | Warm Run | Auth Coverage | Output Quality | Isolation Posture | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Moderate: compose boot plus local config override | 479.7s | Pending | N/A intentionally disabled | Structured summary plus JSON report, but shallow API coverage | Reused target compose network, not a dedicated isolated scan network | Partial success |
| T2 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T3 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T4 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

## Findings Summary
- High-level result: T1 ran successfully against the live compose stack, but coverage remained shallow and did not produce any `/api/v1/*` alert URIs
- Candidate findings of note:
  - `CSP: Failure to Define Directive with No Fallback`
  - `CSP: style-src unsafe-inline`
  - `CSP: Wildcard Directive`
  - `Information Disclosure - Suspicious Comments`
  - `Modern Web Application`
- Confirmed findings (if any): None; these are candidate findings only
- Caveats:
  - Host access from Windows to `localhost:9090` remained unreliable even though the container was healthy and published, so T1 had to measure network-side reachability instead of host reachability.
  - The alerts observed in T1 landed on the app root and frontend asset surface, not on the intended API routes.
  - Real-repo findings are candidate findings until independently validated.

## Stability Notes
- Consecutive run behavior: Not measured yet
- Flaky steps: Windows-host reachability to the published port was flaky; compose-network access was stable
- Workarounds used:
  - fetched health and OpenAPI from inside the compose network using a helper container
  - used a sanitized OpenAPI copy for cached ZAP `2.16.0`

## Final Assessment
- Suitable / Suitable with caveats / Not suitable: Suitable with caveats
- Recommendation: Keep this as the official EventDebug T1 baseline. It proves that the target can be scanned in a live multi-service setup, but it also shows why plain-scanner baselines underperform on richer real repos.
- What this repo should teach us about ZeroDAST: Whether T2 and especially T3 can convert a technically successful but API-shallow baseline into materially better API reach without turning setup into repo mess.
