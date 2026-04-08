# ZeroDAST Alpha Release Notes

## Release Position

ZeroDAST is now in a credible alpha state.

That means:

- the core architecture works
- the benchmark evidence is real
- the project can be evaluated seriously
- but the repo is still early enough that adoption should be deliberate and evidence-driven

## What Is Proven

### 1. Self-validating demo pipeline

The repository contains a deliberately vulnerable demo target and a working two-lane GitHub Actions DAST setup.

Proven outcomes:

- local DAST execution works
- nightly GitHub execution works
- intended canaries are detected on the demo target
- trusted/untrusted workflow separation is implemented and exercised

### 2. External benchmark evidence

ZeroDAST was benchmarked beyond the demo target.

Proven outcomes:

- two external public repos were evaluated through benchmark tiers
- Petclinic is the stronger finding-lift/value-demonstration target
- EventDebug is the stronger hard-target operational benchmark
- ZeroDAST value is currently target-dependent, not universal

### 3. Full external CI-backed proof

Petclinic `T4` is the first full external CI-backed ZeroDAST demonstration.

Proven outcomes:

- ZeroDAST can clone, build, run, scan, and report on a real external repo from within the ZeroDAST repo
- the trusted scan-lane architecture works outside the self-validating demo
- the Petclinic benchmark signal survives that transition cleanly

### 4. Early Model 1 adoption proof

Model 1 is no longer just a design sketch.

Proven outcomes:

- the in-repo prototype installs cleanly into two zones only:
  - `.github/workflows/`
  - `zerodast/`
- the prototype uninstalls cleanly
- Petclinic can run real in-repo scans under Model 1
- the kit now supports both:
  - artifact-style targets
  - compose-style targets

## What Is Not Yet Proven

These claims would be too strong today:

- universal stack coverage
- superior detection accuracy across arbitrary repos
- production readiness for all organizations
- consistent finding lift on hard multi-service targets

## Current Best Public Message

The strongest honest public framing right now is:

> ZeroDAST is an alpha-stage, zero-cost DAST orchestration project for public GitHub repositories. It already proves a trusted two-lane DAST architecture, a self-validating demo target, a full external CI-backed benchmark on Petclinic, and an early low-noise in-repo adoption path. Its current strengths are isolation, repeatability, low-mess adaptation, and target-aware benchmarking. Its limitations are still strongest on harder targets where route exercise is measurable but alert-bearing API signal remains weak.

## Recommended Audience Right Now

ZeroDAST is ready to show to:

- security-minded OSS maintainers
- AppSec engineers evaluating low-cost DAST orchestration patterns
- developers interested in trust boundaries for CI security tooling
- maintainers who want benchmark evidence, not just tool claims

ZeroDAST is not yet ready to market as:

- a broad enterprise replacement
- a finished platform
- a universal plug-and-play DAST solution for any repo

## Recommended Next Public Steps

1. Keep the repo public-facing messaging disciplined and alpha-explicit.
2. Use Petclinic as the main demonstration repo.
3. Keep EventDebug as the hard-target benchmark that keeps the claims honest.
4. Treat Model 1 as an adoption prototype with real evidence, not as a finished installer product.
5. Expand breadth only after the current story is easy to understand.
