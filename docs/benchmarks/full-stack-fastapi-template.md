# ZeroDAST Benchmark Result: full-stack-fastapi-template

## Repository
- Name: fastapi/full-stack-fastapi-template
- URL: https://github.com/fastapi/full-stack-fastapi-template
- Commit SHA: bba8d07c0cb4ac0e38a99d1de38090048fab8dee
- Stack summary: FastAPI backend with SQLModel/PostgreSQL, React frontend, Docker Compose, and JWT-based authentication
- API surface summary: backend API at `http://localhost:8000`, interactive docs at `/docs`, alternative docs at `/redoc`, and versioned API routes under `/api/v1/*`
- Auth model: JWT authentication with password-based login via `POST /api/v1/login/access-token`; protected routes include `users/me`, item CRUD, and superuser-only user-management routes

## Setup Assumptions
- Local runtime assumptions: Docker Compose-capable environment, stack started through the documented compose path in [development.md](C:/Java%20Developer/fullstack-fastapi-benchmark/development.md)
- CI/runtime assumptions: target can be built and run from its own compose stack; backend OpenAPI should be reachable from the internal runtime at `/openapi.json` or via FastAPI docs paths once the stack is up
- Required secrets: no external identity-provider secrets for the first benchmark pass; local defaults exist in `.env`
- Mock/seed assumptions: `.env` provides `FIRST_SUPERUSER=admin@example.com` and `FIRST_SUPERUSER_PASSWORD=changethis`, and [initial_data.py](C:/Java%20Developer/fullstack-fastapi-benchmark/backend/app/initial_data.py) indicates local bootstrap goes through the normal DB initialization path

## Auth Success Criteria
- login bootstrap succeeds against `POST /api/v1/login/access-token`
- obtained token is accepted by `POST /api/v1/login/test-token` or an equivalent protected route
- authenticated route exercise is measured separately from alert-bearing API findings
- benchmark notes distinguish:
  - auth bootstrap success
  - protected-route exercise success
  - alert-bearing API signal success

## Adaptation Summary
- Files created: benchmark-local harness only, in [run-t1.ps1](C:/Java%20Developer/DAST/benchmarks/fullstack-fastapi-template/run-t1.ps1) and [out/.gitignore](C:/Java%20Developer/DAST/benchmarks/fullstack-fastapi-template/out/.gitignore)
- Files modified: none yet
- Auth/bootstrap changes: local-only token bootstrap using the seeded superuser from `.env`, with bearer-token injection baked into the ZAP automation config
- Scan policy changes: minimal T1 authenticated request seeding for `login/test-token`, `users/me`, `items/`, and `users/`
- Any repo-specific compromises:
  - local-only creation of `backend/htmlcov/` was required so `compose.override.yml` could start cleanly under Podman
  - cached ZAP `2.16.0` was used to avoid a local image pull, which matters when interpreting OpenAPI importer behavior

## Tier Results

| Tier | Setup Time | Cold Run | Warm Run | Auth Coverage | Output Quality | Isolation Posture | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Moderate | 270.8s | Pending | Login bootstrap succeeded; protected route validation and authenticated request seeding succeeded | Meaningful but limited: API-side findings landed, but OpenAPI import added `0` URLs and findings stayed low/informational | Compose-network local scan, no trusted split yet | Partial success |
| T2 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T3 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T4 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

## Findings Summary
- High-level result: the first authenticated T1 baseline worked operationally and produced authenticated API-side signal
- Candidate findings of note:
  - `X-Content-Type-Options Header Missing`
  - `User Agent Fuzzer`
- Confirmed findings (if any):
  - API-side low-severity header issue on authenticated endpoints such as `/api/v1/users/me`, `/api/v1/items/`, and `/api/v1/users/`
- Caveats:
  - this repo is the first authenticated showcase candidate, so auth bootstrap remains part of the benchmark difficulty, not just setup noise
  - cached ZAP `2.16.0` imported `0` URLs from the OpenAPI document even though the raw spec was reachable and request seeding worked
  - the spider still started from the backend root and logged the familiar root-path `404` warning
  - T1 was completed locally with an elevated direct Podman run because the current Windows PowerShell harness still needs a cleaner Podman execution wrapper

## Stability Notes
- Consecutive run behavior: not measured yet
- Flaky steps:
  - local Podman execution from inside the PowerShell harness hit Windows `podman.exe` invocation issues
  - OpenAPI importer behavior on ZAP `2.16.0` remains weak even when auth/bootstrap is healthy
- Workarounds used:
  - created `backend/htmlcov/` locally before startup
  - ran the final ZAP container invocation directly with Podman outside the script after the harness had already generated config/spec/token artifacts

## Final Assessment
- Suitable / Suitable with caveats / Not suitable: Suitable with caveats
- Recommendation: proceed to T2, but keep auth-bootstrap instrumentation as a first-class success signal and do not overread the current low/informational finding set as “auth problem solved”
- What this repo should teach us about ZeroDAST: Whether ZeroDAST can bring together authenticated bootstrap, protected-route exercise, and trusted DAST orchestration on a non-Java public repo without losing the low-noise adaptation story. T1 already suggests the answer is “yes operationally, but scanner-depth still needs help.”
