# EventDebug Investigation Plan

## Purpose

This plan exists to answer one specific question:

> Is EventDebug a fundamentally weak DAST target for the current ZeroDAST strategy, or is the current weak API-side signal mostly caused by adaptation and measurement choices we can still improve?

That is narrower than "does ZeroDAST work on EventDebug?"

The current evidence already shows that ZeroDAST **does** work operationally on EventDebug:

- install and transplant work
- compose-mode runtime boot works
- health and OpenAPI fetch work
- ZAP runs and reports are generated

The unclear part is detection value.

## Current Facts

These points are already established by the benchmark and model 1 rehearsal:

- EventDebug is a multi-service target with Postgres, Kafka, UI, and API components.
- The benchmark first pass intentionally runs unauthenticated.
- ZeroDAST can execute EventDebug in both:
  - external-orchestrator style
  - model 1 in-repo compose mode
- The current scans produce candidate findings on root and frontend-adjacent surfaces.
- The current scans do **not** produce alert-bearing `/api/v1/*` instances.

So the unresolved problem is:

- **runtime success:** yes
- **meaningful API-side detection lift:** not yet

## Working Hypotheses

The next investigation should treat these as separate possibilities, not one blended failure.

### H1. EventDebug is a weak classic-DAST target in unauthenticated mode

Possible interpretation:

- the interesting risks in EventDebug may be logic, authz, or state-dependent
- classic passive/active ZAP findings may naturally be sparse on `/api/v1/*`

If this hypothesis is true, ZeroDAST is not "broken" on EventDebug.
The target is just harder than Petclinic for the current scanner strategy.

### H2. Our current success metric is too narrow

Right now, we heavily weight:

- `API alert URI count`

That metric is useful, but it may be too strict for a harder real repo.

Possible refinement:

- route exercise count
- API response status diversity
- number of distinct `/api/v1/*` routes actually requested by ZAP
- whether seeded API requests are preserved in the scan history even when no alert is raised

If this hypothesis is true, the current benchmark may be under-crediting real scan activity.

### H3. EventDebug still needs richer target-specific input

Possible interpretation:

- current request seeding is too shallow
- seeded IDs are too static
- OpenAPI import alone is not enough to drive meaningful route exploration
- base-path and route-entry choices may still bias the scan toward the UI shell

If this hypothesis is true, ZeroDAST can likely improve the result without changing the overall architecture.

### H4. ZAP is the limiting factor on this target

Possible interpretation:

- ZAP can run the target, but it may not produce useful API findings here without auth, richer state, or a different scan strategy

If this hypothesis is true, the limitation is not specific to ZeroDAST.

## Investigation Goals

The next EventDebug pass should answer these questions in order:

1. Are `/api/v1/*` routes being exercised more than our current alert metric suggests?
2. If yes, are we missing signal only because the current metric is too narrow?
3. If no, can richer seeding or scope controls materially improve route exercise?
4. If route exercise improves but alerts still do not, is EventDebug better treated as an operational benchmark than a finding-lift benchmark?


## Experiment 1 Outcome

Experiment 1 is now complete for the current model 1 EventDebug pass.

Observed rerun result:

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

Observed conclusion:

- this is **not** a "no API exercise" case
- all configured API seed URLs were observed by the requestor phase
- the current weakness is therefore downstream of basic route exercise

This narrows the problem materially.
The next investigation should assume:

- runtime boot works
- route exercise exists
- alert generation remains weak

That makes `H2`, `H3`, and `H4` more likely than a simple "the API was never reached" explanation.
## Proposed Experiments

These should be small and isolated.
Do not mix them into one giant tuning pass.

### Experiment 1. Measure route exercise directly

Add a report-side metric for:

- distinct `/api/v1/*` URIs observed in the ZAP report
- distinct seeded API URLs actually requested

Success criterion:

- we can distinguish "no API alerts" from "no API exercise"

Why this matters:

- right now those two cases are too easy to blur together

### Experiment 2. Expose richer scan controls in model 1 config

Make harder-target knobs configurable rather than script-only:

- additional request seed lists
- spider target override
- passive scan wait duration
- active scan duration
- optional rule overrides

Success criterion:

- EventDebug can be tuned through config, not by editing the runner

Why this matters:

- if harder targets require code edits, the kit is not really adaptable yet

### Experiment 3. Expand EventDebug request seeding with documented and seeded IDs

Add more route coverage around:

- aggregates
- events
- timelines
- any additional stable seeded identifiers from the benchmark data

Success criterion:

- more distinct `/api/v1/*` request targets are exercised during the run

Why this matters:

- current seeds may be too narrow for this target's meaningful behavior

### Experiment 4. Separate operational success from finding-lift success

Define two EventDebug result classes:

- operational success
- finding-lift success

Operational success means:

- install works
- runtime boots
- scan completes
- artifacts are produced

Finding-lift success means:

- route exercise or alert-bearing API signal improves beyond the current baseline

Why this matters:

- EventDebug already demonstrates one kind of value even if it does not yet demonstrate the other


## Experiment 2 Outcome

Experiment 2 is now complete for the current model 1 EventDebug pass.

Changes made:

- exposed `scan.spiderPath` in config
- exposed per-mode `spiderMaxDepth` and `spiderMaxChildren`
- exposed per-mode `passiveWaitMinutes`
- exposed per-mode `defaultStrength` and `defaultThreshold`
- expanded the EventDebug example seeds to include both bare and query-string variants for `events/recent` and `aggregates/search`, plus the stable `aggregates/1/timeline` path

Observed rerun result:

- `coldRunSeconds`: `115`
- `API alert URI count`: `0`
- `Observed API requestor URL count`: `8`
- `Configured API seed URL count`: `8`
- `OpenAPI imported URL count`: `0`
- `Spider discovered URL count`: `14`

Observed conclusion:

- the new scan controls are now part of the product surface, which is a real model 1 improvement
- the richer EventDebug config did **not** materially improve API-side signal
- `openapi added 0 URLs` remains one of the strongest indicators that imported route discovery is still weak on this target
- EventDebug now looks more like a target where ZeroDAST can prove execution and route exercise, but not yet alert lift

## Experiment 3 Outcome

Experiment 3 is complete enough to inform the next product decision.

What changed:

- EventDebug now has a richer example seed set in the model 1 kit
- the kit now supports an explicit `reporting.successMode`
- EventDebug can declare success via `route_exercise` instead of only `api_alerts`

Why this is justified:

- EventDebug already proved `8/8` configured API seeds were exercised
- repeated reruns still produced `0` API alert URIs
- that means EventDebug is a poor fit for an alert-only success contract right now, but still a valid operational benchmark target

Current recommendation:

- keep Petclinic on `successMode: api_alerts`
- allow EventDebug to use `successMode: route_exercise`
- continue treating EventDebug as a hard-target operational benchmark unless importer behavior or target-specific tuning later produces alert-bearing API signal

## Experiment 4 Outcome

Experiment 4 is now complete for the current model 1 EventDebug pass.

What changed:

- the model 1 kit now supports `reporting.successMode`
- Petclinic stays on `api_alerts`
- EventDebug can opt into `route_exercise`

Observed route-exercise rerun result:

- `Success mode`: `route_exercise`
- `Success result`: `pass`
- `Success reason`: `Route exercise thresholds satisfied (8 observed API requestor URLs, seed observation ratio 1.00)`
- `coldRunSeconds`: `124`
- `API alert URI count`: `0`
- `Observed API requestor URL count`: `8`
- `Seed observation ratio`: `1.00`
- `OpenAPI imported URL count`: `0`

Observed conclusion:

- EventDebug still does **not** demonstrate alert-bearing API lift
- but it now has a success contract that matches the value it is actually proving: reproducible API route exercise on a harder multi-service target
- this is a product-shape improvement, not a detection breakthrough
## Proposed Exit Criteria

We should stop the EventDebug investigation loop when one of these becomes true:

### Exit A. We improve the signal

Evidence:

- higher API route exercise
- or new alert-bearing `/api/v1/*` instances
- or both

Conclusion:

- EventDebug becomes at least a partial finding-lift success

### Exit B. We do not improve the signal, but we prove the routes are exercised

Evidence:

- route exercise improves measurably
- alerts remain absent or weak

Conclusion:

- EventDebug remains an operational benchmark and hard-target control, not a detection-lift showcase

### Exit C. We fail to improve either route exercise or signal after bounded tuning

Evidence:

- richer seeding and config controls do not materially change the result

Conclusion:

- the current unauthenticated ZAP-based approach is not sufficient for EventDebug
- that becomes an explicit benchmark limitation, not an ambiguous gap

## Recommendation

The next engineering pass should focus on:

1. adding route-exercise metrics
2. exposing harder-target scan controls in config
3. rerunning EventDebug with richer seeds

That is the smallest serious step that can tell us whether the weakness is mostly:

- target nature
- metric choice
- or adaptation depth




