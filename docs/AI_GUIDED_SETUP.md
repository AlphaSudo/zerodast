# AI Guided Setup

## Goal
Use the prompt files under `ai-prompts/` to adapt ZeroDAST to another repository with bounded, reviewable outputs.

## Workflow
1. Inspect
- Run `ai-prompts/INSPECT_REPO.md` against the target repo.
- Capture working directory, runtime, auth mode, route layout, schema sources, and DAST blockers.

2. Generate Model 1 Config
- Feed the inspection YAML into `ai-prompts/GENERATE_MODEL1_CONFIG.md`.
- This produces a valid `zerodast/config.json` for the Model 1 in-repo prototype.
- For general ZAP config and strategy, use `ai-prompts/GENERATE_CONFIG.md`.

3. Adapt Auth
- Use `ai-prompts/ADAPT_AUTH.md` with real login code and auth routes.
- The output now includes a Model 1 adapter selection and a `config.json` auth block.
- Dry-run auth bootstrap before attempting full scans.

4. Adapt Seed
- Use `ai-prompts/ADAPT_SEED.md` with migrations/models/fixtures.
- Prefer additive synthetic data and explicit ownership relationships.

5. Validate and Triage
- Run scans.
- Use `ai-prompts/AI_TRIAGE.md` on high-signal findings for remediation guidance.

## Dry-Run Mode
Before full DAST, validate these in order:
- app starts locally or in Docker
- health endpoint responds
- auth bootstrap returns usable token/session material
- OpenAPI path exists if expected
- seed data covers public, authenticated, and ownership-sensitive paths

## Examples
- Node.js / Express: login endpoint + bearer token + OpenAPI JSON route
- Python / FastAPI: `/token` flow + OpenAPI docs + seeded relational fixtures
- Java / Spring: session/cookie bootstrap + CSRF handling + migration-derived test data
- Go: API key or JWT bootstrap + route extraction from handlers/router setup
