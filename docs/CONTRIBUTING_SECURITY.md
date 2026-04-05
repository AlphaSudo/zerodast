# Contributing Security

## Purpose of overlay.sql
`overlay.sql` is for additive, synthetic test data that helps a feature or route become meaningfully scannable without mutating the trusted base seed set.

## Allowed Patterns
- `INSERT` with explicit literal `VALUES`
- `CREATE TABLE` for isolated throwaway fixtures
- `CREATE INDEX`
- `ALTER TABLE ... ADD COLUMN`

## Forbidden Patterns
- `DROP`, `DELETE`, `UPDATE`, `TRUNCATE`
- `CREATE FUNCTION`, `DO`, unsafe `COPY`
- subqueries inside `INSERT`
- `RETURNING`
- `ON CONFLICT DO UPDATE`
- URLs, IPs, dangerous functions, or obfuscated SQL

## Why `ON CONFLICT DO UPDATE` is forbidden
It turns an additive overlay into a mutation mechanism against trusted seed data, which weakens reviewability and broadens the attack surface for PR-supplied fixtures.

## What happens on validation failure
`db/seed/validate_overlay.py` exits non-zero with a reason. In the trusted DAST workflow, a failing overlay should block that artifact from being used for DB seeding.

## Contribution Notes
- Keep overlay files minimal and obviously fake.
- Prefer supporting auth/bootstrap coverage over bulk data volume.
- The trusted workflow currently consumes overlay through the PR artifact bundle rather than sparse-checkout path surgery.
