# Tier Comparison

## Overview
ZeroDAST is positioned as a T3 approach: stronger than basic scanner CI, still lighter than a fully custom platform.
All score framing here is self-benchmarked, not certified.

| Tier | Summary | Scan Time | Security Posture | Complexity | Cost |
| --- | --- | --- | --- | --- | --- |
| T1 | Basic scanner in CI | Fast | Low isolation | Low | Zero |
| T2 | Scanner plus modest gating | Medium | Moderate | Medium | Zero/Low |
| T3 | ZeroDAST | 5-9 min delta target, 15-30 min full | Strong privilege/network separation for CI DAST | Medium/High | Zero |
| T4 | Custom hardened platform | Higher build time | Strongest customization and controls | High | Higher engineering cost |

## Why T3
- Trusted/untrusted workflow separation
- artifact handoff instead of direct trust reuse
- overlay validation
- isolated Docker network for scan execution
- post-scan canary verification and authz scripting

## When to move to T4
- You need org-wide multi-app tenancy and centralized orchestration.
- You need stronger secret/session brokers or custom sandboxing.
- You need broader protocol/application coverage than documented REST APIs.
- You can justify the operational cost of a dedicated platform.
