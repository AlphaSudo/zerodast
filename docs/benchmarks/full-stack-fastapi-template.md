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
- High-level result: profiling complete, execution pending
- Candidate findings of note: pending
- Confirmed findings (if any): pending
- Caveats:
  - this repo is the first authenticated showcase candidate, so auth bootstrap itself is part of the benchmark difficulty
  - default credentials exist, but we still need to verify how reliably they appear in the running stack and whether compose networking changes the effective base URL shape

## Stability Notes
- Consecutive run behavior: pending
- Flaky steps: pending
- Workarounds used: pending

## Final Assessment
- Suitable / Suitable with caveats / Not suitable: Suitable with caveats
- Recommendation: proceed to T1 with explicit auth-bootstrap instrumentation rather than pretending this is another unauthenticated target
- What this repo should teach us about ZeroDAST: Whether ZeroDAST can bring together authenticated bootstrap, protected-route exercise, and trusted DAST orchestration on a non-Java public repo without losing the low-noise adaptation story.
