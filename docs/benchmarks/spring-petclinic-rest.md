# ZeroDAST Benchmark Result: spring-petclinic-rest

## Repository
- Name: spring-petclinic/spring-petclinic-rest
- URL: https://github.com/spring-petclinic/spring-petclinic-rest
- Commit SHA: 155f89a08828386493c27b5584cd2a93d0dcfc39
- Stack summary: Java, Spring Boot, REST-only backend, Maven build
- API surface summary: Documented OpenAPI surface with Swagger UI and `/petclinic/v3/api-docs`
- Auth model: Default mode is unauthenticated; optional basic auth exists but is not required for the first benchmark pass

## Setup Assumptions
- Local runtime assumptions: Java 17+, Maven wrapper, default in-memory H2 database, app expected on port 9966 with `/petclinic` base path
- CI/runtime assumptions: Docker-capable environment or direct JVM run; no paid infrastructure required
- Required secrets: None for default unauthenticated mode
- Mock/seed assumptions: Repository ships with its own sample data via default H2 startup path

## Adaptation Summary
- Files created: Pending benchmark execution
- Files modified: Pending benchmark execution
- Auth/bootstrap changes: Expected to be minimal in the first pass because the default path is unauthenticated
- Scan policy changes: Expected to be modest; likely base-path and OpenAPI import adjustments
- Any repo-specific compromises: None yet

## Tier Results

| Tier | Setup Time | Cold Run | Warm Run | Auth Coverage | Output Quality | Isolation Posture | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T2 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T3 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T4 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

## Findings Summary
- High-level result: Pending benchmark execution
- Candidate findings of note: Pending benchmark execution
- Confirmed findings (if any): None yet
- Caveats: Real-repo findings are candidate findings until independently validated

## Stability Notes
- Consecutive run behavior: Pending benchmark execution
- Flaky steps: Pending benchmark execution
- Workarounds used: Pending benchmark execution

## Final Assessment
- Suitable / Suitable with caveats / Not suitable: Pending benchmark execution
- Recommendation: Execute this repository first because it is the cleaner external adaptation target
- What this repo should teach us about ZeroDAST: How well the T1/T2/T3/T4 model transfers to a documented Spring REST backend with low setup friction
