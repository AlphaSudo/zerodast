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
  - [x] Non-root user (1000:1000) in production stage
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
- [ ] Git commit: "feat(db): add schema, mock data, overlay system, and AST-based SQL validator with 15+ bypass test cases"

---

## Phase 3: Security Scripts

### 3.1 Network Isolation
- [ ] Create `security/network-isolation.sh`
  - [ ] `docker network create --internal dast-net`
  - [ ] Start PostgreSQL on `dast-net`
  - [ ] Start hardened app container on `dast-net`
  - [ ] Start ZAP on `dast-net`
  - [ ] Verify: app can reach DB ✅
  - [ ] Verify: app CANNOT reach internet ✅
  - [ ] Handle ZAP exit codes (0, 2, 3 = expected; >3 = crash)
  - [ ] Cleanup: `docker network rm dast-net` on exit (trap)

### 3.2 Container Hardening
- [ ] Create `security/container-hardening.sh`
  - [ ] `--cap-drop=ALL`
  - [ ] `--security-opt=no-new-privileges:true`
  - [ ] `--read-only`
  - [ ] `--tmpfs /tmp:rw,noexec,nosuid,size=100m`
  - [ ] `--user 1000:1000`
  - [ ] `--memory=1g --memory-swap=1g`
  - [ ] `--pids-limit=512`
  - [ ] `--rm` for auto-cleanup
  - [ ] `--network dast-net` parameter
  - [ ] Pass `DATABASE_URL` and `JWT_SECRET` as env vars
  - [ ] Trap handler for cleanup on failure
  - [ ] Note: 6 flags (removed `seccomp=default` — Docker applies it by default)

### 3.3 Auth Bootstrap
- [ ] Create `scripts/bootstrap-auth.sh`
  - [ ] Accept APP_URL parameter (default: `http://untrusted-app:8080`)
  - [ ] Login as alice@test.local
  - [ ] Parse JSON response with `jq`
  - [ ] **v2 FIX:** Validate token extraction (exit 1 if login fails)
  - [ ] Save token to `/tmp/zap-auth-token.txt`
  - [ ] Also bootstrap Bob's token for authz tests
  - [ ] Save Bob's token to `/tmp/zap-auth-token-bob.txt`

### 3.4 Delta Detection
- [ ] Create `scripts/delta-detect.sh`
  - [ ] Read changed files via `git diff --name-only origin/main...HEAD`
  - [ ] Route file pattern matching (`*/routes/*`, `*/controllers/*`)
  - [ ] **v2 FIX:** Regex `\.(get|post|put|delete|patch)\s*\(` (leading dot!)
  - [ ] Core file detection triggers FULL scan (middleware, db, index, Dockerfile)
  - [ ] Fail-safe: if no routes found AND no core changes → FULL (not empty)
  - [ ] Deduplicate and output endpoint paths

### 3.5 Delta Scan Generator
- [ ] Create `scripts/generate-delta-scan.sh`
  - [ ] Read delta endpoint list from file
  - [ ] Generate ZAP Automation Framework YAML with `includePaths` regexes
  - [ ] If input is "FULL", copy full `automation.yaml` instead
  - [ ] Output to `/tmp/zap-config.yaml`

### 3.6 AuthZ Tests
- [ ] Create `scripts/authz-tests.sh`
  - [ ] Login as Alice, login as Bob
  - [ ] Alice tries Bob's private document → expect 403 (but 200 = IDOR found ✅)
  - [ ] Bob tries DELETE Alice's document → expect 403 (but 200 = IDOR found ✅)
  - [ ] Alice tries Bob's user profile edit → expect 403
  - [ ] Output: list of IDOR findings
  - [ ] Exit 0 always (IDOR is intentional in demo app)
  - [ ] Warning if NO IDOR found (means demo was patched)

### 3.7 Self-Validation
- [ ] Create `scripts/verify-canaries.sh`
  - [ ] Read `reports/zap-report.json`
  - [ ] Check for expected findings: "SQL Injection", "Cross Site Scripting", "X-Content-Type-Options"
  - [ ] ✅ found → pass, ❌ missing → fail pipeline with "coverage gap" message

### 3.8 Report Parser
- [ ] Create `scripts/parse-zap-report.js`
  - [ ] Read ZAP JSON report
  - [ ] Count by risk level (Critical/High/Medium/Low/Informational)
  - [ ] **v2 FIX:** Configurable fail level via `ZAP_FAIL_LEVEL` env var (default: High)
  - [ ] Generate markdown summary table for PR comment
  - [ ] Return exit code 1 if findings exceed fail level

### 3.9 Delta Detection Tests
- [ ] Create `tests/test_delta_detect.sh`
  - [ ] Test: `router.get('/api/users')` matches → extracts `/api/users`
  - [ ] Test: `app.post('/api/auth/login')` matches → extracts `/api/auth/login`
  - [ ] Test: middleware change triggers FULL
  - [ ] Test: Dockerfile change triggers FULL
  - [ ] Test: non-route JS file → no match → FULL (fail-safe)

### 3.10 Commit
- [ ] Git commit: "feat(security): add Docker network isolation, container hardening, delta detection, authz tests, and canary verification"

---

## Phase 4: ZAP Configuration

### 4.1 Version Pinning
- [ ] Create `security/zap/.zap-version`
  - [ ] Contains pinned version number (e.g., `2.16.0`)

### 4.2 Automation Config
- [ ] Create `security/zap/automation.yaml`
  - [ ] **v2 FIX:** `env.vars.AUTH_TOKEN` section for OS env passthrough
  - [ ] Context: `zerodast-target` pointing to app URL
  - [ ] Job: `openapi` — import from `/v3/api-docs`
  - [ ] Job: `replacer` — **v2 FIX:** `matchType: REQ_HEADER_ADD` (not REQ_HEADER)
  - [ ] Job: `passiveScan-wait` — **v2 NEW:** passive scan before active (maxDuration: 2 min)
  - [ ] Job: `activeScan` — 8 threads, **v2 FIX:** delayInMs: 50 (not 0), maxScanDuration: 30 min
  - [ ] Job: `report` — JSON format to `/zap/wrk/zap-report.json`
  - [ ] Job: `report` — HTML format to `/zap/wrk/zap-report.html`

### 4.3 Scan Policy
- [ ] Create `security/zap/scan-policy.yaml`
  - [ ] KEEP rules: XSS (reflected + persistent), SQLi (PostgreSQL), SSRF, Path Traversal, RCE, CORS, CSRF
  - [ ] DISABLE rules: Oracle/MySQL/SQLite/MSSQL SQLi, ASP injection, Java deserialization, .NET exploits, PHP-specific, Windows OS injection

### 4.4 Baseline Suppression
- [ ] Create `security/zap/.zap-baseline.json`
  - [ ] Suppress known informational alerts from demo app
  - [ ] Document each suppression with rationale

### 4.5 Commit
- [ ] Git commit: "feat(zap): add pinned ZAP config with passive+active scan, auth injection, and tech-stack filtering"

---

## Phase 5: GitHub Actions Workflows

### 5.1 CI Workflow (Lane 1: Untrusted)
- [ ] Create `.github/workflows/ci.yml`
  - [ ] Name: `CI Tests` (exact — dast-pr.yml depends on this name)
  - [ ] Trigger: `on: pull_request: branches: [main]`
  - [ ] Permissions: `contents: read` only
  - [ ] Concurrency group with cancel-in-progress
  - [ ] Step: checkout with **fetch-depth: 0** (for delta detection)
  - [ ] Step: Install dependencies (`npm ci`)
  - [ ] Step: Lint (`npm run lint`)
  - [ ] Step: Unit tests (`npm test`)
  - [ ] Step: SAST with Semgrep (pinned SHA)
  - [ ] Step: Secret detection with Gitleaks (pinned SHA)
  - [ ] Step: Delta endpoint detection → output to file
  - [ ] Step: Build Docker image with exact PR number tag
  - [ ] Step: `docker save` → tar file
  - [ ] Step: Upload artifact (image tar + delta endpoints) with retention-days: 1
  - [ ] All actions pinned by SHA (Rule 0: PIN)

### 5.2 DAST PR Workflow (Lane 2: Trusted)
- [ ] Create `.github/workflows/dast-pr.yml`
  - [ ] Name: `DAST PR Scan`
  - [ ] Trigger: `on: workflow_run: workflows: ["CI Tests"]`
  - [ ] Concurrency group by head SHA with cancel-in-progress
  - [ ] **Job 1: dast-scan**
    - [ ] `runs-on: ubuntu-22.04` (pinned runner)
    - [ ] `timeout-minutes: 15`
    - [ ] Permissions: `actions: read`, `contents: read` (NO write)
    - [ ] Condition: only run if CI succeeded and was a PR event
    - [ ] Step: Checkout main branch (trusted scripts) — `ref: main`
    - [ ] Step: Sparse checkout PR code (only `db/seed/overlay.sql`)
    - [ ] Step: Install pglast (`pip install pglast==6.*`)
    - [ ] Step: Validate PR overlay (if exists)
    - [ ] Step: Pre-pull all Docker images (Postgres, ZAP) BEFORE any isolation
    - [ ] Step: Create Docker `--internal` network
    - [ ] Step: Start PostgreSQL on internal network
    - [ ] Step: Wait for DB healthy
    - [ ] Step: Seed DB (schema.sql + mock_data.sql + overlay.sql if valid)
    - [ ] Step: Download PR artifact (image tar + delta file)
      - [ ] Include `github-token: ${{ secrets.GITHUB_TOKEN }}`
      - [ ] Include `run-id: ${{ github.event.workflow_run.id }}`
    - [ ] Step: `docker load` PR image
    - [ ] Step: Start hardened PR app on internal network (container-hardening.sh)
    - [ ] Step: Wait for app healthy (timeout 60s)
    - [ ] Step: Bootstrap auth (Alice + Bob tokens)
    - [ ] Step: Configure DAST scope (delta or full)
    - [ ] Step: Run ZAP on internal network
      - [ ] `-config check.onstart=false`
      - [ ] `-Xmx3g -Xms1g`
      - [ ] Handle exit codes (2,3 = expected findings)
    - [ ] Step: Run authz tests
    - [ ] Step: Run verify-canaries.sh (nightly only, skip on delta)
    - [ ] Step: Kill untrusted container (always, even on failure)
    - [ ] Step: Remove Docker network (always)
    - [ ] Step: Upload DAST report artifact (retention-days: 30)
  - [ ] **Job 2: report-results**
    - [ ] `needs: dast-scan`
    - [ ] `runs-on: ubuntu-22.04` (DIFFERENT runner — no untrusted code)
    - [ ] `timeout-minutes: 5`
    - [ ] Permissions: `pull-requests: write`, `issues: write`
    - [ ] Step: Checkout main (only `scripts/parse-zap-report.js`)
    - [ ] Step: Download DAST report artifact
    - [ ] Step: Parse report and post PR comment via `actions/github-script`
    - [ ] Step: Fail if findings exceed `ZAP_FAIL_LEVEL`

### 5.3 DAST Nightly Workflow
- [ ] Create `.github/workflows/dast-nightly.yml`
  - [ ] Trigger: `on: push: branches: [main]` + `schedule: cron: '0 2 * * *'`
  - [ ] `timeout-minutes: 30`
  - [ ] Full scan — all endpoints, no delta
  - [ ] Same security layers (internal network, container hardening)
  - [ ] Longer ZAP timeout (60 min active scan)
  - [ ] Run verify-canaries.sh (self-validation)
  - [ ] Run authz-tests.sh
  - [ ] Upload report as artifact
  - [ ] Create GitHub Issue for new critical/high findings

### 5.4 Commit
- [ ] Git commit: "feat(ci): add 3-workflow DAST pipeline with privilege isolation, Docker network isolation, and configurable fail levels"

---

## Phase 6: AI-Driven Repo Inspection Prompts

### 6.1 Prompts
- [ ] Create `ai-prompts/INSPECT_REPO.md`
  - [ ] Step 1: Identify tech stack from manifest files
  - [ ] Step 2: Find API surface (route definitions)
  - [ ] Step 3: Understand auth mechanism (JWT, session, OAuth2, API key)
  - [ ] Step 4: Understand data model (migrations, schemas, ORM models)
  - [ ] Step 5: Identify DAST config (Docker, env vars, health endpoints)
  - [ ] Output: Structured YAML profile for other prompts to consume
- [ ] Create `ai-prompts/GENERATE_CONFIG.md`
  - [ ] Takes INSPECT_REPO output
  - [ ] Generates: ZAP automation YAML, seed data SQL, auth bootstrap script, docker-compose, scan policy
- [ ] Create `ai-prompts/ADAPT_AUTH.md`
  - [ ] Framework-specific auth bootstrap generators
  - [ ] Templates for: Express+JWT, FastAPI+OAuth2, Spring+Sessions, Go+APIKey
- [ ] Create `ai-prompts/ADAPT_SEED.md`
  - [ ] Schema-aware mock data generators
  - [ ] Reads migration files, generates INSERT statements covering all tables
- [ ] Create `ai-prompts/AI_TRIAGE.md` (**v2 NEW**)
  - [ ] Post-scan triage prompt
  - [ ] Input: zap-report.json + source code of vulnerable endpoint
  - [ ] Output: Root cause analysis + exact fix suggestion

### 6.2 Commit
- [ ] Git commit: "feat(ai): add 5 structured AI prompts for universal repo adaptation and post-scan triage"

---

## Phase 7: Documentation

### 7.1 Root README
- [ ] Create `README.md`
  - [ ] Project name, tagline, architecture diagram (ASCII art)
  - [ ] **v2 FIX:** "Self-benchmarked via AlphaSudo/sbtr-benchmark" (not "certified")
  - [ ] Quick Start (5 steps)
  - [ ] Comparison table: T1/T2/T3/T4
  - [ ] ⚠️ WARNING: Demo app is intentionally vulnerable — never deploy to production
  - [ ] License badge, status badges

### 7.2 Architecture Doc
- [ ] Create `docs/ARCHITECTURE.md`
  - [ ] 3-layer defense model with diagrams
  - [ ] **v2 FIX:** "Privilege Isolation" not "Temporal Isolation" in security layers
  - [ ] Docker `--internal` network explanation
  - [ ] Data flow between workflows
  - [ ] Speed lever explanations

### 7.3 Quick Start
- [ ] Create `docs/QUICK_START.md`
  - [ ] Prerequisites: Docker, Node.js 20+, Python 3.8+
  - [ ] Step-by-step local setup
  - [ ] Copy-paste YAML for different frameworks
  - [ ] Common pitfalls (CRLF line endings, workflow name mismatch)

### 7.4 Contributing Security
- [ ] Create `docs/CONTRIBUTING_SECURITY.md`
  - [ ] How to write `overlay.sql` for new features
  - [ ] Allowed/forbidden statement whitelist
  - [ ] Why ON CONFLICT DO UPDATE is forbidden
  - [ ] What happens when validation fails
  - [ ] Sparse checkout path requirements

### 7.5 Supply Chain Rules
- [ ] Create `docs/SUPPLY_CHAIN_RULES.md`
  - [ ] 6-Rule Framework from AlphaSudo/sbtr-benchmark
  - [ ] How each rule is implemented in workflows
  - [ ] **Rule 4b exception** for DAST (sandboxed binary crossing) — documented
  - [ ] Mapping to SBTR benchmark tiers

### 7.6 Threat Model
- [ ] Create `docs/THREAT_MODEL.md`
  - [ ] All attack vectors (poisoned seed, poisoned code, container escape, token hijacking)
  - [ ] Mitigation for each
  - [ ] **v2 NEW:** Fork PR behavior documented ("fork PRs get DAST only after merge — intentional")
  - [ ] Residual risk: hypervisor escape (GitHub's problem)
  - [ ] ZAP on `--internal` network nuance (trusted image, but documented)

### 7.7 Tier Comparison
- [ ] Create `docs/TIER_COMPARISON.md`
  - [ ] T1 vs T2 vs T3 (us) vs T4
  - [ ] **v2 FIX:** Scores labeled as self-benchmarked
  - [ ] Scan time, security score, cost, complexity
  - [ ] When to upgrade from T3 to T4

### 7.8 AI Setup Guide
- [ ] Create `docs/AI_GUIDED_SETUP.md`
  - [ ] How to use the AI prompts
  - [ ] Workflow: Inspect → Generate → Adapt → Validate
  - [ ] Dry-run mode: verify auth bootstrap before full scan
  - [ ] Examples for Node.js, Python, Java, Go

### 7.9 Commit
- [ ] Git commit: "docs: add comprehensive documentation covering architecture, security, setup, and AI-guided adaptation"

---

## Phase 8: Local Development Tools

### 8.1 Docker Compose
- [ ] Create `docker-compose.yml`
  - [ ] DB service: postgres:16-alpine with explicit healthcheck
  - [ ] App service: builds from `./demo-app`, depends on healthy DB
  - [ ] ZAP service: pinned version, `profiles: ["dast"]`, network mode
  - [ ] All env vars (DATABASE_URL, JWT_SECRET = throwaway values)
  - [ ] Port mappings: 5432 (DB), 8080 (App)

### 8.2 Makefile
- [ ] Create `Makefile`
  - [ ] `make build` — build demo-app Docker image
  - [ ] `make up` — start DB + app, wait for healthy
  - [ ] `make seed` — run schema.sql + mock_data.sql
  - [ ] `make dast` — full local DAST (up + seed + auth + ZAP)
  - [ ] `make validate FILE=overlay.sql` — run AST validator
  - [ ] `make test` — run pytest for validator + bash tests for delta
  - [ ] `make authz` — run authz tests
  - [ ] `make clean` — docker compose down -v --remove-orphans

### 8.3 Local DAST Runner
- [ ] Create `scripts/run-dast-local.sh`
  - [ ] docker-compose up → seed → auth bootstrap → ZAP scan → verify canaries → report
  - [ ] Trap handler for cleanup on exit/error
  - [ ] Print summary at end

### 8.4 Commit
- [ ] Git commit: "feat(dev): add docker-compose, Makefile, and local DAST runner for developer testing"

---

## Phase 9: Verification & Validation

### 9.1 Unit Tests
- [ ] Run `pip install pglast==6.* pytest`
- [x] Run `pytest tests/test_validate_overlay.py -v` — all 15+ tests pass
- [ ] Run `bash tests/test_delta_detect.sh` — all regex tests pass

### 9.2 Local Full DAST
- [ ] Run `make build`
- [ ] Run `make up` — app starts, healthcheck passes
- [ ] Run `make seed` — DB seeded without errors
- [ ] Run `make dast` — full ZAP scan completes
- [ ] Verify ZAP finds: SQL Injection ✅
- [ ] Verify ZAP finds: Cross Site Scripting ✅
- [ ] Verify ZAP finds: Missing security headers ✅
- [ ] Run `bash scripts/verify-canaries.sh` — all canaries pass
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
- [ ] Verify all `.sh` files have Unix line endings (LF, not CRLF)
- [ ] Add `.gitattributes` if needed: `*.sh text eol=lf`

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


