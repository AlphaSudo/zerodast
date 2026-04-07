# Model 1 Transplant Rehearsal

## Purpose

This note records the first controlled install/remove rehearsal for the model 1 in-repo prototype.

The goal started as install-shape proof, then expanded to a second question:

> Can the same clean in-repo prototype also execute a real scan end to end on a controlled target repo?

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

## Real Scan Result

After the runner was upgraded from install-shape proof to real scan behavior, the same controlled target copy completed a real in-repo scan run.

Observed result from `zerodast/reports/`:

- `specMode`: `raw`
- `zapImage`: `zaproxy/zap-stable:2.17.0`
- `zapExitCode`: `0`
- `coldRunSeconds`: `453`
- `seededRequestCount`: `15`
- `API alert URI count`: `1`

Observed API-side alert URI:

- `http://zerodast-target:9966/petclinic/api/owners/1/pets`

This means the model 1 prototype now proves both:

- clean install and clean removal
- real in-repo scan execution with preserved API-side signal on the controlled Petclinic target

## Engineering Lessons From The Rehearsal

The rehearsal exposed several adoption-relevant implementation details:

- target working directories must resolve from the target repo root, not from inside `zerodast/`
- Maven build artifacts need pattern-based lookup because versioned jar names are normal
- Git Bash + Windows + `podman.exe` requires explicit path-conversion handling for bind mounts

These are exactly the kinds of issues a model 1 prototype must absorb before it is ready for broader adoption.

## What This Proves

This rehearsal supports the model 1 claim that:

- ZeroDAST can be transplanted into a target repo without scattering files
- the install shape is explainable in one short paragraph
- removal is obvious and scriptable
- the prototype can execute a real in-repo scan on a controlled target repo
- API-side signal can survive the model 2 to model 1 transition

It does **not** yet prove:

- adoption readiness for arbitrary repositories
- broad target-agnostic config portability
- acceptable default runtime ergonomics for all maintainer workflows

## Recommendation

The next model 1 step should be:

1. keep the same two-zone install rule
2. tune PR-mode runtime and scan breadth so the in-repo experience is less heavy
3. repeat the transplant rehearsal after runtime tuning
4. only then consider transplanting model 1 into a less controlled target
