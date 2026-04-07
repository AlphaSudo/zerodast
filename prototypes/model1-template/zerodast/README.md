# ZeroDAST In-Repo Prototype

This directory is the minimal in-repo ZeroDAST footprint for a controlled prototype.

## Ownership

ZeroDAST owns everything under `zerodast/`.
The target repo should only need:
- `.github/workflows/zerodast-pr.yml`
- `.github/workflows/zerodast-nightly.yml`
- `zerodast/`

## What this prototype proves

- the install footprint is concentrated
- workflows stay thin and orchestration-only
- target-specific settings live in `config.json`
- removal is obvious and reversible

## Mandatory files

- `config.json`
- `run-scan.sh`
- `prepare-openapi.js`
- `verify-report.js`
- `templates/automation.yaml`
- `reports/.gitignore`

## Install Into A Controlled Target Repo

From the ZeroDAST repo root:

```powershell
./prototypes/model1-template/install.ps1 -TargetRepoPath 'C:\path\to\target-repo'
```

That copies exactly two zones into the target repo:
- `.github/workflows/zerodast-*.yml`
- `zerodast/`

Nothing else should be required for the first prototype.

## Removal

Delete:
- `.github/workflows/zerodast-pr.yml`
- `.github/workflows/zerodast-nightly.yml`
- `zerodast/`

If anything else must be cleaned up, the prototype is too invasive.
