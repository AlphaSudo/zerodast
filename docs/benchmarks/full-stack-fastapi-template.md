# ZeroDAST Benchmark Result: full-stack-fastapi-template

## Repository
- Name: fastapi/full-stack-fastapi-template
- URL: https://github.com/fastapi/full-stack-fastapi-template
- Commit SHA: bba8d07c0cb4ac0e38a99d1de38090048fab8dee
- Stack summary: FastAPI backend with SQLModel/PostgreSQL, React frontend, Docker Compose, and JWT-based authentication
- API surface summary: FastAPI backend with OpenAPI/interactive API docs, frontend + backend compose stack, and documented generated API client flow
- Auth model: JWT authentication with password-based login; this repo should become the first authenticated showcase benchmark for ZeroDAST rather than another unauthenticated baseline

## Setup Assumptions
- Local runtime assumptions: Docker Compose-capable environment, backend + database + supporting services started from the template's documented compose flow
- CI/runtime assumptions: target can be built and run from its own compose stack; backend OpenAPI should be reachable from the internal runtime once the stack is up
- Required secrets: none for the first benchmark pass if the template defaults and seeded local bootstrap path are used
- Mock/seed assumptions: the template should provide enough local user/bootstrap state to exercise login and authenticated route access without third-party identity infrastructure

## Adaptation Summary
- Files created: pending
- Files modified: none yet
- Auth/bootstrap changes: pending
- Scan policy changes: pending
- Any repo-specific compromises: pending

## Tier Results

| Tier | Setup Time | Cold Run | Warm Run | Auth Coverage | Output Quality | Isolation Posture | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T2 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T3 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T4 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

## Findings Summary
- High-level result: pending
- Candidate findings of note: pending
- Confirmed findings (if any): pending
- Caveats: pending

## Stability Notes
- Consecutive run behavior: pending
- Flaky steps: pending
- Workarounds used: pending

## Final Assessment
- Suitable / Suitable with caveats / Not suitable: pending
- Recommendation: pending
- What this repo should teach us about ZeroDAST: Whether ZeroDAST can bring together authenticated bootstrap, route exercise, and trusted DAST orchestration on a non-Java public repo without losing the low-noise adaptation story.
