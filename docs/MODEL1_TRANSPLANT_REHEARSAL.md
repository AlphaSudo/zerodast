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

## PR Runtime Tuning Result

The first working PR-mode profile took about `453s`, which was heavier than we want for maintainer ergonomics.

A first tuning attempt removed the spider entirely and lowered the active scan budget to `5` minutes:

- runtime improved to `119s`
- but API-side signal dropped to `0`

That result showed the spider was not optional for this target.

The next tuning pass restored a minimal spider:

- `enableSpider: true`
- `spiderMinutes: 1`
- `maxDurationMinutes: 5`

That profile produced a better balance:

- runtime: `353s`
- API alert URI count: `1`
- preserved API-side URI:
  - `http://zerodast-target:9966/petclinic/api/owners/1/pets`

This is the current best-known PR-mode tradeoff for the controlled Petclinic transplant.

## Less-Controlled Target Confirmation

After the controlled rehearsal, the same tuned model 1 profile was installed into the real local Petclinic benchmark clone on an isolated branch.

That less-controlled target produced essentially the same result:

- `specMode`: `raw`
- `zapImage`: `zaproxy/zap-stable:2.17.0`
- `zapExitCode`: `0`
- `coldRunSeconds`: `354`
- `seededRequestCount`: `15`
- `API alert URI count`: `1`

Observed API-side alert URI:

- `http://zerodast-target:9966/petclinic/api/owners/1/pets`

This matters because it shows the model 1 baseline did not only work in a throwaway copy. It held up on the real benchmark clone with the same tuned PR profile and nearly identical runtime.

## Harder Target Extension: EventDebug

The next model 1 extension was the harder EventDebug benchmark clone.

That target required a second runtime class, so the model 1 runner was extended with `compose` mode while keeping the existing `artifact` mode for Petclinic-style targets.

Observed result on EventDebug with compose mode:

- first compose-mode pass:
  - `specMode`: `raw`
  - `zapImage`: `zaproxy/zap-stable:2.17.0`
  - `zapExitCode`: `2`
  - `coldRunSeconds`: `118`
  - `seededRequestCount`: `8`
  - `API alert URI count`: `0`
- route-exercise rerun after adding model 1 summary metrics:
  - `specMode`: `raw`
  - `zapImage`: `zaproxy/zap-stable:2.17.0`
  - `zapExitCode`: `2`
  - `coldRunSeconds`: `128`
  - `seededRequestCount`: `8`
  - `API alert URI count`: `0`
  - `Observed requestor URL count`: `8`
  - `Observed API requestor URL count`: `8`
  - `Configured API seed URL count`: `8`
  - `OpenAPI imported URL count`: `0`
  - `Spider discovered URL count`: `14`

What this means:

- the model 1 kit now spans at least two runtime classes:
  - single-artifact targets
  - compose-driven multi-service targets
- EventDebug still did **not** produce API-side alert lift, which is consistent with the earlier external benchmark result
- the route-exercise rerun proved the weakness is **not** simply that the API was never reached
- a config-only tuning pass also failed to improve signal, which means the next EventDebug work should focus on importer behavior or success-metric design rather than just adding more knobs
- the product limitation on EventDebug is currently detection/output quality, not in-repo installation or runtime orchestration
- EventDebug now has a model-1 success contract that matches exercised API routes even when alert-bearing API findings remain absent

## Engineering Lessons From The Rehearsal

The rehearsal exposed several adoption-relevant implementation details:

- target working directories must resolve from the target repo root, not from inside `zerodast/`
- Maven build artifacts need pattern-based lookup because versioned jar names are normal
- Git Bash + Windows + `podman.exe` requires explicit path-conversion handling for bind mounts
- PR-mode runtime tuning is sensitive: removing the spider entirely makes the run much faster, but loses the API-side signal we care about
- a reusable model 1 kit needs more than one runtime mode; harder targets can require compose-native startup rather than single-artifact boot
- extending to harder targets can still preserve the install surface even when scan output quality remains weak

These are exactly the kinds of issues a model 1 prototype must absorb before it is ready for broader adoption.

## What This Proves

This rehearsal supports the model 1 claim that:

- ZeroDAST can be transplanted into a target repo without scattering files
- the install shape is explainable in one short paragraph
- removal is obvious and scriptable
- the prototype can execute a real in-repo scan on a controlled target repo
- API-side signal can survive the model 2 to model 1 transition
- the PR profile can be tuned materially without collapsing all useful signal
- the tuned profile holds up on a less-controlled real benchmark clone, not only a throwaway copy
- the model 1 runner can now support more than one runtime class

It does **not** yet prove:

- adoption readiness for arbitrary repositories
- broad target-agnostic config portability
- acceptable default runtime ergonomics for all maintainer workflows
- reliable API-side finding lift on harder multi-service targets like EventDebug

## Recommendation

The next model 1 step should be:

1. keep the same two-zone install rule
2. keep `artifact` and `compose` as the two supported prototype runtime modes
3. treat the `5 minute active scan + 1 minute spider` profile as the provisional PR baseline for Petclinic-like targets
4. improve EventDebug success criteria or request seeding before claiming broad harder-target effectiveness





