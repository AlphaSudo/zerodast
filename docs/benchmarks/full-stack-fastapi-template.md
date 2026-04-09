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
- Scan policy changes:
  - T1: minimal authenticated request seeding for `login/test-token`, `users/me`, `items/`, and `users/`
  - T2/T3: corrected `POST /login/test-token`, query-string variants for `users` and `items`, and a docs-targeted spider attempt
- Any repo-specific compromises:
  - local-only creation of `backend/htmlcov/` was required so `compose.override.yml` could start cleanly under Podman
  - cached ZAP `2.16.0` was used to avoid a local image pull, which matters when interpreting OpenAPI importer behavior
  - T3 needed elevated direct Podman execution in this desktop environment so the network-side helper path could run cleanly
  - T4 moved to CI-backed `zaproxy/zap-stable:2.17.0`, which improved signal without fixing the underlying `0`-URL OpenAPI importer issue

## Tier Results

| Tier | Setup Time | Cold Run | Warm Run | Auth Coverage | Output Quality | Isolation Posture | Result |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | Moderate | 270.8s | Pending | Login bootstrap succeeded; protected route validation and authenticated request seeding succeeded | Meaningful but limited: API-side findings landed, but OpenAPI import added `0` URLs and findings stayed low/informational | Compose-network local scan, no trusted split yet | Partial success |
| T2 | Moderate | 307.6s | Pending | Login bootstrap succeeded; protected-route validation and authenticated seeding still succeeded | Better than T1: API alert URI count rose from `5` to `7`, mainly by exercising authenticated query-string variants | Compose-network local scan, still no trusted split | Partial success |
| T3 | High | 630.1s | Pending | Login bootstrap, protected-route validation, and request seeding all succeeded from inside the target network | No lift over T2: API alert URI count stayed at `7`, OpenAPI import still added `0` URLs, and the same low/informational finding set remained | Network-side auth/bootstrap and scan orchestration; closer to ZeroDAST's real model | Partial success |
| T4 | High | 127s | Pending | CI bootstrap/login/protected-route validation all succeeded in the trusted scan lane, and the superuser-only `users/` route validated with HTTP `200` | Strongest result so far: API alert URI count reached `10`, reflected JSON XSS signal appeared on authenticated API routes, and the privileged `users/` route was explicitly exercised | Full CI-backed trusted split with isolated runtime and target-aware auth orchestration | Success |

## Findings Summary
- High-level result: the first authenticated T1 baseline worked operationally and produced authenticated API-side signal
- Follow-up T2 result: still partial, but better than T1. The improved seed set raised API-side alert coverage from `5` URIs to `7`, even though the importer still added `0` URLs and the active findings stayed low/informational.
- T3 result: auth/bootstrap moved fully into the target network and still succeeded, which is an important ZeroDAST proof, but the scanner output did not improve beyond T2.
- T4 result: the CI-backed trusted ZeroDAST path improved signal materially. Using ZAP `2.17.0`, the external FastAPI target proved authenticated and privileged-route coverage together: admin route validation returned `200`, admin route exercise was recorded, API alert URI count reached `10`, and `Cross Site Scripting Weakness (Reflected in JSON Response)` surfaced on authenticated API routes.
- Candidate findings of note:
  - `Cross Site Scripting Weakness (Reflected in JSON Response)`
  - `X-Content-Type-Options Header Missing`
  - `User Agent Fuzzer`
- Confirmed findings (if any):
  - API-side low-severity header issue on authenticated endpoints such as `/api/v1/users/me`, `/api/v1/items/`, `/api/v1/users/`, and their query-string variants
  - reflected JSON XSS-style weakness on authenticated query-string variants for `/api/v1/items` and `/api/v1/users`
  - privileged-route exercise proof on the superuser-only `GET /api/v1/users/?skip=0&limit=10` path
- Caveats:
  - this repo is the first authenticated showcase candidate, so auth bootstrap remains part of the benchmark difficulty, not just setup noise
  - cached ZAP `2.16.0` imported `0` URLs from the OpenAPI document even though the raw spec was reachable and request seeding worked
  - the spider still normalized back to `/api/v1` and logged a `404` warning even after moving the configured seed page to `/docs`
  - T1 was completed locally with an elevated direct Podman run because the current Windows PowerShell harness still needs a cleaner Podman execution wrapper
  - T2 showed the same local Podman constraint; the scan result is real, but the final ZAP invocation still needed the elevated direct Podman path in this desktop environment
  - T3 confirmed that network-side auth/bootstrap is not the limiting factor on this target; the limiting factor is still scanner/importer depth on cached ZAP `2.16.0`
  - T4 still showed `openapi added 0 URLs` and the familiar spider-root `404` warning, so the improved signal came from the stronger CI/runtime/scanner path rather than a fixed importer
  - the stronger Phase 1 close-out signal came from `Admin route validation status: 200`, `Admin route exercised: yes`, and the explicit `Admin Route Evidence` block in the verification artifact, not from a new OpenAPI importer capability

## Stability Notes
- Consecutive run behavior: not measured yet
- Flaky steps:
  - local Podman execution from inside the PowerShell harness hit Windows `podman.exe` invocation issues
  - OpenAPI importer behavior on ZAP `2.16.0` remains weak even when auth/bootstrap is healthy
  - cached `2.16.0` does not recognize the extra `activeScan` tuning knobs we initially tried for T2, so this target needs version-aware config
  - T3 is currently much slower than T2 without improving signal, so network-side orchestration alone is not yet a runtime or output win on this target
  - T4 improved both runtime and signal, which suggests the bigger gain on this repo came from the CI path and newer ZAP rather than from additional local orchestration complexity
- Workarounds used:
  - created `backend/htmlcov/` locally before startup
  - ran the final ZAP container invocation directly with Podman outside the script after the harness had already generated config/spec/token artifacts
  - used elevated local execution for T3 so the network-side helper path could call Podman reliably from this desktop environment
  - T4 avoided the local Windows Podman friction entirely by running in GitHub Actions

## Final Assessment
- Suitable / Suitable with caveats / Not suitable: Suitable
- Recommendation: treat this repo as the first authenticated non-Java T4 showcase and the first external privileged/admin-route proof target. The current evidence says ZeroDAST can handle auth bootstrap, privileged-route validation, route exercise, and trusted orchestration here in a way that produces meaningfully better CI signal than the local baselines.
- What this repo should teach us about ZeroDAST: Whether ZeroDAST can bring together authenticated bootstrap, privileged-route exercise, and trusted DAST orchestration on a non-Java public repo without losing the low-noise adaptation story. T1-T4 now suggest the answer is "yes", with the strongest proof coming from the CI-backed T4 path and its explicit admin-route evidence.
