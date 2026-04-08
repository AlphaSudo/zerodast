# Petclinic T5 Runbook

## Purpose

This runbook defines how to execute the **benchmark-only** Petclinic `T5` baseline in a fork or controlled copy of [spring-petclinic/spring-petclinic-rest](https://github.com/spring-petclinic/spring-petclinic-rest).

`T5` is:
- a fair conventional in-repo DAST baseline
- intentionally non-ZeroDAST
- used only to compare against Petclinic `T4`

## Baseline Location

The current benchmark implementation lives in the separate local clone:
- `C:\Java Developer\petclinic-t5-benchmark`

Implementation branch in that clone:
- `codex/petclinic-t5-baseline`

Primary workflow:
- `.github/workflows/zap-api-scan.yml`

## What The Workflow Does

The workflow follows a plain conventional OSS/AppSec pattern:
- checks out the target repo
- sets up JDK 17
- builds Petclinic with `./mvnw -B -DskipTests package`
- starts the packaged application jar locally
- waits for `/petclinic/actuator/health`
- verifies `/petclinic/v3/api-docs`
- runs the official `zaproxy/action-api-scan`
- uploads:
  - the ZAP scan artifact
  - the Petclinic application log

This is intentionally simpler than `T4`:
- no external orchestrator repo
- no trusted/untrusted split
- no ZeroDAST helper payload
- no ZeroDAST benchmark runner

## Recommended GitHub Execution Path

Because this is benchmark-only and should not touch the upstream Petclinic repo, run it like this:

1. Fork `spring-petclinic/spring-petclinic-rest` into a personal benchmark fork.
2. Push the `codex/petclinic-t5-baseline` branch into that fork.
3. Open a PR in the fork or trigger the workflow manually with `workflow_dispatch`.
4. Let the `OWASP ZAP API Scan` workflow complete.
5. Download:
   - `petclinic-t5-zap-api-scan`
   - `petclinic-t5-app-log`

## Evidence To Capture

For comparison against `T4`, record:
- setup burden:
  - files added to the target repo
  - whether the setup feels conventional and recognizable
- runtime:
  - cold run duration from GitHub Actions
- signal:
  - alert names
  - API-related URIs, if present
  - whether the output contains `/petclinic/api/*` evidence
- repo noise:
  - count and location of added files
- trust posture:
  - single in-repo workflow with broad target-repo trust assumptions

## Expected Differences Versus T4

What `T5` is expected to show:
- smaller conceptual system than ZeroDAST
- more direct in-repo coupling
- weaker trust separation
- likely lower artifact richness
- possibly similar or weaker signal, depending on how much the official action can extract from Petclinic

What would make the benchmark especially useful:
- `T5` reaches similar API signal with less machinery
- or `T4` clearly preserves signal while offering cleaner trust posture and lower long-term repo noise

Both outcomes are informative if we report them honestly.

## Status

Current state:
- workflow implemented locally
- local build/start/OpenAPI sanity check passed
- GitHub fork execution still pending

## Notes

The local sanity check already proved:
- frozen Petclinic SHA builds cleanly
- the packaged jar starts cleanly
- `/petclinic/actuator/health` responds
- `/petclinic/v3/api-docs` responds

So the remaining work is GitHub execution and result capture, not basic repo compatibility.
