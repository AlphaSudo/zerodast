---
title: "How I Got Enterprise-Grade DAST for Free in GitHub Actions (And Why Vanilla ZAP Finds 0 API Endpoints)"
published: true
description: "On 4 real-world APIs with 170k+ combined GitHub stars, vanilla ZAP discovered 0 API endpoints. Here's exactly why, how I fixed it, and how it compares to $180k/year Checkmarx DAST."
tags: security, devops, github, opensource
canonical_url: https://alphasudo.github.io/zerodast/blog/free-dast-github-actions
cover_image: https://raw.githubusercontent.com/AlphaSudo/zerodast/main/docs/arch.png
---

# How I Got Enterprise-Grade DAST for Free in GitHub Actions

Most developers don't run Dynamic Application Security Testing (DAST) in their CI pipelines. Not because they don't want to — but because every viable option seems to cost $180k/year, take 60 minutes per scan, or require a PhD in ZAP configuration.

I spent months building **[ZeroDAST](https://github.com/AlphaSudo/zerodast)** to prove that's a false choice.

This is the story of what I found, the real data behind it, a hands-on tutorial, and an honest comparison with enterprise DAST.

---

## Part 1: Why Vanilla ZAP Discovers 0 API Endpoints

I started where most teams start: running OWASP ZAP against my API.

```bash
docker run -t zaproxy/zap-stable zap-api-scan.py \
  -t http://my-api:3000/api-docs -f openapi
```

The scanner ran. It produced a report. And the result was **essentially useless for API security.**

I tested vanilla ZAP against **four high-profile open-source targets** — NocoDB (48k ⭐), Strapi (67k ⭐), Directus (29k ⭐), and Medusa (27k ⭐). Same GitHub-hosted runners, same ZAP version (`2.17.0`), same Docker Compose targets. The vanilla baseline scripts are [public and executable](https://github.com/AlphaSudo/zerodast/tree/main/benchmarks/vanilla-baseline).

| Target | ⭐ Stars | Vanilla ZAP API URIs | ZeroDAST API URIs |
|---|---:|---:|---:|
| **NocoDB** | 48k+ | **0** | **7** |
| **Strapi** | 67k+ | **0** | **8** |
| **Directus** | 29k+ | **0** | **30** |
| **Medusa** | 27k+ | **0** | **3** |
| **Total** | **171k+** | **0** | **48** |

That's not a typo. Vanilla ZAP discovered **zero API endpoints** across all four targets. It found some frontend/static findings — CSP headers, cookie flags — but nothing behind authentication. The entire API surface was invisible.

### The Three Auth Walls

**Wall 1: Non-standard auth headers.** NocoDB uses a custom header called `xc-auth` — not `Authorization`, not `X-Token`. If your scanner sends `Authorization: Bearer <token>`, NocoDB ignores it. Every request returns `401`. The spider crawls the Nuxt.js SPA shell and finds frontend issues, but the API is locked.

**Wall 2: Nested token responses.** Even if you know the right header, you need to extract the token from the login response. Strapi returns `{ "data": { "token": "..." } }`. Directus goes deeper: `{ "data": { "access_token": "..." } }`. Vanilla ZAP's auth mechanisms expect the token at the root level. When it's nested under `data`, ZAP extracts nothing.

**Wall 3: Admin vs user API separation.** Strapi has two distinct auth systems — `/api/auth/local` for frontend users and `/admin/login` for admins. If you authenticate as a frontend user, the entire admin API surface is invisible. And the admin surface is usually **where the interesting vulnerabilities live**.

### The Full Signal Impact

| Target | Vanilla ZAP | ZeroDAST | Signal Lift |
|---|---|---|---|
| **NocoDB** | 8M/15L/7I — **0 API** URIs | 11M/15L/8I — **7 API** URIs | +13% findings, superset |
| **Strapi** | 3M/7L/4I — **0 API** URIs | 8M/10L/8I — **8 API** URIs | +86% findings, superset |
| **Directus** | 10M/10L/8I — **0 API** URIs | 13M/12L/26I — **30 API** URIs | +82% findings, superset |
| **Medusa** | 2M/3L/0I — **0 API** URIs | 4M/2L/0I — **3 API** URIs | Superset |
| **FastAPI** | **0** — scan failed entirely | **14 API** alert URIs | ∞ (vanilla can't scan it) |
| **Fleet Total** | **77 findings, 0 API** | **117 findings, 48 API** | **+52% more findings** |

ZeroDAST is a **strict superset** of vanilla ZAP — it finds everything vanilla finds (frontend/static) **plus** all authenticated API findings. Switching has zero signal regression.

Auth isn't an incremental improvement. It's the **entire difference** between a DAST scan that finds real API vulnerabilities and one that wastes your CI minutes on frontend noise.

---

## Part 2: What ZeroDAST Actually Is

**ZeroDAST** is an open-source CI DAST orchestration framework — not a scanner itself. It wraps OWASP ZAP inside a security-hardened pipeline with:

- **Adapter-based authentication** — 4 proven auth styles, zero custom scripting
- **Two-lane privilege isolation** — untrusted PR code never touches the DAST runner
- **Container hardening** — `cap-drop ALL`, `no-new-privileges`, read-only root, memory limits
- **Delta-scoped PR scanning** — only scan changed routes, not the whole API
- **Intelligent reporting** — diff-aware baselines, remediation guides, API inventory

The auth problem is solved through a **declarative adapter model** where auth configuration is config — not code:

```json
{
  "auth": {
    "adapter": "json-token-login",
    "loginUrl": "/api/auth/login",
    "responseTokenField": "data.token",
    "headerName": "Authorization",
    "headerValuePrefix": "Bearer "
  }
}
```

Non-standard headers? Set `"headerName": "xc-auth"`. Nested token? Use dot-path notation: `"responseTokenField": "data.access_token"`. No ZAP scripting. No custom code.

Auth is **validated before scanning** — if it fails, you know before wasting 5 minutes:

```
[auth] POST /api/v1/auth/user/signin → 200 ✓
[auth] Token extracted: eyJhbGciOi... (length: 189)
[auth] Protected route GET /api/v1/auth/user/me → 200 ✓
[auth] Admin route GET /api/v1/db/meta/projects → 200 ✓
[auth] Auth bootstrap: PASS
```

### 4 Proven Auth Adapters

| Adapter | Auth Flow | Proven On |
|---|---|---|
| `json-token-login` | POST JSON → extract Bearer token | NocoDB, Strapi, Directus, Medusa, Petclinic |
| `form-cookie-login` | POST form → session cookie | Demo app |
| `json-session-login` | POST JSON → session header | Django Styleguide |
| `form-urlencoded-token-login` | OAuth2-style form → Bearer token | FastAPI |

---

## Part 3: Tutorial — Your First ZeroDAST Scan (5 Minutes)

### Prerequisites

Docker (latest stable), Node.js 22+, Git.

### Step 1: Clone and Install

```bash
git clone https://github.com/AlphaSudo/zerodast.git
cd zerodast
cd demo-app && npm install && cd ..
```

### Step 2: Run Your First DAST Scan

```bash
chmod +x scripts/run-dast-local.sh
./scripts/run-dast-local.sh
```

That's it. Behind the scenes:

1. **Docker `--internal` network** isolates app, database, and ZAP from the outside world
2. **Container hardening** — app runs with `cap-drop ALL`, read-only root, memory/PID limits
3. **Auth bootstrap** — auto-registers user + admin, logs in, extracts tokens, injects into ZAP
4. **OpenAPI import** → Spider → Active Scan through authenticated requests
5. **Report generation** — structured findings, remediation guide, API inventory

### Step 3: Read Your Results (~3 min later)

```
reports/
├── zap-report.json              # Raw ZAP findings
├── zap-report.html              # Human-readable report
├── environment-manifest.json    # What was scanned and how
├── result-state.json            # Triage state (clean / needs_triage)
├── remediation-guide.md         # Prioritized fix guidance
├── operational-reliability.json # Runtime health metrics
├── api-inventory.json           # Route coverage breakdown
└── api-inventory.md             # Human-readable API inventory
```

The **remediation guide** separates findings into:
- **New findings** → fix these first
- **Persisting findings** → decide: fix or accept
- **Resolved findings** → guard against regression

### Setting Up CI: The Two-Profile Model

**PR scans (~3 min):** When someone opens a PR, ZeroDAST detects changed files via `git diff`, extracts API routes from changed controllers, and generates a scoped ZAP config targeting only those routes. Runs in a separate trusted workflow — PR code never gets `secrets` access.

```
PR opens → git diff → route extraction from changed files
    ├── routes changed → scoped ZAP config (targeted seeds only)
    └── core/middleware changed → escalate to FULL scan
```

**Nightly scans (~5 min):** Full API surface, every night. Opens a deduplicated triage issue if threshold is exceeded.

**Why the split matters — it's a security architecture:**

| Security Control | Vanilla CI | ZeroDAST |
|---|---|---|
| PR code accesses secrets | ✅ Yes | ❌ No — `workflow_run` isolation |
| PR code can modify scan config | ✅ Yes | ❌ No — artifact handoff only |
| Scanner has internet access | ✅ Yes | ❌ No — `--internal` network |
| Containers are hardened | ❌ No | ✅ Read-only, cap-dropped, memory-limited |

### Installing in Your Own Repo

ZeroDAST adds exactly two things to your repository:

1. Two workflow files (`.github/workflows/zerodast-pr.yml` + `zerodast-nightly.yml`)
2. A `zerodast/` config directory

```powershell
# Install
./prototypes/model1-template/install.ps1 -TargetRepoPath 'C:\path\to\your-repo'

# Configure zerodast/config.json with your auth/endpoints/seeds
# Run locally
chmod +x zerodast/run-scan.sh
ZERODAST_MODE=pr ./zerodast/run-scan.sh

# Uninstall (clean removal)
./prototypes/model1-template/uninstall.ps1 -TargetRepoPath 'C:\path\to\your-repo'
```

Full install guide: **[MODEL1_INSTALL_GUIDE.md](https://github.com/AlphaSudo/zerodast/blob/main/docs/MODEL1_INSTALL_GUIDE.md)**

---

## Part 4: Honest Comparison — ZeroDAST vs Checkmarx DAST

If you've ever seen a Checkmarx DAST quote — $600-$1,200/dev/year, $180k-$350k annually for 50-100 devs — you've wondered if there's an open-source alternative. **Here's the honest answer.**

### Full Capability Matrix

| Capability | ZeroDAST | Checkmarx DAST |
|---|---|---|
| **Cost** | **$0** — Apache 2.0 | **$180k-$350k/year** (50-100 devs) |
| **CI scan speed** | **~3 min PR, ~5 min nightly** | 15-60 min typical |
| **Auth: Token/session REST** | ✅ 4 proven adapters | ✅ Platform wizard |
| **Auth: SSO/SAML/OIDC/MFA** | ❌ Not supported | ✅ Browser recording + ZEST |
| **Protocol: REST API** | ✅ Primary focus | ✅ Supported |
| **Protocol: GraphQL** | ❌ Not supported | ✅ Supported |
| **Trusted/untrusted CI split** | ✅ Genuine privilege isolation | ⚠️ Platform-managed |
| **Container hardening** | ✅ cap-drop, read-only, no-new-privileges | ⚠️ Varies |
| **Delta PR scanning** | ✅ Route-aware git-diff scoping | ⚠️ Incremental varies |
| **Baseline comparison** | ✅ Diff-aware new/persisting/resolved | ✅ Platform-managed |
| **Remediation guidance** | ✅ Structured priority ordering | ✅ Platform-managed |
| **API inventory** | ✅ Observed/unobserved/hinted routes | ✅ API Security integration |
| **PR bot comments** | ✅ Policy-driven | ✅ Platform-managed |
| **Detection depth** | ZAP standard + tuned rules | Proprietary + ZAP-level + custom |
| **Governance/compliance** | ❌ Not supported | ✅ RBAC, permissions, audit trail |
| **Shadow API discovery** | ❌ Not supported | ✅ API Security product |
| **Vendor lock-in** | **None** — fully inspectable | Yes — proprietary |
| **Support** | Community (GitHub Issues) | Commercial SLAs |

### Where Checkmarx Wins (Honestly)

- **Auth breadth**: SSO/SAML/OIDC/MFA/browser recording — outside ZeroDAST's niche by design
- **Detection depth**: Proprietary rules may catch vulnerability classes ZAP misses — real gap
- **Platform features**: Full governance/compliance/RBAC/ASPM — no contest
- **Shadow API discovery**: Production traffic analysis — different product category
- **Support**: SLAs and dedicated teams vs community-only

### Where ZeroDAST Wins

- **Cost**: $0 vs $180k+/year — for OSS and small teams, this is the difference between having DAST and not having it
- **CI speed**: 3-minute PR scans vs 15-60 min — ZeroDAST is architecturally faster through delta detection, not just lower budgets
- **Transparency**: Every script, config, and decision is inspectable shell + JS + YAML, not a proprietary black box
- **Trust architecture**: Genuine privilege isolation with `workflow_run`, `--internal` networking, and hardened containers
- **No lock-in**: Standard ZAP config, standard GitHub Actions YAML, standard JSON baselines

### Who Should Use What

**Use ZeroDAST if:** You're an OSS maintainer or small team with a REST API, token-based auth, and no enterprise security budget. You want 3-minute PR scans and full transparency.

**Use Checkmarx if:** You need SSO/SAML/MFA auth, GraphQL scanning, enterprise governance, or commercial SLAs. You have the budget and the scale.

**Use both if:** You want fast CI-first feedback on PRs (ZeroDAST: 3 min) plus deep periodic enterprise scans (Checkmarx: proprietary rules).

---

## What ZeroDAST Doesn't Do (Honest Limitations)

- ❌ **Enterprise auth** — SSO / SAML / OIDC / MFA / browser-recorded login flows
- ❌ **Non-REST protocols** — GraphQL, SOAP, gRPC
- ❌ **Shadow API discovery** — No production traffic analysis
- ❌ **Platform features** — No governance / compliance / RBAC control plane
- ❌ **Commercial support** — Community-only, no SLA
- ❌ **Alpha stage** — Proven on 7 targets, but still early

ZeroDAST is purpose-built for a specific niche: **CI-first DAST on documented REST APIs with token-bootstrap-friendly auth.** Within that niche, it delivers enterprise-grade results at zero cost. Outside that niche, use something else.

---

## Key Numbers

| Metric | Value |
|---|---|
| PR scan time | **~3 min** |
| Nightly scan time | **~5 min** |
| Total cost | **$0** |
| External targets proven | **7** |
| Language stacks | **3** (Java, Python, Node.js) |
| Auth styles proven | **4** |
| More findings vs vanilla ZAP | **52%** |
| API URIs vs vanilla | **48 vs 0** |
| Combined stars (proven targets) | **100k+** |
| Vendor lock-in | **0** |

Every claim is backed by a green CI run:
- [NocoDB proof](https://github.com/AlphaSudo/nocodb/tree/zerodast-install) • [Strapi proof](https://github.com/AlphaSudo/strapi/tree/zerodast-install) • [Directus proof](https://github.com/AlphaSudo/directus/tree/zerodast-install) • [Medusa proof](https://github.com/AlphaSudo/medusa/tree/zerodast-install)
- [Petclinic T4 scan](https://github.com/AlphaSudo/zerodast/actions/workflows/petclinic-t4-scan.yml) • [FastAPI T4 scan](https://github.com/AlphaSudo/zerodast/actions/workflows/fullstack-fastapi-t4-scan.yml) • [Nightly](https://github.com/AlphaSudo/zerodast/actions/workflows/dast-nightly.yml)

---

## Try It Now

```bash
git clone https://github.com/AlphaSudo/zerodast.git
cd zerodast
cd demo-app && npm install && cd ..
chmod +x scripts/run-dast-local.sh
./scripts/run-dast-local.sh
```

⭐ **[Star ZeroDAST on GitHub](https://github.com/AlphaSudo/zerodast)** — it helps other developers find it.

🐛 **Try it on your repo** — if your API uses token-based auth and has an OpenAPI spec, ZeroDAST can scan it. **[Install guide](https://github.com/AlphaSudo/zerodast/blob/main/docs/MODEL1_INSTALL_GUIDE.md)**

📊 **[Read the full benchmark data](https://github.com/AlphaSudo/zerodast/blob/main/docs/NEAR_LOSSLESS_COMPARISON.md)** — 800+ lines of structured evidence.

💬 **[Open an issue](https://github.com/AlphaSudo/zerodast/issues)** — questions, bugs, and targets that break the adapter model are all welcome.

---

> **SEO note for self-publishing:** Publish this article on your own blog/GitHub Pages **first**. Wait 1-3 days for Google to index it. Then repost to Dev.to using the **canonical URL** feature (set it in the front matter above). This way your site gets the SEO credit, not Dev.to.

---

*All benchmark data measured on GitHub-hosted Ubuntu runners with ZAP 2.17.0. Vanilla baselines are executable at [`benchmarks/vanilla-baseline/`](https://github.com/AlphaSudo/zerodast/tree/main/benchmarks/vanilla-baseline). Checkmarx data sourced from [official public documentation](https://docs.checkmarx.com/en/34965-433898-checkmarx-dast.html) and [public pricing](https://checkmarx.com/pricing). ZeroDAST is Apache 2.0 licensed.*

*Built with discipline. Proven with evidence. Licensed for freedom.*
