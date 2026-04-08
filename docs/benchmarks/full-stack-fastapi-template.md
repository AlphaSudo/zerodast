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
| T2 | Moderate | 307.6s | Pending | Login bootstrap succeeded; protected-route validation and authenticated seeding still succeeded | Better than T1: API alert URI count rose from `5` to `7`, mainly by exercising authenticated query-string variants | Compose-network local scan, still no trusted split | Partial success |
| T3 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| T4 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

## Findings Summary
- High-level result: the first authenticated T1 baseline worked operationally and produced authenticated API-side signal
- Follow-up T2 result: still partial, but better than T1. The improved seed set raised API-side alert coverage from `5` URIs to `7`, even though the importer still added `0` URLs and the active findings stayed low/informational.
- Candidate findings of note:
  - `X-Content-Type-Options Header Missing`
  - `User Agent Fuzzer`
- Confirmed findings (if any):
  - API-side low-severity header issue on authenticated endpoints such as `/api/v1/users/me`, `/api/v1/items/`, `/api/v1/users/`, and their query-string variants
- Caveats:
  - this repo is the first authenticated showcase candidate, so auth bootstrap remains part of the benchmark difficulty, not just setup noise
  - cached ZAP `2.16.0` imported `0` URLs from the OpenAPI document even though the raw spec was reachable and request seeding worked
  - the spider still normalized back to `/api/v1` and logged a `404` warning even after moving the configured seed page to `/docs`
  - T1 was completed locally with an elevated direct Podman run because the current Windows PowerShell harness still needs a cleaner Podman execution wrapper
  - T2 showed the same local Podman constraint; the scan result is real, but the final ZAP invocation still needed the elevated direct Podman path in this desktop environment

## Stability Notes
- Consecutive run behavior: not measured yet
- Flaky steps:
  - local Podman execution from inside the PowerShell harness hit Windows `podman.exe` invocation issues
  - OpenAPI importer behavior on ZAP `2.16.0` remains weak even when auth/bootstrap is healthy
  - cached `2.16.0` does not recognize the extra `activeScan` tuning knobs we initially tried for T2, so this target needs version-aware config
- Workarounds used:
  - created `backend/htmlcov/` locally before startup
  - ran the final ZAP container invocation directly with Podman outside the script after the harness had already generated config/spec/token artifacts

## Final Assessment
- Suitable / Suitable with caveats / Not suitable: Suitable with caveats
- Recommendation: proceed to T3, but keep auth-bootstrap instrumentation as a first-class success signal and treat importer weakness and Windows Podman ergonomics as separate problems from auth coverage
- What this repo should teach us about ZeroDAST: Whether ZeroDAST can bring together authenticated bootstrap, protected-route exercise, and trusted DAST orchestration on a non-Java public repo without losing the low-noise adaptation story. T1/T2 suggest the answer is “yes operationally, with modest but real finding lift from better authenticated seeding, while scanner-depth still needs help.”
