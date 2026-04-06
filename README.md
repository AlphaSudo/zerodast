# ZeroDAST

Professional-grade, zero-cost DAST pipeline for public GitHub repositories, optimized for small and medium documented REST APIs.

Self-benchmarked via AlphaSudo/sbtr-benchmark. Not certified, not claiming universal coverage.

## Architecture

```text
LANE 1: Untrusted PR CI
  pull_request -> lint -> tests -> semgrep -> gitleaks -> build image -> upload artifacts

LANE 2: Trusted DAST
  workflow_run(CI success) -> download artifacts -> validate overlay -> isolated scan runtime -> PR report

Nightly / Mainline DAST
  push main or schedule -> build image -> full isolated scan -> report artifact -> issue on threshold breach
```

## What ZeroDAST Does

- Builds a demo scan target with intentional SQLi, XSS, IDOR, and application-error-disclosure surfaces.
- Uses a trusted second-stage workflow to run DAST against an artifactized image rather than directly trusting PR execution.
- Isolates app, DB, and ZAP inside Docker `--internal` networking.
- Uses additive SQL overlay validation to reduce poisoned-seed risk.
- Supports delta-scoped PR scanning and full nightly scanning.

## Quick Start

1. Install Docker, Node.js 22+, Python 3.11+, and Git Bash on Windows.
2. Use `demo-app/` as the local scan target and install dependencies with `npm install` if you need local lint/test execution.
3. Review `db/seed/schema.sql`, `db/seed/mock_data.sql`, and `db/seed/validate_overlay.py` to understand the seed model.
4. Review `.github/workflows/ci.yml`, `.github/workflows/dast-pr.yml`, and `.github/workflows/dast-nightly.yml` to understand the two-lane pipeline.
5. Use the prompts under `ai-prompts/` to adapt the pattern to another repository.

## Benchmarking

- Benchmark protocol: `docs/BENCHMARK_PROTOCOL.md`
- Results template: `docs/BENCHMARK_RESULTS_TEMPLATE.md`

## Comparison
| Tier | Description | Speed | Security Posture | Cost |
| --- | --- | --- | --- | --- |
| T1 | Basic scanner only | Fast | Weak isolation | Zero |
| T2 | Scanner + light CI gating | Medium | Better, still broad trust | Zero/Low |
| T3 | ZeroDAST | 5-9 min delta target, 15-30 min full | Privilege + network isolation with artifact handoff | Zero |
| T4 | Heavier custom platform | Slower to build, potentially stronger | Highest customization | Higher engineering cost |

## Warning
The demo app is intentionally vulnerable. Never deploy it to production or expose it to the public internet as-is.

## Status
- License: Apache-2.0
- Current state: local and GitHub validation working on the self-validating demo; external two-repo benchmark protocol defined, real-repo benchmark pending

