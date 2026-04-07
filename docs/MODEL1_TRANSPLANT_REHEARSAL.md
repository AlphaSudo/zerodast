# Model 1 Transplant Rehearsal

## Purpose

This note records the first controlled install/remove rehearsal for the model 1 in-repo prototype.

The goal was not to prove scanning depth yet.
The goal was to prove that the prototype install shape is:

- concentrated
- understandable
- reversible

## Target

- Source template: `prototypes/model1-template/`
- Controlled target copy: `C:\Java Developer\petclinic-model1-prototype`
- Target base repo: the local Petclinic benchmark copy

## What Was Installed

The installer added exactly the planned two zones:

1. `.github/workflows/zerodast-pr.yml`
2. `.github/workflows/zerodast-nightly.yml`
3. `zerodast/`

Inside `zerodast/`, the installed footprint remained:

- `README.md`
- `config.json`
- `run-scan.sh`
- `prepare-openapi.js`
- `verify-report.js`
- `templates/automation.yaml`
- `reports/.gitignore`

## What The Target Repo Already Had

The controlled Petclinic copy already contained local benchmark leftovers:

- `petclinic-t1-automation.yaml`
- `t1-reports/`

These were pre-existing and unrelated to the model 1 install.

This matters because raw `git status` in a target repo may contain local noise that should not be misattributed to ZeroDAST.

## Install Result

The install rehearsal was successful:

- the installer required only the target repo root
- the workflow files landed in the expected directory
- the ZeroDAST-owned payload stayed fully contained under `zerodast/`
- no extra repo directories were touched

## Removal Result

The uninstall rehearsal was also successful:

- `.github/workflows/zerodast-pr.yml` removed
- `.github/workflows/zerodast-nightly.yml` removed
- `zerodast/` removed

After uninstall, the target repo returned to showing only its pre-existing local benchmark noise:

- `petclinic-t1-automation.yaml`
- `t1-reports/`

That is the key reversibility proof for the first model 1 prototype.

## What This Proves

This rehearsal supports the model 1 claim that:

- ZeroDAST can be transplanted into a target repo without scattering files
- the install shape is explainable in one short paragraph
- removal is obvious and scriptable

It does **not** yet prove:

- full in-repo scanning sophistication
- target-agnostic config portability
- adoption readiness for arbitrary repositories

## Recommendation

The next model 1 step should be:

1. keep the same two-zone install rule
2. upgrade the prototype runner from install-shape proof to real scan behavior
3. repeat the transplant rehearsal after the runner grows more capable

The install footprint should stay small even as the runner becomes more useful.
