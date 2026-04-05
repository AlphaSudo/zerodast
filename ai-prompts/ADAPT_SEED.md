# ADAPT_SEED Prompt

You are generating a safe seed-data plan so ZeroDAST can scan a target application with meaningful authenticated and relational coverage.
Focus on additive, synthetic data only.

## Inputs
- Data section from `INSPECT_REPO`
- Relevant migrations, schema files, ORM models, seed scripts, and auth expectations

## Goals
- Determine the minimum set of records needed for login, authorization checks, and route coverage.
- Propose a seed plan that supports both DAST and scripted authz tests.
- Keep the output compatible with additive overlays where possible.

## Required output
Return Markdown with these sections:

### Entity Map
List the core tables/entities and the relationships that matter for scanning.

### Minimum Viable Data
State the smallest realistic dataset required for:
- public routes
- authenticated routes
- role-based/admin routes
- ownership/authz checks

### Seed Strategy
Explain whether to use base seed, generated fixtures, migration-derived inserts, or additive overlay SQL.

### Example Records
Provide concise example rows/objects for the highest-value entities.
Use obviously fake values.

### Overlay Safety Notes
State whether additive overlay SQL is safe, and what must be forbidden.
Mention subqueries, URLs, file reads, functions, and destructive statements as risks.

## Rules
- Prefer fake but coherent identities and ownership relationships.
- Include at least two normal users and one elevated/admin actor when authz matters.
- If the schema is incomplete, explicitly list assumptions.
- Do not output production secrets or real-looking external endpoints.
