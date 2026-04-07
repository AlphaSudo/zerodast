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
- Files created: Pending benchmark execution
- Files modified: Pending benchmark execution
- Auth/bootstrap changes: Expected to be unnecessary for T1/T2/T3 baseline if the benchmark stays on the default disabled-auth path
- Scan policy changes: Expected to include route scoping to `/api/v1/*`, OpenAPI import from `/api/v1/openapi.json`, and likely target-specific request seeding for timeline/search/export endpoints
- Any repo-specific compromises: OpenAPI exists as a bundled static `openapi.json` and is served through a route authorizer; benchmark assumptions should explicitly keep auth disabled for the first pass so the spec remains practically reachable

## Tier Results

| Tier | Setup Time | Cold Run | Warm Run | Auth Coverage | Output Quality | Isolation Posture | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T2 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T3 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T4 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

## Findings Summary
- High-level result: Profiling complete; execution not started yet
- Candidate findings of note: None yet
- Confirmed findings (if any): None yet
- Caveats:
  - This target is operationally heavier than Petclinic because the default path includes both Postgres and Kafka.
  - The benchmark should avoid touching the user's existing local EventDebug checkout and should operate only from the isolated benchmark clone.
  - Real-repo findings are candidate findings until independently validated.

## Stability Notes
- Consecutive run behavior: Pending benchmark execution
- Flaky steps: Pending benchmark execution
- Workarounds used: None yet

## Final Assessment
- Suitable / Suitable with caveats / Not suitable: Suitable with caveats
- Recommendation: Execute this repository second after Petclinic. It should be the stronger test of ZeroDAST's real-world value because it is a richer, auth-capable, multi-service application rather than a relatively clean Spring REST sample.
- What this repo should teach us about ZeroDAST: Whether ZeroDAST's T1/T2/T3 gradient still holds on a more complex, multi-module application with a real API surface, richer security model, and heavier local runtime footprint
