# ZeroDAST Benchmark Comparison

## Scope

This document compares the initial external benchmark results for:
- [spring-petclinic/spring-petclinic-rest](https://github.com/spring-petclinic/spring-petclinic-rest) at `155f89a08828386493c27b5584cd2a93d0dcfc39`
- [AlphaSudo/EventDebug](https://github.com/AlphaSudo/EventDebug) at `090e249dbbb6d63f8a6d28e8c9bfe3e105b7def6`

It is intentionally conservative.
The purpose is to explain what ZeroDAST demonstrably improved, what it did not improve, and what kind of `T4` work is justified next.

## Executive Summary

The two-repo benchmark shows that ZeroDAST already provides real value beyond the self-validating demo, but the value is not identical across targets.

- On Petclinic, `T3` improved actual API reach over `T1/T2`.
- On EventDebug, `T3` improved execution quality, containment, and cold-run time, but did not improve API-side alert reach.
- Across both repos, the strongest consistent value today is:
  - cleaner adaptation mechanics
  - contained benchmark machinery
  - more reproducible execution
  - stronger runtime isolation
- The strongest inconsistent value today is:
  - measurable API finding lift on arbitrary real repos

So the current evidence supports a disciplined claim:

> ZeroDAST can improve the practicality and operational quality of DAST on real open-source repositories, and on some targets it also improves effective API reach. It does not yet justify a broad claim of consistent finding lift across arbitrary stacks.

## Side-by-Side Summary

| Dimension | Petclinic | EventDebug |
| --- | --- | --- |
| Stack shape | Spring Boot REST backend | Java multi-module app with UI, Javalin API, Postgres, Kafka |
| Auth in benchmark | Disabled / not needed | Disabled intentionally for first pass |
| T1 result | Operational success, API-shallow | Operational success, API-shallow |
| T2 result | Better packaging, still shallow | Better packaging, still shallow |
| T3 result | Modest API reach improvement | Strong execution/isolation improvement, no API reach improvement |
| Best demonstrated value | Reach + packaging | Isolation + reproducibility + runtime efficiency |
| Main friction | ZAP/OpenAPI 3.1 compatibility | ZAP/OpenAPI compatibility plus runtime complexity |
| Overall verdict | Stronger value-demonstration repo | Stronger stress-test repo |

## Tier-by-Tier Interpretation

## T1

### What T1 was meant to prove
- Can the target be scanned at all with minimal adaptation?
- How much value does a plain scanner baseline provide?

### What happened
- Both repos were scannable.
- Both repos exposed OpenAPI compatibility friction with cached ZAP `2.16.0`.
- Both repos produced reports.
- Neither repo produced a compelling API-focused result from the plain baseline.

### Conclusion
`T1` is useful as a reality check, not as a satisfying end state.
That is exactly what we want a benchmark baseline to do.

## T2

### What T2 was meant to prove
- Does lightweight scripting and artifact discipline materially improve the benchmark story without full ZeroDAST isolation?

### What happened
- On both repos, `T2` improved packaging and repeatability.
- On both repos, `T2` did not materially improve finding reach.
- On EventDebug, `T2` was actually slower than `T1`, which is an important warning against equating “more scripting” with “better outcome.”

### Conclusion
`T2` is operationally useful, but by itself it is not the main product differentiator.

## T3

### What T3 was meant to prove
- Does a ZeroDAST-style isolated adaptation improve the benchmark meaningfully?

### What happened on Petclinic
- `T3` added isolated runtime orchestration and request seeding.
- API alert URI count improved from `0` to `1`.
- This is modest but real reach improvement.

### What happened on EventDebug
- `T3` moved the benchmark to a disposable internal Postgres/Kafka/app network.
- Runtime became cleaner and dramatically faster than the compose-backed baseline.
- API alert URI count remained `0`.

### Conclusion
`T3` already shows real value, but the form of the value depends on the target:
- Petclinic: measurable reach lift
- EventDebug: measurable execution-quality lift

## What ZeroDAST Helped With

These gains are supported by the benchmark evidence:

- Keeping target repositories clean.
  Benchmark machinery stayed inside [benchmarks](C:/Java%20Developer/DAST/benchmarks) in ZeroDAST, not scattered through the target repos.
- Adapting complex runtime shapes without modifying the user’s real working copy.
  This mattered especially for EventDebug.
- Turning brittle one-off scans into repeatable harnesses with structured outputs.
- Improving containment and trust posture.
  The EventDebug `T3` isolated stack is a good example of this.
- Improving API reach on at least one real external repo.
  Petclinic provides that evidence.

## What ZeroDAST Did Not Yet Prove

These claims are still unsupported by the current benchmark:

- consistent API finding lift across both real repos
- superior detection accuracy across arbitrary stacks
- broad generalization beyond the current repo pair
- that alert-bearing API URIs are the only useful success metric for real-repo DAST value

## Hardest Friction Points Exposed

## 1. Scanner/version coupling
Both repos needed a sanitized OpenAPI compatibility shim because cached ZAP `2.16.0` did not cleanly handle the published specs.

## 2. Real-repo API coverage is harder than self-validating demos
Even with request seeding, EventDebug did not produce API-side alert instances.
That is a meaningful benchmark result, not a failure to report.

## 3. Runtime ergonomics matter a lot for OSS adoption
EventDebug showed that ZeroDAST can still add value even when finding lift is flat, because contained execution and predictable orchestration are themselves part of making DAST viable for open-source maintainers.

## Recommendation: What T4 Should Mean

`T4` should not mean “do more of the same local harnessing on both repos.”
That would create work without improving the evidence much.

The most justified next definition of `T4` is:

> a full CI-backed ZeroDAST demonstration on one selected real repo, using the repo that best demonstrates the product value with acceptable setup cost.

## Which repo should get T4 first?

Recommendation: **Petclinic first**.

Why:
- It is the clearer value-demonstration repo.
- It already shows a positive `T1 -> T2 -> T3` gradient in API reach.
- It is easier to explain publicly.
- It gives us the best chance of a clean first CI-backed demonstration.

What EventDebug should remain:
- the stronger stress-test repo
- the repo that keeps us honest about where ZeroDAST still needs better metrics, better scanning, or newer scanner versions

## Public Narrative We Can Support Now

We can now say:
- ZeroDAST has been benchmarked on two real public repositories beyond its self-validating demo.
- The benchmark shows a real `T1/T2/T3` improvement gradient, but the improvement is target-dependent.
- ZeroDAST already improves practical adoption qualities like isolation, repeatability, and low-noise adaptation.
- On at least one real repo, ZeroDAST also improves effective API reach over lighter tiers.

We should not yet say:
- ZeroDAST consistently improves detection depth on any arbitrary open-source repo.
- ZeroDAST has broad benchmark evidence across ecosystems.
- ZeroDAST outperforms enterprise DAST tools generally.

## Next Step

The next highest-value step is:

1. choose Petclinic as the first `T4` target
2. define `T4` as the first full CI-backed ZeroDAST demonstration on a real repo
3. keep EventDebug as the stress-test benchmark and use it to refine metrics and scanner strategy later
