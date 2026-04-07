# ZeroDAST Model Transition

## Purpose

This document explains how ZeroDAST should evolve from the current **external orchestrator model** to the eventual **in-repo adoption model**.

The goal is to make that transition deliberate.
We do not want to jump into target-repo installation too early, and we also do not want to stay forever in a benchmark-only external mode if the product goal is real open-source adoption.

## The Two Models

## Model 2: External Orchestrator

This is the model ZeroDAST is using today for external benchmark targets.

Shape:
- ZeroDAST lives in its own repository.
- ZeroDAST clones a target repository at a specific SHA.
- ZeroDAST builds, runs, and scans that target from outside.
- The target repository remains mostly untouched.

What it is good for:
- benchmarking
- controlled comparison
- low-noise experimentation
- proving the architecture before asking maintainers to modify their repos
- preserving clean trust boundaries while we are still learning

What it does **not** prove by itself:
- that maintainers will adopt the system inside their own repos
- that the installation footprint is small enough for routine OSS use
- that the GitHub workflow experience is pleasant when owned directly by the target project

## Model 1: In-Repo Adoption

This is the model we should eventually reach for real adoption.

Shape:
- the target repository contains the ZeroDAST workflows and support files
- the target repository runs its own scan pipeline
- artifacts, comments, and findings belong directly to that repository

What it is good for:
- real maintainer adoption
- native repository ownership of security workflows
- direct PR and main-branch feedback inside the target project

What it is bad for if done too early:
- repo mess
- overfitting the integration to one target
- pushing immature workflow machinery into maintainers' repositories
- obscuring whether the real problem is scanner behavior or installation complexity

## Current Position

Right now, ZeroDAST is in the correct stage:
- model 2 is proven on benchmark targets
- Petclinic now has a full CI-backed external ZeroDAST demonstration
- EventDebug serves as a stress-test benchmark under the same external-orchestrator philosophy

This means we have now proven:
- ZeroDAST can operate beyond the self-validating demo
- ZeroDAST can coordinate a real target repository from outside
- ZeroDAST can preserve meaningful scan signal in a full CI-backed external demonstration

What is still not proven:
- that ZeroDAST can be installed inside a target repository with low enough friction for maintainers to accept it

## Why Model 2 Came First

We deliberately started with the external orchestrator model because it aligns with the current product risks.

At this stage, the biggest risks were:
- scanner/runtime uncertainty
- trust-boundary design uncertainty
- workflow semantics uncertainty
- adaptation noise across different target repos

Model 2 let us answer those questions while keeping the target repos clean.
That was the correct tradeoff.

## When We Should Move Toward Model 1

We should move toward model 1 once all of the following are true:
- the core architecture is no longer changing every few hours
- we have at least one clean external CI-backed demonstration we trust
- we can define a minimal install footprint
- we know which files truly need to live inside the target repo
- we can explain the security semantics clearly to a maintainer

That threshold is now becoming realistic because Petclinic T4 is working cleanly.

## What Model 1 Should Look Like

The in-repo model should **not** mean “copy the entire ZeroDAST repo into the target repo.”

It should mean:
- one clear ZeroDAST-owned root folder inside the target repo
- only the minimum GitHub workflow files at `.github/workflows`
- a reversible installation shape
- minimal surprises for maintainers

A good target shape would look like:
- `.github/workflows/...`
- `zerodast/` or another single agreed root folder
- minimal config file surface

The principle is:

> maintainers should be able to add ZeroDAST, understand it, and remove it without repository chaos.

## What Must Stay the Same Across Both Models

These principles should survive the transition from model 2 to model 1:
- explicit trust boundaries
- contained runtime orchestration
- artifact-backed reporting
- target-aware route and runtime handling
- understandable workflow semantics
- low repository noise

The model may change.
The security and maintainability principles should not.

## Recommended Transition Path

## Stage 1: External Proof
- already achieved
- benchmark and external orchestration prove the architecture

## Stage 2: Minimal In-Repo Prototype
- choose one cooperative target or a controlled transplant repo
- install the smallest viable ZeroDAST footprint inside that repo
- measure installation noise and maintainer ergonomics

## Stage 3: In-Repo Benchmark Variant
- run the same target with the in-repo model
- compare model 1 vs model 2 on:
  - file footprint
  - workflow complexity
  - runtime stability
  - maintainer clarity

## Stage 4: Adoption Guidance
- produce a canonical “install ZeroDAST in your repo” guide
- define what is mandatory vs optional
- document removal/reversibility

## Recommendation

The next product-level message should be:

- **Model 2 proves ZeroDAST works.**
- **Model 1 will prove ZeroDAST can be adopted.**

That is the cleanest honest framing of where the project stands now.
