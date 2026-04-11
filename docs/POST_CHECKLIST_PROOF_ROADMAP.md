# ZeroDAST Post-Checklist Proof Roadmap

This roadmap starts **after** [CHECKMARX_PARITY_CHECKLIST.md](C:/Java%20Developer/DAST/docs/CHECKMARX_PARITY_CHECKLIST.md) is implemented.

Its purpose is to take ZeroDAST from:

- "the planned major capability edits are done"

to:

- "ZeroDAST is proven and ready to be described as enterprise-like CI DAST for OSS/public-repo-friendly web/API targets, with much lower adoption friction"

This is a **proof and hardening roadmap**, not another large feature roadmap.

It assumes the checklist phases were completed honestly and are already reflected in:

- [CURRENT_CAPABILITIES.md](C:/Java%20Developer/DAST/docs/CURRENT_CAPABILITIES.md)
- [CHECKMARX_CURRENT_CAPABILITIES.md](C:/Java%20Developer/DAST/docs/CHECKMARX_CURRENT_CAPABILITIES.md)
- [CHECKMARX_PARITY_ROADMAP.md](C:/Java%20Developer/DAST/docs/CHECKMARX_PARITY_ROADMAP.md)

---

## Core Principle

At this point, the main job is no longer "add more features."

The main job becomes:

- prove the implemented capability is real
- prove the timing goals hold under repetition
- prove the claims stay truthful across more than one or two friendly targets
- correct the last gaps exposed by testing

---

## Stage 0: Checklist Completion Gate

Before starting this roadmap, confirm:

- every major item in [CHECKMARX_PARITY_CHECKLIST.md](C:/Java%20Developer/DAST/docs/CHECKMARX_PARITY_CHECKLIST.md) is either complete or consciously deferred
- capability docs are updated to match reality
- timing numbers are measured, not guessed
- at least one internal and one external proof exists for each major new capability

### Exit

- ZeroDAST is feature-complete enough for proof work
- no major hidden implementation gap is still being called "done"

### Current note
The repo is now past the original "major implementation only" state.

In practice:
- Phase 4 is complete for the current REST-first target slice
- Phase 5 has a materially implemented lightweight operator model
- the remaining work is less about core missing capabilities and more about:
  - repeated proof quality
  - benchmark expansion
  - final claim discipline

---

## Stage 1: Stability and Repeatability Proof

Goal:

- show that the system is stable enough to trust, not just impressive in one run

### Work

- run at least 5 PR-profile scans on the demo app
- run at least 5 nightly-profile scans on the demo app
- run at least 3 repeated scans on each benchmark repo that represents a major target class
- record:
  - total duration
  - scan exit behavior
  - auth bootstrap success
  - admin-path verification success where applicable
  - route exercise success
  - alert-bearing signal
  - flake/failure cause

### Evidence

- a small reliability log under `docs/`
- median and worst-case timings, not only best case
- explicit count of flaky vs clean runs

### Exit

- PR median remains under 10 minutes
- nightly median remains under 15 minutes
- no recurring unexplained failure mode remains open
- repeated runs preserve the expected auth/admin coverage behavior

---

## Stage 2: Benchmark Expansion Proof

Goal:

- show that ZeroDAST is not only good on the original benchmark set

### Work

- expand to a broader benchmark matrix
- include at least:
  - one additional Node target
  - one additional Python target
  - one Go or .NET target if feasible
  - at least one session/cookie-auth target
  - at least one role-aware target with explicit admin-only routes
- keep frozen SHAs and benchmark sheets for every repo
- run at least T1/T2/T3/T4 where appropriate
- use T5 only as a benchmark comparator, not as product scope

### Evidence

- benchmark matrix with target class labels
- target-level proof that auth/bootstrap/admin coverage works across more than one stack
- hard-target notes where signal remains weak

### Exit

- ZeroDAST proves cross-stack behavior on enough targets to support the niche claim
- at least one authenticated/admin target outside the demo app is successful
- benchmark docs show both strengths and limitations honestly

---

## Stage 3: Near-Lossless Comparison Proof

Goal:

- show that ZeroDAST is close enough to conventional enterprise-style DAST for the target niche while still easier to adopt

### Work

- define fair comparison baselines for selected targets
- compare ZeroDAST against:
  - light conventional baseline where useful
  - heavier enterprise-style conventional baseline where possible
- compare on:
  - setup burden
  - repo footprint
  - timing
  - auth/admin coverage
  - route exercise
  - alert-bearing signal
  - operator burden

### Evidence

- side-by-side comparison tables per target
- explicit "where ZeroDAST is weaker" notes
- explicit "where ZeroDAST is stronger" notes

### Exit

- the "near-lossless for the target niche" claim is backed by benchmark evidence
- the "easier to set up" claim is backed by install/footprint evidence
- the "faster in CI" claim is backed by measured timing medians

---

## Stage 4: Adoption and Operator Proof

Goal:

- show that maintainers can realistically adopt and operate ZeroDAST

### Work

- run at least 3 clean Model 1 installation rehearsals on real repo copies
- verify install, run, update, and uninstall flows
- validate docs from the perspective of another engineer
- harden default config examples for the most common target classes
- confirm the control-plane/operator model is understandable and not ad hoc

### Evidence

- install timing numbers
- file-footprint counts
- uninstall/reversibility proof
- adoption notes per target class

### Exit

- installation is repeatable and understandable
- repo noise remains low
- operator workflow is clear enough for alpha adoption

---

## Stage 5: Final Correction Pass

Goal:

- fix the last issues exposed by proof work without reopening a huge feature program

### Work

- review all open proof failures
- classify them into:
  - must-fix before claim
  - acceptable limitation
  - future work
- fix only the must-fix class
- re-run the smallest necessary subset of proof after each fix

### Evidence

- explicit defect ledger
- explicit accepted limitations list
- final capability and comparison docs synced to reality

### Exit

- no must-fix gap remains open
- all remaining limitations are documented honestly
- no hidden "we know this is broken but shipped anyway" issue remains

---

## Stage 6: Ready-to-Claim Gate

Goal:

- decide whether ZeroDAST is ready to be described publicly using the intended positioning

### Claim standard

ZeroDAST may be described as:

- **enterprise-like CI DAST for OSS/public-repo-friendly web/API targets**
- **with lower adoption friction**
- **and with faster bounded CI profiles**

only if all of the following are true:

- PR median is under 10 minutes
- nightly median is under 15 minutes
- authenticated coverage is proven
- admin-path coverage is proven
- cross-stack proof exists
- installation/adoption proof exists
- near-lossless comparison evidence exists for the target niche
- public docs still describe limitations truthfully

### Exit

- the positioning claim is approved by evidence, not hope

---

## Recommended Execution Order

1. Finish checklist implementation.
2. Run stability and repeatability proof.
3. Expand benchmark breadth.
4. Perform near-lossless comparison work.
5. Validate adoption/operator experience.
6. Run a final correction pass.
7. Re-assess claim readiness.

---

## What This Roadmap Does Not Assume

This roadmap does **not** assume:

- ZeroDAST will become full Checkmarx parity
- ZeroDAST must support every enterprise auth model before the claim
- ZeroDAST must beat enterprise tools on every target

It assumes a narrower and more honest goal:

- strong enterprise-like CI DAST behavior
- for OSS/public-repo-friendly web/API targets
- with much lower setup and maintenance friction

---

## Final Intended Outcome

If this roadmap is completed successfully, ZeroDAST should be ready to present as:

- a serious open-source CI DAST system
- enterprise-like for its defined target niche
- materially easier to adopt than conventional enterprise setups
- faster enough in CI to be practical
- backed by benchmark and operational evidence rather than only design intent

## Current Reality Check

As of the current repo state, ZeroDAST is already much closer to this outcome than when this proof roadmap was first written.

That is because the repo now has:
- proven authenticated + admin-path coverage
- proven external richer-auth coverage
- proven REST-first API inventory/hint coverage on multiple hard targets
- proven lightweight operator artifacts:
  - environment manifest
  - result state
  - remediation guide
  - operational reliability
  - lightweight fleet summary
- GitHub-proven PR/nightly policy outputs in the newer operator-oriented format

So the remaining burden is now mostly:
- broaden proof where it still matters
- keep claims honest
- avoid overbuilding beyond the current niche before the benchmark/proof story is fully consolidated
