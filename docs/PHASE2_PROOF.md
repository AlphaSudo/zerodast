# Phase 2 Proof: Scan-Quality Uplift Without PR Regression

This document closes the remaining **Phase 2 proof debt**.

It focuses on the part of Phase 2 that matters for the claim story:
- external rerun evidence
- signal uplift vs timing impact
- whether improved scan quality stayed inside the intended CI budget

This document does **not** claim every implementation idea from Phase 2 is complete.
It only answers whether the proof debt is now strong enough to stop calling Phase 2 externally unproven.

## Scope

Targets used for proof:
- FastAPI external authenticated/admin target
- Spring Petclinic external REST target

Why these two:
- they are materially different stacks
- they were already part of the benchmark set
- they show two different Phase 2 outcomes:
  - better authenticated API reach on FastAPI
  - stronger spec/hint alignment on Petclinic

## What Counts As Signal Uplift Here

Signal uplift in Phase 2 is **not** defined as "more alerts no matter what."

For this phase, signal uplift means one or more of:
- better route exercise
- better authenticated/admin route exercise
- better observed-vs-unobserved coverage visibility
- better route-seeded targeting of the changed/relevant surface
- better operator ability to distinguish:
  - reached routes
  - unreached routes
  - alert-bearing routes

That definition is deliberate, because otherwise the benchmark would reward noisy active-scan behavior over useful CI signal.

## External Rerun Evidence

| Target | Earlier Reference Point | Later Scan-Quality Evidence | Signal Change | Timing Change | Assessment |
| --- | --- | --- | --- | --- | --- |
| FastAPI T4 | `133s`, API alert URI count `14`, strong authenticated/admin proof | `3m 44s`, seeded request count `10`, observed OpenAPI routes `9 / 15`, unobserved routes made explicit | Better measured API reach and clearer coverage visibility, even though raw API alert count did not need to rise further | Slower by roughly `91s`, still well inside nightly budget | Positive uplift without breaking budget |
| Petclinic T4 | `145s` initial / `209s` clean rerun, seeded request count `15`, API alert URIs observed `1` | `5m 9s`, observed OpenAPI routes `17 / 17`, code-hinted observed routes `17 / 17`, undocumented observed routes classified mostly as operational/UI surface | Much stronger route-coverage confidence and cleaner distinction between documented API surface and operational/UI observations | Slower by roughly `100s` vs clean rerun, still well inside nightly budget | Positive uplift without breaking budget |

## FastAPI Read

What changed:
- bounded spec-derived request seeding improved route exercise
- API inventory output made observed/unobserved routes explicit
- code-hint inventory confirmed the documented surface shape

What matters:
- the earlier strong T4 already had:
  - authenticated bootstrap
  - admin-path proof
  - API alert URI count `14`
- the later scan-quality model improved:
  - seeded request count to `10`
  - observed OpenAPI routes to `9 / 15`
  - artifact clarity about what was still unobserved

Interpretation:
- the uplift here is **not** "more alerts"
- the uplift is:
  - broader measured reach
  - better operator understanding of what the scan did and did not cover

## Petclinic Read

What changed:
- inventory/hint model was applied to the existing T4 benchmark
- route visibility became much stronger

What matters:
- earlier Petclinic T4 already had a clean CI-backed benchmark path
- later proof showed:
  - `Observed OpenAPI routes: 17 / 17`
  - `Code-hinted observed routes: 17 / 17`
  - undocumented observations were mostly operational/UI, not hidden API breadth

Interpretation:
- the uplift here is stronger confidence in API reach and lower ambiguity
- this is a quality gain even though raw alert count did not explode

## Timing Read

The important timing question is not "did the later runs get slower at all?"

It is:
- did the uplift flatten the CI budget?

Answer:
- **no**

Observed later timings:
- FastAPI follow-up: `3m 44s`
- Petclinic follow-up: `5m 9s`

Both remain comfortably inside:
- PR target under `10 min`
- nightly target under `15 min`

So the truthful Phase 2 read is:
- scan-quality uplift did add cost
- but the cost remained acceptable for the current profile budgets

## Conclusion

Phase 2 proof debt is now closed strongly enough for the current claim story.

What is now proven:
- at least two external targets were re-run under the improved scan-quality model
- signal uplift was visible in a meaningful CI sense
- timing stayed inside the intended bounded profile envelope
- benchmark docs were updated with the newer evidence

What is still not claimed:
- every Phase 2 implementation idea is complete
- stronger per-profile scan budget controls are fully done
- the phase should be treated as "perfectly finished"

The honest conclusion is narrower:

> Phase 2 no longer lacks external proof. Its remaining gap is implementation/polish, not whether the improved scan-quality model works on real targets.
