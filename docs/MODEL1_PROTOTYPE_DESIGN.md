# Model 1 Prototype Design

## Purpose

This document defines the **first minimal in-repo ZeroDAST prototype**.

Its job is not to maximize features.
Its job is to answer a narrower, more important question:

> Can ZeroDAST be installed inside a target repository with low enough friction, low enough mess, and clear enough semantics that a maintainer could realistically adopt it?

This is the next proof after the external orchestrator benchmark model.

## Design Goal

The prototype should feel:
- small
- reversible
- understandable
- security-conscious
- repo-local without being repo-invasive

It should **not** feel like importing an entire platform into the target repository.

## What This Prototype Is Trying to Prove

The model 1 prototype should prove all of the following:
- the in-repo install footprint can stay small
- the trust boundary can still be explained clearly inside the target repo
- the maintainer can understand where ZeroDAST starts and stops
- the workflow remains useful without spraying files everywhere
- ZeroDAST can be removed cleanly if the maintainer changes their mind
- the repo-local runner can execute a real scan on a controlled target

## Non-Goals

This prototype is **not** trying to prove:
- maximum feature completeness
- broad multi-target configurability
- enterprise policy depth
- every optional subsystem from the demo repo
- fully generalized auth/bootstrap handling for every stack

Those can come later.
The prototype should optimize for adoption clarity, not feature count.

## Proposed Install Footprint

The prototype should use exactly two installation zones:

1. `.github/workflows/`
2. `zerodast/`

Nothing else should be required unless GitHub or the target build system forces it.

## Directory Layout

Recommended shape inside the target repo:

```text
.github/
  workflows/
    zerodast-pr.yml
    zerodast-nightly.yml
    zerodast-trigger.yml   (optional if split flow is used)

zerodast/
  README.md
  config.json
  run-scan.sh
  prepare-openapi.js
  verify-report.js
  templates/
    automation.yaml
  reports/                (gitignored / runtime only)
```

## File Ownership Rules

## `.github/workflows/*`
These files should only do orchestration:
- checkout
- setup runtime
- call the repo-local ZeroDAST scripts
- upload artifacts
- report summary

They should **not** contain lots of target-specific scan logic inline.
That logic belongs in `zerodast/`.

## `zerodast/*`
This should be the single ZeroDAST-owned root folder.
It should contain:
- repo-local scan helpers
- target configuration
- templates
- docs for maintainers

If a maintainer asks "what did ZeroDAST add?", the answer should mostly be:
- `.github/workflows/...`
- `zerodast/...`

That is the whole point of the prototype.

## Mandatory Files

These should exist in the first prototype:

- `.github/workflows/zerodast-pr.yml`
- `.github/workflows/zerodast-nightly.yml`
- `zerodast/README.md`
- `zerodast/config.json`
- `zerodast/run-scan.sh`
- `zerodast/prepare-openapi.js`
- `zerodast/verify-report.js`
- `zerodast/templates/automation.yaml`
- `zerodast/reports/.gitignore`

## Optional Files

These should remain optional until needed by the target:

- `zerodast/bootstrap-auth.sh`
- `zerodast/post-scan.sh`
- `zerodast/validate-overlay.py`
- `zerodast/request-seeds.json`
- `zerodast/COMMENT_TEMPLATE.md`

The prototype should start with the mandatory set only.

## Minimal Workflow Strategy

The first prototype should prefer **two workflows**, not many.

## Workflow A: PR Scan

Responsibilities:
- trigger on PRs
- run the local ZeroDAST runner in a bounded way
- upload report artifacts
- publish a summary

## Workflow B: Nightly / Mainline Scan

Responsibilities:
- trigger on schedule or mainline events
- run the same local ZeroDAST runner with the full profile
- upload artifacts
- publish a summary

If a third trigger workflow becomes necessary for trust separation, it should be justified explicitly.
The default prototype should not multiply workflows just because the benchmark repo used more.

## Trust Boundary Approach

The prototype must still preserve the security intent from the external model, but with less ceremony.

For the first in-repo prototype, the trust boundary should be defined like this:
- do not execute arbitrary unreviewed configuration from user-controlled inputs
- keep scan logic in committed repo-local scripts
- keep workflow permissions minimal
- avoid shell interpolation of untrusted GitHub context directly in `run:` blocks
- make the security assumptions explicit in `zerodast/README.md`

This is the adoption-friendly version of the same principle.

## Configuration Model

The prototype should centralize target-specific settings in one file:
- `zerodast/config.json`

Expected fields:
- build command and artifact lookup
- base path and OpenAPI path
- scan mode flags
- request seeding values
- report thresholds

The rule is:
- change config first
- only change scripts if the target truly needs new behavior

That keeps the install understandable.

## Reversibility Requirement

The maintainer must be able to remove ZeroDAST by deleting:
- `.github/workflows/zerodast-*.yml`
- `zerodast/`

If removal requires cleanup in five other places, the prototype failed.

## Success Criteria

The first model 1 prototype is successful if:
- the full install footprint is easy to explain in one paragraph
- the file count is low and concentrated
- the workflows call repo-local scripts instead of containing complex inline logic
- the prototype runs end-to-end on a controlled target repo
- the maintainer-facing README in `zerodast/` makes ownership and assumptions clear
- the uninstall path is obvious
- API-side signal survives the in-repo transplant on the controlled target

## Failure Criteria

The first model 1 prototype should be considered poor if:
- files end up scattered across many repo directories
- target-specific logic is duplicated across workflow YAML and scripts
- the maintainer has to understand the whole ZeroDAST benchmark repo to use it
- removal is not obvious
- the install shape feels heavier than the value it provides

## Recommended First Prototype Target

Use a **controlled transplant repo or controlled branch first**, not a random public repo.

Why:
- it reduces coordination overhead
- it lets us refine the install footprint without surprising an external maintainer
- it keeps the experiment reversible while the model is still forming

## Recommended Next Implementation Plan

1. Create a `zerodast/` root folder prototype in a controlled repo.
2. Keep workflows thin and move scan logic into repo-local scripts.
3. Put all target-specific settings in `zerodast/config.json`.
4. Measure the install footprint:
   - number of files added
   - number of directories touched
   - whether removal is obvious
5. Run the first in-repo proof.
6. Tune runtime and portability rough edges.
7. Write the maintainer installation/removal guide only after the prototype feels clean.

## Recommendation

The first model 1 prototype should still be judged primarily on **install ergonomics**, but it should now also preserve a minimal real scan result on the controlled target.

If it is not clean to install, or if it loses the API-side signal entirely, it is not ready to claim adoption-friendliness.
