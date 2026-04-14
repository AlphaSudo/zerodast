# ⚡ ZeroDAST v0.1.0-alpha — Release Notes

**Release Date:** April 12, 2026  
**Status:** Alpha  
**License:** Apache 2.0  

---

> **These alpha release notes describe the broader ZeroDAST project direction. As of the V2 ship-readiness pass on April 14, 2026, the new surgical-image path is still experimental and does not yet achieve full Medium+ parity on `demo-core` because ZAP rule `40026` (`Cross Site Scripting (DOM Based)`) is still missing in the surgical run.**

## V2 Ship-Readiness Note

- V2 adds opt-in interfaces for `ZAP_IMAGE`, `SCAN_PROFILE`, `CAPTURE_ZAP_INTERNALS`, and `CAPTURE_MEMORY`.
- Default CI behavior remains unchanged: stock ZAP image and no scan profile unless explicitly enabled.
- Current local demo-core evidence:
  - stock image: `2.23 GB`
  - surgical image: `1.37 GB`
  - surgical installed addon inventory: `45`
  - surgical peak observed memory: `356.3 MiB`
- Current blocker: `scripts/verify-alert-parity.sh demo-core` still fails on missing Medium+ alert type `40026`.
- Detailed commands and measurements are captured in [docs/V2_SHIP_STATUS.md](docs/V2_SHIP_STATUS.md).

---

## 🎯 What is ZeroDAST?

ZeroDAST is an open-source, CI-first **Dynamic Application Security Testing (DAST)** orchestration framework that wraps OWASP ZAP inside a security-hardened, privilege-isolated CI pipeline. It delivers enterprise-grade scanning capabilities — authenticated multi-role scanning, delta-scoped PR analysis, baseline-aware triage, and structured operator artifacts — all at zero licensing cost.

---

## ✨ Highlights

### 🔐 Enterprise-Grade CI Security Architecture
- **Two-lane privilege-isolated CI pipeline** — PR code runs with read-only permissions; DAST runs from trusted `main` via `workflow_run` on a separate runner
- **Artifact handoff isolation** — PR builds a Docker image uploaded as an artifact; DAST downloads it with no direct runtime trust reuse
- **Container hardening** — `cap-drop ALL`, `no-new-privileges`, read-only root filesystem, memory & PID limits
- **Network isolation** — App, DB, and ZAP communicate on a Docker `--internal` network

### 🔑 Auth Adapter Framework (4 Proven Styles)
| Adapter | Auth Style | Proven On |
|---|---|---|
| `json-token-login` | JSON body → Bearer token | Demo app, Petclinic, NocoDB, Directus, Medusa |
| `form-cookie-login` | Form POST → session cookie | Demo app |
| `json-session-login` | JSON body → session header | Django Styleguide |
| `form-urlencoded-token-login` | OAuth2-style form → Bearer token | FastAPI |

- Custom header support (e.g. NocoDB's `xc-auth`)
- Nested token extraction via dot-path notation (`data.token`, `data.access_token`)
- Zero custom scripting required

### 📊 52% More Findings Than Vanilla ZAP
Benchmarked across **4 real-world open-source targets** (combined 100k+ GitHub stars):

| Target | ⭐ Stars | Vanilla ZAP | ZeroDAST | Signal Lift |
|---|---:|---|---|---|
| **NocoDB** | 48k+ | 8M/15L/7I — **0 API** URIs | 11M/15L/8I — **7 API** URIs | +13%, superset |
| **Strapi** | 67k+ | 3M/7L/4I — **0 API** URIs | 8M/10L/8I — **8 API** URIs | +86%, superset |
| **Directus** | 29k+ | 10M/10L/8I — **0 API** URIs | 13M/12L/26I — **30 API** URIs | +82%, superset |
| **Medusa** | 27k+ | 2M/3L/0I — **0 API** URIs | 4M/2L/0I — **3 API** URIs | Superset |
| **Fleet Total** | **100k+** | **77 findings, 0 API URIs** | **117 findings, 48 API URIs** | **+52% findings** |

ZeroDAST is a **strict superset** of vanilla ZAP — it finds everything vanilla finds plus all authenticated API findings.

### ⚡ CI Performance
- **PR scans**: ~3 minutes (delta-scoped)
- **Nightly scans**: ~5 minutes (full API surface)
- Compare: vanilla ZAP took 8m 44s on the demo app alone

### 🛡️ 7 Proven External Targets

| Target | Stack | Auth Style | Runtime |
|---|---|---|---|
| NocoDB (48k⭐) | Node.js | `xc-auth` custom header | 242s |
| Strapi (67k⭐) | Node.js | Bearer JWT (nested) | 171s |
| Directus (29k⭐) | Node.js | Bearer JWT (nested) | 343s |
| Medusa (27k⭐) | Node.js | Bearer JWT | 108s |
| Petclinic | Java/Spring | Public REST | 309s |
| FastAPI Template | Python/FastAPI | OAuth2 Bearer | 225s |
| Django Styleguide | Python/Django | Session header | 92s |

### 📋 Operator Artifacts (Every Scan)
- `zap-report.json` / `.html` — Raw ZAP findings
- `environment-manifest.json` — Scanned environment context
- `result-state.json` — Baseline-adjusted triage state
- `remediation-guide.md` — Prioritized fix guidance (new → persisting → resolved)
- `operational-reliability.json` — Runtime health tracking
- `api-inventory.json` / `.md` — Route coverage inventory

### 📦 Model 1 Installer
- One-command install into any repository via PowerShell
- Adds exactly 2 workflow files + `zerodast/` config directory
- Clean uninstall — removes only what it added

### 🤖 AI-Guided Setup
- 5 prompt templates for AI-assisted adaptation to any target
- INSPECT_REPO → GENERATE_CONFIG → ADAPT_AUTH → ADAPT_SEED → AI_TRIAGE

---

## 📈 Key Numbers at a Glance

| Metric | Value |
|---|---|
| PR scan time | ~3 min |
| Nightly scan time | ~5 min |
| Total cost | $0 |
| External targets proven | 7 |
| Language stacks | 3 (Java, Python, Node.js) |
| Auth styles proven | 4 |
| More findings vs vanilla ZAP | +52% |
| API URIs (ZeroDAST vs vanilla) | 48 vs 0 |
| Model 1 fleet CI-green | 4/4 |
| Combined target GitHub stars | 100k+ |
| Petclinic route coverage | 17/17 |
| Total commits | 183 |

---

## ⚠️ Known Limitations (Alpha)

This is an alpha release. The following are **not** currently supported:

- ❌ Enterprise auth (SSO / SAML / OIDC / MFA / browser-recorded login flows)
- ❌ Non-REST protocols (GraphQL, SOAP, gRPC)
- ❌ Shadow API discovery from production traffic
- ❌ Platform features (governance / compliance / RBAC / ASPM)
- ❌ Commercial support / SLA

---

## 🔗 CI Proof Links

Every claim is backed by a green GitHub Actions run:

| Target | Proof |
|---|---|
| NocoDB Model 1 | [AlphaSudo/nocodb `zerodast-install`](https://github.com/AlphaSudo/nocodb/tree/zerodast-install) |
| Strapi Model 1 | [AlphaSudo/strapi `zerodast-install`](https://github.com/AlphaSudo/strapi/tree/zerodast-install) |
| Directus Model 1 | [AlphaSudo/directus `zerodast-install`](https://github.com/AlphaSudo/directus/tree/zerodast-install) |
| Medusa Model 1 | [AlphaSudo/medusa `zerodast-install`](https://github.com/AlphaSudo/medusa/tree/zerodast-install) |
| Petclinic T4 | [petclinic-t4-scan.yml](https://github.com/AlphaSudo/zerodast/actions/workflows/petclinic-t4-scan.yml) |
| FastAPI T4 | [fullstack-fastapi-t4-scan.yml](https://github.com/AlphaSudo/zerodast/actions/workflows/fullstack-fastapi-t4-scan.yml) |
| Core Demo Nightly | [dast-nightly.yml](https://github.com/AlphaSudo/zerodast/actions/workflows/dast-nightly.yml) |

---

## 🚀 Quick Start

```bash
git clone https://github.com/AlphaSudo/zerodast.git
cd zerodast
cd demo-app && npm install && cd ..
chmod +x scripts/run-dast-local.sh
./scripts/run-dast-local.sh
```

---

## 📚 Documentation

| Document | Description |
|---|---|
| [README.md](README.md) | Project overview and getting started |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Three-layer defense model |
| [NEAR_LOSSLESS_COMPARISON.md](docs/NEAR_LOSSLESS_COMPARISON.md) | Full benchmark comparison |
| [MODEL1_INSTALL_GUIDE.md](docs/MODEL1_INSTALL_GUIDE.md) | Step-by-step installation |
| [CURRENT_CAPABILITIES.md](docs/CURRENT_CAPABILITIES.md) | Complete capability inventory |
| [THREAT_MODEL.md](docs/THREAT_MODEL.md) | Attack vectors and mitigations |

---

<p align="center">
  <sub>Built with discipline. Proven with evidence. Licensed for freedom.</sub>
</p>
