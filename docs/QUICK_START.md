# Quick Start

## Prerequisites
- Docker
- Node.js 22+ for local demo-app lint/test and lockfile management
- Python 3.11+ for `validate_overlay.py`
- Git Bash on Windows for `.sh` validation and local shell execution

## Local Setup
1. Install demo app dependencies:
   - `cd demo-app`
   - `npm install`
2. Validate overlay tooling:
   - `python db/seed/validate_overlay.py db/seed/overlay.sql.example`
3. Review the trusted/untrusted workflow split under `.github/workflows/`.
4. Review the seed files under `db/seed/`.
5. Review the ZAP config under `security/zap/`.

## Adaptation Workflow
1. Run `ai-prompts/INSPECT_REPO.md` against the target repo.
2. Feed that output into `ai-prompts/GENERATE_CONFIG.md`.
3. Refine auth handling with `ai-prompts/ADAPT_AUTH.md`.
4. Refine data handling with `ai-prompts/ADAPT_SEED.md`.
5. Use `ai-prompts/AI_TRIAGE.md` after scans for fix guidance.

## Common Pitfalls
- Windows line endings can affect shell scripts; keep `.sh` files LF-normalized when possible.
- `CI Tests` must match the exact `workflow_run` dependency name in `dast-pr.yml`.
- In this repo, local runtimes may exist on the PC but not appear on sandbox PATH automatically.
- Delta detection is intentionally fail-safe: ambiguous cases escalate to `FULL`.
