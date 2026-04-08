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
