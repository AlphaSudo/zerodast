# ZeroDAST

Alpha-stage, zero-cost DAST orchestration for public GitHub repositories, optimized for small and medium documented REST APIs.

ZeroDAST is a working security engineering project, not a finished platform. It is strongest today as:

- a self-validating DAST reference implementation
- an external-orchestrator benchmark runner for public repos
- an early in-repo adoption kit for low-noise Model 1 installs

It is not certified, not claiming universal coverage, and not yet claiming broad production readiness across arbitrary stacks.

## Architecture

```text
LANE 1: Untrusted PR CI
  pull_request -> lint -> tests -> semgrep -> gitleaks -> build image -> upload artifacts

LANE 2: Trusted DAST
  workflow_run(CI success) -> download artifacts -> validate overlay -> isolated scan runtime -> PR report

Nightly / Mainline DAST
  push main or schedule -> build image -> full isolated scan -> report artifact -> issue on threshold breach

External-Repo Demonstration (T4)
  trigger/metadata lane -> trusted scan lane -> clone target SHA -> build target -> isolated runtime -> upload benchmark artifacts

Model 1 Prototype
  install thin workflows + zerodast/ into target repo -> run in-repo scan with target-specific config
```

## What ZeroDAST Does

- Builds a demo scan target with intentional SQLi, XSS, IDOR, and application-error-disclosure surfaces.
- Uses a trusted second-stage workflow to run DAST against an artifactized image rather than directly trusting PR execution.
- Isolates app, DB, and ZAP inside Docker `--internal` networking.
- Uses additive SQL overlay validation to reduce poisoned-seed risk.
- Supports delta-scoped PR scanning and full nightly scanning.
- Can benchmark and orchestrate DAST against external public repositories from within the ZeroDAST repo itself.
- Includes an alpha Model 1 adoption kit for in-repo installs with a contained two-zone footprint.

## Quick Start

1. Install Docker, Node.js 22+, Python 3.11+, and Git Bash on Windows.
2. Use `demo-app/` as the local scan target and install dependencies with `npm install` if you need local lint/test execution.
3. Review [QUICK_START.md](C:/Java%20Developer/DAST/docs/QUICK_START.md) for the local demo path.
4. Review [.github/workflows/ci.yml](C:/Java%20Developer/DAST/.github/workflows/ci.yml), [.github/workflows/dast-pr.yml](C:/Java%20Developer/DAST/.github/workflows/dast-pr.yml), and [.github/workflows/dast-nightly.yml](C:/Java%20Developer/DAST/.github/workflows/dast-nightly.yml) to understand the two-lane pipeline.
5. Review [MODEL1_INSTALL_GUIDE.md](C:/Java%20Developer/DAST/docs/MODEL1_INSTALL_GUIDE.md) if you want to evaluate the in-repo prototype.
6. Use the prompts under `ai-prompts/` to adapt the pattern to another repository.

## Benchmarking

- Benchmark protocol: [BENCHMARK_PROTOCOL.md](C:/Java%20Developer/DAST/docs/BENCHMARK_PROTOCOL.md)
- Results template: [BENCHMARK_RESULTS_TEMPLATE.md](C:/Java%20Developer/DAST/docs/BENCHMARK_RESULTS_TEMPLATE.md)
- Roadmap: [BENCHMARK_ROADMAP.md](C:/Java%20Developer/DAST/docs/BENCHMARK_ROADMAP.md)
- Comparison: [BENCHMARK_COMPARISON.md](C:/Java%20Developer/DAST/docs/BENCHMARK_COMPARISON.md)
- EventDebug investigation: [EVENTDEBUG_INVESTIGATION_PLAN.md](C:/Java%20Developer/DAST/docs/EVENTDEBUG_INVESTIGATION_PLAN.md)

## Model 1

- Transition rationale: [MODEL_TRANSITION.md](C:/Java%20Developer/DAST/docs/MODEL_TRANSITION.md)
- Prototype design: [MODEL1_PROTOTYPE_DESIGN.md](C:/Java%20Developer/DAST/docs/MODEL1_PROTOTYPE_DESIGN.md)
- Install guide: [MODEL1_INSTALL_GUIDE.md](C:/Java%20Developer/DAST/docs/MODEL1_INSTALL_GUIDE.md)
- Adoption kit: [MODEL1_ADOPTION_KIT.md](C:/Java%20Developer/DAST/docs/MODEL1_ADOPTION_KIT.md)
- Rehearsal results: [MODEL1_TRANSPLANT_REHEARSAL.md](C:/Java%20Developer/DAST/docs/MODEL1_TRANSPLANT_REHEARSAL.md)

## Comparison
| Tier | Description | Speed | Security Posture | Cost |
| --- | --- | --- | --- | --- |
| T1 | Basic scanner only | Fast | Weak isolation | Zero |
| T2 | Scanner + light CI gating | Medium | Better, still broad trust | Zero/Low |
| T3 | ZeroDAST-style isolated local adaptation | Medium | Strong local isolation and contained artifacts | Zero |
| T4 | Full CI-backed ZeroDAST on a real external repo | Slower than local tiers, stronger proof | Trusted split plus isolated runtime with target-aware orchestration | Zero direct tooling cost, higher engineering effort |

## Warning
The demo app is intentionally vulnerable. Never deploy it to production or expose it to the public internet as-is.

## Status
- License: Apache-2.0
- Release posture: alpha
- Current state:
  - self-validating demo validated locally and on GitHub Actions
  - two external benchmark repos completed through T1-T3
  - first full CI-backed external ZeroDAST demonstration completed on Petclinic T4
  - Petclinic T4 clean rerun succeeded with `zapExitCode: 0` while preserving the API-side benchmark signal
  - Model 1 prototype proved clean install/removal, real Petclinic in-repo execution, and a two-runtime-class adoption kit
  - EventDebug now has a route-exercise success contract for hard-target operational benchmarking, but still does not show alert-bearing API lift
  - current evidence supports target-dependent value claims, not universal coverage claims

## Alpha Notes

For a concise public-facing summary of what is proven and what is still alpha, see [ALPHA_RELEASE_NOTES.md](C:/Java%20Developer/DAST/docs/ALPHA_RELEASE_NOTES.md).
