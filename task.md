# ZeroDAST v2 — Full Implementation Checklist

---

## Phase 0: Project Scaffolding
- [x] Create root directory structure under `c:\Java Developer\DAST\`
- [x] Create `.gitignore` (node_modules, reports/, *.tar, .env, /tmp/)
- [x] Create `LICENSE` (Apache-2.0)
- [x] Initialize git repo (`git init`)
- [ ] Initial commit: "chore: initialize ZeroDAST project scaffold"

---

## Phase 1: Demo App (Self-Validating DAST Target)

### 1.1 Package Setup
- [x] Create `demo-app/package.json`
  - [x] Dependencies: express, pg, jsonwebtoken, bcryptjs, swagger-jsdoc, swagger-ui-express, helmet, cors
  - [x] Dev dependencies: eslint, jest (for CI lint/test steps)
  - [x] Scripts: start, lint, test
- [x] Create `demo-app/.dockerignore` (node_modules, npm-debug.log, .git)

### 1.2 Core Application
- [x] Create `demo-app/src/index.js`
  - [x] Express app setup with JSON body parsing
  - [x] Mount all route files
  - [x] Swagger UI at `/api-docs`
  - [x] OpenAPI JSON spec at `/v3/api-docs`
  - [x] Port from `PORT` env var (default 8080)
  - [x] Global error handler middleware
- [x] Create `demo-app/src/db.js`
  - [x] PostgreSQL Pool from `DATABASE_URL`
  - [x] Connection retry logic (up to 10 retries, 2s interval)
- [x] Create `demo-app/src/swagger.js`
  - [x] swagger-jsdoc config with OpenAPI 3.0
  - [x] Security scheme: Bearer JWT
  - [x] Server URL: `http://localhost:8080`

### 1.3 Middleware
- [x] Create `demo-app/src/middleware/auth.js`
  - [x] JWT verification from Authorization header
  - [x] Extract userId and role to `req.user`
  - [x] Return 401 on missing/invalid token
- [x] Create `demo-app/src/middleware/errorHandler.js`
  - [x] **INTENTIONAL VULN:** Returns stack trace in error responses (info disclosure)
  - [x] Add `// codeql[js/stack-trace-exposure]` suppression comment

### 1.4 Route Files
- [x] Create `demo-app/src/routes/health.js`
  - [x] `GET /health`  `{ status: "ok", timestamp: ... }`
- [x] Create `demo-app/src/routes/auth.js`
  - [x] `POST /api/auth/register` - bcrypt hash, insert user, return JWT
  - [x] `POST /api/auth/login` - verify credentials, return JWT
  - [x] **INTENTIONAL VULN:** Verbose error on login failure (user enumeration)
  - [x] JSDoc OpenAPI annotations on each endpoint
- [x] Create `demo-app/src/routes/users.js`
  - [x] `GET /api/users` - list all users (admin only)
  - [x] `GET /api/users/:id` - get user profile
  - [x] `PUT /api/users/:id` - update profile
  - [x] **INTENTIONAL VULN:** IDOR - no ownership check on `:id`
  - [x] JSDoc OpenAPI annotations with example IDs
- [x] Create `demo-app/src/routes/documents.js`
  - [x] `GET /api/documents` - list user's documents
  - [x] `GET /api/documents/:id` - get document by ID
  - [x] `POST /api/documents` - create document
  - [x] `DELETE /api/documents/:id` - delete document
  - [x] **INTENTIONAL VULN:** IDOR - no ownership check on `:id`
  - [x] JSDoc OpenAPI annotations with example IDs
- [x] Create `demo-app/src/routes/search.js`
  - [x] `GET /api/search?q=<query>` - search documents
  - [x] **INTENTIONAL VULN:** SQL Injection - query concatenated into SQL string (not parameterized)
  - [x] Add `// codeql[js/sql-injection]` suppression comment
  - [x] `GET /api/search/preview?q=<query>` - returns HTML with unsanitized query
  - [x] **INTENTIONAL VULN:** Reflected XSS - query echoed in HTML response
  - [x] JSDoc OpenAPI annotations

### 1.5 Dockerfile
- [x] Create `demo-app/Dockerfile`
  - [x] Multi-stage build (builder -> production)
  - [x] `FROM node:20-alpine` for both stages
  - [x] `npm ci --omit=dev` in builder
  - [x] Non-root user in production stage (`USER node`)
  - [x] `HEALTHCHECK` using `wget -qO-` (Alpine lacks curl)
  - [x] `EXPOSE 8080`

### 1.6 Commit
- [ ] Git commit: "feat(demo-app): add Express app with intentional vulnerability surfaces for DAST validation"

---

## Phase 2: Database Seed System

### 2.1 Schema & Seed Data
- [x] Create `db/seed/schema.sql`
  - [x] `CREATE TABLE users` (id SERIAL, email, name, password_hash, role, created_at)
  - [x] `CREATE TABLE documents` (id SERIAL, user_id FK, title, content, visibility, created_at)
  - [x] `CREATE TABLE organizations` (id SERIAL, name, owner_id FK)
  - [x] `CREATE TABLE api_tokens` (id SERIAL, user_id FK, token, scope, expires_at)
  - [x] Indices on foreign keys
- [x] Create `db/seed/mock_data.sql`
  - [x] 3 users: alice (user), bob (user), admin (admin)
  - [x] bcrypt hashes for password `Test123!`
  - [x] 6 documents across users (mixed public/private visibility)
  - [x] Alice's private docs (IDs 1-2), Bob's private docs (IDs 4-5)
  - [x] 2 organizations
  - [x] API tokens: valid, expired, admin-scoped
  - [x] All data obviously fake (`@test.local` emails)

### 2.2 Overlay System
- [x] Create `db/seed/overlay.sql.example`
  - [x] Template with comments: what's allowed vs forbidden
  - [x] Example INSERT for adding test data for a new feature
  - [x] Clear explanation of validation rules

### 2.3 AST-Based Validator
- [x] Create `db/seed/validate_overlay.py`
  - [x] `import pglast` for AST parsing
  - [x] File size check (reject > 100KB)
  - [x] psql meta-command detection (`\copy`, `\!`, etc.)
  - [x] URL/IP pattern detection in raw content
  - [x] Parse SQL into AST via `pglast.parse_sql()`
  - [x] Statement whitelist: InsertStmt, CreateStmt, IndexStmt, AlterTableStmt (ADD only)
  - [x] Deep INSERT inspection:
    - [x] Reject subqueries (SELECT inside INSERT values)
    - [x] Reject RETURNING clause
    - [x] Reject ON CONFLICT DO UPDATE
    - [x] Reject CTEs (WITH clauses)
  - [x] Dangerous function blacklist (pg_read_file, dblink, CHR, lo_import, etc.)
  - [x] Dollar-quoting obfuscation detection
  - [x] Clear error messages with offending statement excerpt
  - [x] Exit code 0 = valid, 1 = rejected

### 2.4 Validator Tests
- [x] Create `tests/test_validate_overlay.py`
  - [x] Test: Valid INSERT passes ?
  - [x] Test: Valid CREATE TABLE passes ?
  - [x] Test: Valid CREATE INDEX passes ?
  - [x] Test: INSERT with SELECT FROM pg_shadow -> REJECTED ?
  - [x] Test: INSERT with CTE -> REJECTED ?
  - [x] Test: CREATE FUNCTION -> REJECTED ?
  - [x] Test: Dollar-quoting obfuscation -> REJECTED ?
  - [x] Test: CHR() concatenation -> REJECTED ?
  - [x] Test: Comment-obfuscated keywords -> REJECTED ?
  - [x] Test: INSERT RETURNING -> REJECTED ?
  - [x] Test: ON CONFLICT DO UPDATE -> REJECTED ?
  - [x] Test: psql meta-commands -> REJECTED ?
  - [x] Test: URLs in data -> REJECTED ?
  - [x] Test: File > 100KB -> REJECTED ?
  - [x] Test: DROP TABLE -> REJECTED ?

### 2.5 Commit
- [x] Git commit: "feat(db): add schema, mock data, overlay system, and AST-based SQL validator with 15+ bypass test cases"

---

## Phase 3: Security Scripts

### 3.1 Runtime Environment
- [x] Create `security/run-dast-env.sh`
  - [x] `docker network create --internal dast-net`
  - [x] Start PostgreSQL on `dast-net`
  - [x] Start hardened app container on `dast-net`
  - [x] Start ZAP on `dast-net`
  - [x] Handle ZAP exit codes (0, 2, 3 = expected; >3 = crash)
  - [x] Cleanup via trap on exit
  - [x] `--cap-drop=ALL`
  - [x] `--security-opt=no-new-privileges:true`
  - [x] `--read-only`
  - [x] `--tmpfs /tmp:rw,noexec,nosuid,size=100m`
  - [x] `--user 1000:1000`
  - [x] `--memory=1g --memory-swap=1g`
  - [x] `--pids-limit=512`
  - [x] `--rm` for auto-cleanup
  - [x] Pass `DATABASE_URL` and `JWT_SECRET` as env vars

### 3.2 Auth Bootstrap
- [x] Create `scripts/bootstrap-auth.sh`
  - [x] Accept APP_URL parameter (default: `http://untrusted-app:8080`)
  - [x] Login as alice@test.local
  - [x] Parse JSON response with `jq`
  - [x] **v2 FIX:** Validate token extraction (exit 1 if login fails)
  - [x] Save token to `/tmp/zap-auth-token.txt`
  - [x] Also bootstrap Bob's token for authz tests
  - [x] Save Bob's token to `/tmp/zap-auth-token-bob.txt`

### 3.3 Delta Detection
- [x] Create `scripts/delta-detect.sh`
  - [x] Read changed files via `git diff --name-only origin/main...HEAD`
  - [x] Route file pattern matching (`*/routes/*`, `*/controllers/*`)
  - [x] **v2 FIX:** Regex `\.(get|post|put|delete|patch)\s*\(` (leading dot!)
  - [x] Core file detection triggers FULL scan (middleware, db, index, Dockerfile)
  - [x] Fail-safe: if no routes found AND no core changes -> FULL
  - [x] Deduplicate and output endpoint paths

### 3.4 Delta Scan Generator
- [x] Create `scripts/generate-delta-scan.sh`
  - [x] Read delta endpoint list from file
  - [x] Generate ZAP Automation Framework YAML with `includePaths` regexes
  - [x] If input is "FULL", copy full `automation.yaml` instead
  - [x] Output to `/tmp/zap-config.yaml`

### 3.5 AuthZ Tests
- [x] Create `scripts/authz-tests.sh`
  - [x] Login as Alice, login as Bob
  - [x] Alice tries Bob's private document -> 200/204 means IDOR detected
  - [x] Bob tries DELETE Alice's document -> 200/204 means IDOR detected
  - [x] Bob tries to update Alice's user profile
  - [x] Output: list of IDOR findings
  - [x] Exit 0 always (demo/default mode)
  - [x] Support `EXPECT_IDOR=true|false` for demo vs hardened apps

### 3.6 Self-Validation
- [x] Create `scripts/verify-canaries.sh`
  - [x] Read `reports/zap-report.json`
  - [x] Check for expected findings: "SQL Injection", "Cross Site Scripting", "Application Error Disclosure"
  - [x] Found -> pass, missing -> fail pipeline with coverage gap message

### 3.7 Report Parser
- [x] Create `scripts/parse-zap-report.js`
  - [x] Read ZAP JSON report
  - [x] Count by risk level (Critical/High/Medium/Low/Informational)
  - [x] **v2 FIX:** Configurable fail level via `ZAP_FAIL_LEVEL` env var (default: High)
  - [x] Generate markdown summary table for PR comment
  - [x] Return exit code 1 if findings exceed fail level

### 3.8 Delta Detection Tests
- [x] Create `tests/test_delta_detect.sh`
  - [x] Test: `router.get('/api/users')` matches -> extracts `/api/users`
  - [x] Test: `app.post('/api/auth/login')` matches -> extracts `/api/auth/login`
  - [x] Test: middleware change triggers FULL
  - [x] Test: Dockerfile change triggers FULL
  - [x] Test: non-route JS file -> no match -> FULL (fail-safe)

### 3.9 Commit
- [x] Git commit: "feat(security): add Docker network isolation, container hardening, delta detection, authz tests, and canary verification"

---

## Phase 4: ZAP Configuration

### 4.1 Version Pinning
- [x] Create `security/zap/.zap-version`
  - [x] Contains pinned version number (e.g., `2.16.0`)

### 4.2 Automation Config
- [x] Create `security/zap/automation.yaml`
  - [x] **v2 FIX:** `env.vars.AUTH_TOKEN` section for OS env passthrough
  - [x] Context: `zerodast-target` pointing to app URL
  - [x] Job: `openapi` - import from `/v3/api-docs` with `targetUrl` override to `http://untrusted-app:8080`
  - [x] Job: `replacer` - runtime-baked Bearer token injection via `REQ_HEADER`
  - [x] Job: `requestor` - seed `/api/debug/error` and `/api/search/preview`
  - [x] Job: `spider` - discover additional reachable URLs
  - [x] Job: `passiveScan-wait` - **v2 NEW:** passive scan before active (maxDuration: 2 min)
  - [x] Job: `activeScan` - 8 threads, **v2 FIX:** delayInMs: 50 (not 0), maxScanDuration: 30 min, tuned SQLi/XSS rules
  - [x] Job: `report` - JSON format to `/zap/wrk/zap-report.json`
  - [x] Job: `report` - HTML format to `/zap/wrk/zap-report.html`

### 4.3 Scan Policy
- [x] Create `security/zap/scan-policy.yaml`
  - [x] KEEP rules: XSS, SQLi, CORS, traversal-style checks
  - [x] Filter the policy toward the demo tech stack and away from irrelevant stacks

### 4.4 Baseline Suppression
- [x] Create `security/zap/.zap-baseline.json`
  - [x] Suppress known informational alerts from demo app
  - [x] Document each suppression with rationale

### 4.5 Commit
- [x] Git commit: "feat(zap): add pinned ZAP config with passive+active scan, auth injection, and tech-stack filtering"

---

## Phase 5: GitHub Actions Workflows

### 5.1 CI Workflow (Lane 1: Untrusted)
- [x] Create `.github/workflows/ci.yml`
  - [x] Name: `CI Tests`
  - [x] Trigger: `pull_request` on `main`
  - [x] Permissions: `contents: read` only
  - [x] Concurrency group with cancel-in-progress
  - [x] Checkout with `fetch-depth: 0`
  - [x] Use `working-directory: demo-app` for npm steps
  - [x] Install dependencies with `npm ci`
  - [x] Lint with `npm run lint`
  - [x] Test with `npm test`
  - [x] Run Semgrep with pinned SHA
  - [x] Run Gitleaks with pinned SHA
  - [x] Detect delta endpoints and save artifact file
  - [x] Build Docker image for the PR SHA
  - [x] `docker save` the image tarball
  - [x] Upload artifact bundle with retention-days `1`
  - [x] All actions pinned by SHA

### 5.2 DAST PR Workflow (Lane 2: Trusted)
- [x] Create `.github/workflows/dast-pr.yml`
  - [x] Name: `DAST PR Scan`
  - [x] Trigger: `workflow_run` of `CI Tests`
  - [x] Concurrency group by head SHA with cancel-in-progress
  - [x] `dast-scan` job on `ubuntu-22.04`
  - [x] `timeout-minutes: 15`
  - [x] Permissions: `actions: read`, `contents: read`
  - [x] Condition: only run for successful PR-triggered CI runs
  - [x] Checkout trusted `main`
  - [x] Download cross-workflow PR artifact bundle using `github-token` and `run-id`
  - [x] Install `pglast` and validate `overlay.sql` if present in artifacts
  - [x] Pre-pull Postgres and ZAP images
  - [x] `docker load` the PR image tarball
  - [x] Generate delta or full ZAP config from artifact input
  - [x] Seed DB with schema, mock data, and optional overlay
  - [x] Bootstrap auth token before ZAP
  - [x] Run ZAP in the isolated runtime environment
  - [x] Run authz tests post-scan
  - [x] Run canary verification only for `FULL` scans
  - [x] Upload DAST reports and summary artifacts
  - [x] `report-results` job runs on a separate runner
  - [x] Comment on the PR via `actions/github-script`
  - [x] Fail the workflow if findings exceed `ZAP_FAIL_LEVEL`

### 5.3 DAST Nightly Workflow
- [x] Create `.github/workflows/dast-nightly.yml`
  - [x] Trigger on `push` to `main`
  - [x] Trigger on nightly `schedule`
  - [x] `timeout-minutes: 30`
  - [x] Build the demo image from the current repo state
  - [x] Run full scan with same isolation/hardening layers
  - [x] Bootstrap auth before ZAP
  - [x] Run `verify-canaries.sh`
  - [x] Run `authz-tests.sh`
  - [x] Upload nightly report artifact
  - [x] Create a GitHub issue when findings exceed threshold

### 5.4 Commit
- [x] Git commit: `feat(ci): add 3-workflow DAST pipeline with privilege isolation, Docker network isolation, and configurable fail levels`

---

## Phase 6: AI-Driven Repo Inspection Prompts

### 6.1 Prompts
- [x] Create `ai-prompts/INSPECT_REPO.md`
  - [x] Step 1: Identify tech stack from manifest files
  - [x] Step 2: Find API surface (route definitions)
  - [x] Step 3: Understand auth mechanism (JWT, session, OAuth2, API key)
  - [x] Step 4: Understand data model (migrations, schemas, ORM models)
  - [x] Step 5: Identify DAST config (Docker, env vars, health endpoints)
  - [x] Output: Structured YAML profile for other prompts to consume
- [x] Create `ai-prompts/GENERATE_CONFIG.md`
  - [x] Takes INSPECT_REPO output
  - [x] Generates: ZAP automation YAML, seed data SQL, auth bootstrap script, docker-compose, scan policy
- [x] Create `ai-prompts/ADAPT_AUTH.md`
  - [x] Framework-specific auth bootstrap generators
  - [x] Templates for: Express+JWT, FastAPI+OAuth2, Spring+Sessions, Go+APIKey
- [x] Create `ai-prompts/ADAPT_SEED.md`
  - [x] Schema-aware mock data generators
  - [x] Reads migration files, generates INSERT statements covering all tables
- [x] Create `ai-prompts/AI_TRIAGE.md` (**v2 NEW**)
  - [x] Post-scan triage prompt
  - [x] Input: zap-report.json + source code of vulnerable endpoint
  - [x] Output: Root cause analysis + exact fix suggestion

### 6.2 Commit
- [x] Git commit: "feat(ai): add 5 structured AI prompts for universal repo adaptation and post-scan triage"

---

## Phase 7: Documentation

### 7.1 Root README
- [x] Create `README.md`
  - [x] Project name, tagline, architecture diagram (ASCII art)
  - [x] **v2 FIX:** "Self-benchmarked via AlphaSudo/sbtr-benchmark" (not "certified")
  - [x] Quick Start (5 steps)
  - [x] Comparison table: T1/T2/T3/T4
  - [x] ?? WARNING: Demo app is intentionally vulnerable - never deploy to production
  - [ ] License badge, status badges

### 7.2 Architecture Doc
- [x] Create `docs/ARCHITECTURE.md`
  - [x] 3-layer defense model with diagrams
  - [x] **v2 FIX:** "Privilege Isolation" not "Temporal Isolation" in security layers
  - [x] Docker `--internal` network explanation
  - [x] Data flow between workflows
  - [x] Speed lever explanations

### 7.3 Quick Start
- [x] Create `docs/QUICK_START.md`
  - [x] Prerequisites: Docker, Node.js 20+, Python 3.8+
  - [x] Step-by-step local setup
  - [x] Copy-paste YAML for different frameworks
  - [x] Common pitfalls (CRLF line endings, workflow name mismatch)

### 7.4 Contributing Security
- [x] Create `docs/CONTRIBUTING_SECURITY.md`
  - [x] How to write `overlay.sql` for new features
  - [x] Allowed/forbidden statement whitelist
  - [x] Why ON CONFLICT DO UPDATE is forbidden
  - [x] What happens when validation fails
  - [x] Sparse checkout path requirements

### 7.5 Supply Chain Rules
- [x] Create `docs/SUPPLY_CHAIN_RULES.md`
  - [x] 6-Rule Framework from AlphaSudo/sbtr-benchmark
  - [x] How each rule is implemented in workflows
  - [x] **Rule 4b exception** for DAST (sandboxed binary crossing) - documented
  - [x] Mapping to SBTR benchmark tiers

### 7.6 Threat Model
- [x] Create `docs/THREAT_MODEL.md`
  - [x] All attack vectors (poisoned seed, poisoned code, container escape, token hijacking)
  - [x] Mitigation for each
  - [x] **v2 NEW:** Fork PR behavior documented ("fork PRs get DAST only after merge - intentional")
  - [x] Residual risk: hypervisor escape (GitHub's problem)
  - [x] ZAP on `--internal` network nuance (trusted image, but documented)

### 7.7 Tier Comparison
- [x] Create `docs/TIER_COMPARISON.md`
  - [x] T1 vs T2 vs T3 (us) vs T4
  - [x] **v2 FIX:** Scores labeled as self-benchmarked
  - [x] Scan time, security score, cost, complexity
  - [x] When to upgrade from T3 to T4

### 7.8 AI Setup Guide
- [x] Create `docs/AI_GUIDED_SETUP.md`
  - [x] How to use the AI prompts
  - [x] Workflow: Inspect -> Generate -> Adapt -> Validate
  - [x] Dry-run mode: verify auth bootstrap before full scan
  - [x] Examples for Node.js, Python, Java, Go

### 7.9 Commit
- [x] Git commit: "docs: add comprehensive documentation covering architecture, security, setup, and AI-guided adaptation"

---

## Phase 8: Local Development Tools

### 8.1 Docker Compose
- [x] Create `docker-compose.yml`
  - [x] DB service: postgres:16-alpine with explicit healthcheck
  - [x] App service: builds from `./demo-app`, depends on healthy DB
  - [x] ZAP service: pinned version, `profiles: ["dast"]`, network mode
  - [x] All env vars (DATABASE_URL, JWT_SECRET = throwaway values)
  - [x] Port mappings: 5432 (DB), 8080 (App)

### 8.2 Makefile
- [x] Create `Makefile`
  - [x] `make build` — build demo-app Docker image
  - [x] `make up` — start DB + app, wait for healthy
  - [x] `make seed` — run schema.sql + mock_data.sql
  - [x] `make dast` — full local DAST (up + seed + auth + ZAP)
  - [x] `make validate FILE=overlay.sql` — run AST validator
  - [x] `make test` — run pytest for validator + bash tests for delta
  - [x] `make authz` — run authz tests
  - [x] `make clean` — docker compose down -v --remove-orphans

### 8.3 Local DAST Runner
- [x] Create `scripts/run-dast-local.sh`
  - [x] Local wrapper runs build -> isolated runtime -> auth bootstrap -> ZAP scan -> verify canaries -> report
  - [x] Trap handler for cleanup on exit/error
  - [x] Print summary at end

### 8.4 Commit
- [x] Git commit: "feat(dev): add docker-compose, Makefile, and local DAST runner for developer testing"

---

## Phase 9: Verification & Validation

### 9.1 Unit Tests
- [x] Run `pip install pglast==6.* pytest`
- [x] Run `pytest tests/test_validate_overlay.py -v` - all 15+ tests pass
- [x] Run `bash tests/test_delta_detect.sh` - all regex tests pass

### 9.2 Local Full DAST
- [ ] Run `make build`
- [ ] Run `make up` — app starts, healthcheck passes
- [ ] Run `make seed` — DB seeded without errors
- [x] Run local DAST runner (`make dast` / `scripts/run-dast-local.sh`) - full ZAP scan completes
- [x] Verify ZAP finds: SQL Injection ?
- [x] Verify ZAP finds: Cross Site Scripting ?
- [ ] Verify ZAP finds: Missing security headers ✅
- [x] Run `bash scripts/verify-canaries.sh` - all canaries pass
- [ ] Run `bash scripts/authz-tests.sh` — IDOR surfaces confirmed

### 9.3 Network Isolation Verification
- [ ] Start app on `--internal` network
- [ ] From app container: `wget -qO- https://httpbin.org/get` → FAILS ✅
- [ ] From app container: `wget -qO- http://dast-db:5432` → SUCCEEDS ✅

### 9.4 Container Hardening Verification
- [ ] Verify `--read-only` works with Node.js demo app (no crash)
- [ ] Verify `--pids-limit=512` sufficient under ZAP load
- [ ] Verify `--memory=1g` sufficient (no OOM kills)

### 9.5 Overlay Bypass Testing
- [ ] Submit `INSERT INTO users SELECT * FROM pg_shadow` → validator rejects ❌
- [ ] Submit `CREATE FUNCTION evil()` → validator rejects ❌
- [ ] Submit file with `\copy` command → validator rejects ❌
- [ ] Submit file > 100KB → validator rejects ❌
- [ ] Submit valid INSERT → validator accepts ✅

### 9.6 Line Ending Check
- [x] Verify all `.sh` files have Unix line endings (LF, not CRLF)
- [x] Add `.gitattributes` if needed: `*.sh text eol=lf`

### 9.7 Final Commit
- [ ] Git commit: "test: verify all security layers, canary detection, and overlay bypass rejection"

---

## Phase 10: Polish & Ship

### 10.1 Final Review
- [ ] Review all `@<SHA>` placeholders → replace with real pinned SHAs
- [ ] Review all `// codeql[...]` suppression comments are present on intentional vulns
- [ ] Review `workflow_run` workflow name matches exactly
- [ ] Review `.gitattributes` for line endings
- [ ] Run full `make dast` one final time — clean run

### 10.2 Git Tags
- [ ] Tag: `v0.1.0` — first local-validated release

### 10.3 Pre-Public Checklist (for when we go public)
- [ ] 3 consecutive successful E2E runs locally
- [ ] Test fork PR path (only ci.yml runs — no DAST, no secrets)
- [ ] Test merge to main (dast-nightly triggers full scan)
- [ ] Test malicious overlay PR (validator blocks)
- [ ] Measure actual CI time: target 5-9 min delta, 15-25 min full
- [ ] Create `SECURITY.md` for public repo
- [ ] Push to AlphaSudo/zerodast

---

## Summary

| Phase | Items | Est. Time |
|-------|-------|-----------|
| 0. Scaffolding | 5 | 15 min |
| 1. Demo App | 23 | ~4 hours |
| 2. DB Seed | 12 | ~2 hours |
| 3. Security Scripts | 15 | ~3 hours |
| 4. ZAP Config | 5 | ~3 hours |
| 5. Workflows | 14 | ~4 hours |
| 6. AI Prompts | 6 | ~2 hours |
| 7. Documentation | 10 | ~2 hours |
| 8. Local Tools | 4 | ~1 hour |
| 9. Verification | 12 | ~2 hours |
| 10. Polish | 5 | ~30 min |
| **Total** | **111 items** | **~21 hours** |













