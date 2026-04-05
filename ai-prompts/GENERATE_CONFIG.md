# GENERATE_CONFIG Prompt

You are given an `INSPECT_REPO` YAML profile.
Generate ZeroDAST adaptation artifacts for the detected application.
Prioritize minimal, safe, reviewable output over cleverness.

## Inputs
- The repository inspection YAML
- Optional user constraints such as scan speed, local-only mode, or auth limitations

## Outputs to generate
1. ZAP automation config
- Context URL
- OpenAPI import when available
- Header injection with `REQ_HEADER_ADD`
- Passive scan before active scan
- Report output to `/zap/wrk/zap-report.json`

2. Auth bootstrap strategy
- Machine-usable login flow
- Required headers/cookies/body shape
- Failure handling for missing token/session material

3. Seed/overlay plan
- Minimum viable data required for authenticated coverage
- Which entities must exist before auth bootstrap and before active scan
- Whether additive overlay SQL is appropriate

4. Local orchestration notes
- How to start app + DB in isolation
- Which env vars are mandatory
- Which readiness checks are required

5. Scan scope notes
- Whether delta scanning is appropriate
- Which changes should force a full scan

## Output format
Return Markdown with exactly these sections:

### ZAP Automation
Provide a YAML snippet or a precise outline.

### Auth Bootstrap
Provide a shell-oriented flow, not prose only.

### Seed Strategy
List required entities and constraints.

### Runtime Notes
List startup/readiness requirements.

### Scope Guidance
State when to use delta vs full.

## Rules
- Reuse ZeroDAST patterns when they fit: isolated Docker network, pinned ZAP version, auth bootstrap before scan, post-scan canary checks.
- If auth is not automatable, say so explicitly and propose the safest fallback.
- If OpenAPI is missing, recommend discovery fallback paths without pretending docs exist.
- Avoid claiming universal coverage; prefer bounded language.
