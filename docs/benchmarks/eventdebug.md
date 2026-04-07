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
- Files created: [run-t1.ps1](C:/Java%20Developer/DAST/benchmarks/eventdebug/run-t1.ps1), [run-t2.ps1](C:/Java%20Developer/DAST/benchmarks/eventdebug/run-t2.ps1), [run-t3.ps1](C:/Java%20Developer/DAST/benchmarks/eventdebug/run-t3.ps1), [out/.gitignore](C:/Java%20Developer/DAST/benchmarks/eventdebug/out/.gitignore)
- Files modified: none in the target repo; benchmark clone received only a local `eventlens.yaml` for disabled-auth runtime boot
- Auth/bootstrap changes: None across T1-T3 beyond keeping the benchmark clone on `server.auth.enabled: false` and `security.auth.provider: disabled`
- Scan policy changes:
  - T1: route scoping to `/api/v1/*`, OpenAPI import from `/api/v1/openapi.json`, network-side scanning against the compose project
  - T2: added requestor seeding for the three documented API routes using real sample IDs from seeded data
  - T3: moved the target into a disposable internal-only Postgres/Kafka/app network with the same seeded requestor flow
- Any repo-specific compromises: Cached ZAP `2.16.0` could not consume the raw EventDebug spec cleanly enough for the benchmark, so all tiers fell back to a runner-side sanitized copy with `openapi: 3.0.3` and network-local server metadata

## Tier Results

| Tier | Setup Time | Cold Run | Warm Run | Auth Coverage | Output Quality | Isolation Posture | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Moderate: compose boot plus local config override | 479.7s | Pending | N/A intentionally disabled | Structured summary plus JSON report, but shallow API coverage | Reused target compose network, not a dedicated isolated scan network | Partial success |
| T2 | Moderate: same compose stack, plus request seeding | 526.6s | Pending | N/A intentionally disabled | Better benchmark packaging, but no additional API-side findings | Reused target compose network, not a dedicated isolated scan network | Partial success |
| T3 | Higher: disposable Postgres, Kafka, and app stack inside a fresh internal network | 197.6s | Pending | N/A intentionally disabled | Best packaging and cleanest runtime story, but still no API-side findings | Strongest so far: fully internal target and scanner runtime | Partial success |
| T4 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

## Findings Summary
- High-level result: All three tiers ran successfully, but none produced any `/api/v1/*` alert URIs. EventDebug is therefore a strong operational benchmark target but currently a weak finding-lift target for ZeroDAST.
- Candidate findings of note:
  - `CSP: Failure to Define Directive with No Fallback`
  - `CSP: style-src unsafe-inline`
  - `CSP: Wildcard Directive`
  - `Information Disclosure - Suspicious Comments`
  - `Modern Web Application`
- Confirmed findings (if any): None; these are candidate findings only
- Caveats:
  - Host access from Windows to `localhost:9090` remained unreliable even though the container was healthy and published, so the benchmark had to measure network-side reachability instead of host reachability.
  - The alerts observed in T1-T3 landed on the app root and frontend asset surface, not on the intended API routes.
  - Real-repo findings are candidate findings until independently validated.

## Stability Notes
- Consecutive run behavior: Not measured yet
- Flaky steps: Windows-host reachability to the published port was flaky; compose-network and isolated-network access were stable
- Workarounds used:
  - fetched health and OpenAPI from inside the compose or isolated network using a helper container
  - used a sanitized OpenAPI copy for cached ZAP `2.16.0`
  - used seeded aggregate IDs (`ORD-001`, `ACC-002`) for requestor URLs in T2/T3

## Final Assessment
- Suitable / Suitable with caveats / Not suitable: Suitable with caveats
- Recommendation: Keep EventDebug as the more demanding real-repo benchmark target. It demonstrates that ZeroDAST can make execution cleaner and faster on a multi-service app, but it does not yet demonstrate a finding lift on this target.
- What this repo should teach us about ZeroDAST: Whether we need a better real-repo success metric than alert-bearing API URIs alone, because execution quality improved materially while detection output stayed flat.
