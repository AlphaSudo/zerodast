# Architecture

## Core Model
ZeroDAST uses privilege isolation, credential isolation, and network isolation to scan untrusted PR artifacts without giving the untrusted PR direct write authority in the reporting step.

## Three-Layer Defense
1. Privilege Isolation
- `ci.yml` runs on `pull_request` with read-only contents permission.
- `dast-pr.yml` runs later from trusted `main` on `workflow_run`.
- The PR reporting job runs on a separate runner from the scan execution job.

2. Credential and Artifact Isolation
- The PR workflow builds a Docker image and uploads it as an artifact.
- The trusted DAST workflow downloads that artifact rather than reusing the PR runtime directly.
- Optional `overlay.sql` is validated before use.

3. Network Isolation
- The scan runtime creates a Docker `--internal` network.
- Postgres, the app, and ZAP communicate inside that private network.
- The GitHub runner itself remains outside the isolated container network.

## Data Flow
1. PR opens against `main`.
2. `ci.yml` runs lint, tests, static checks, delta detection, and image build.
3. PR artifacts are uploaded: image tar, delta endpoint file, optional overlay SQL.
4. `dast-pr.yml` downloads those artifacts on trusted `main`.
5. Overlay is validated.
6. Isolated runtime starts DB + app + ZAP.
7. Auth bootstrap runs, ZAP scans, authz checks run, canaries may run.
8. Reports are summarized and posted back to the PR from a separate job.

## Speed Levers
- Delta endpoint detection for PR scans.
- OpenAPI import to reduce aimless crawling.
- Full scans reserved for `FULL` scope or nightly runs.
- App, DB, and ZAP orchestration lives in a reusable runtime script.

## Why "Privilege Isolation"
Earlier wording such as “temporal isolation” under-described the trust boundary. The key control is not time alone; it is that write/report authority and untrusted code execution are separated by workflow and runner boundaries.
