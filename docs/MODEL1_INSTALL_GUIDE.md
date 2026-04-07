# Model 1 Install Guide

## Purpose

This guide explains how to install the **model 1 in-repo ZeroDAST prototype** into a target repository.

It is based on the controlled Petclinic transplant that has already been proven locally.

The goal is to make the install shape easy to understand before we ask anyone to adopt it more broadly.

## What Gets Added

The current model 1 prototype adds exactly two install zones:

1. `.github/workflows/`
2. `zerodast/`

In practice, that means:

- `.github/workflows/zerodast-pr.yml`
- `.github/workflows/zerodast-nightly.yml`
- `zerodast/`

Everything else in the target repo should stay untouched.

## What The `zerodast/` Folder Contains

The prototype keeps the DAST logic concentrated in one root folder:

- `zerodast/README.md`
- `zerodast/config.json`
- `zerodast/run-scan.sh`
- `zerodast/prepare-openapi.js`
- `zerodast/verify-report.js`
- `zerodast/templates/automation.yaml`
- `zerodast/reports/.gitignore`

That is the ownership boundary.

## Before You Install

The current prototype assumes a target repo that can provide:

- a build command
- a runnable application artifact
- a reachable health endpoint
- a reachable OpenAPI JSON endpoint
- Docker or Podman-compatible container execution

The current template is Petclinic-flavored, so it is a better fit for a controlled transplant than a random repo with unknown runtime behavior.

## Install

From the ZeroDAST repo root:

```powershell
./prototypes/model1-template/install.ps1 -TargetRepoPath 'C:\path\to\target-repo'
```

Use `-Force` only when you intentionally want to replace an existing prototype install.

## First Things To Edit

The first file to adapt is:

- `zerodast/config.json`

That file controls:

- build command
- artifact lookup pattern
- target working directory
- port
- base path
- health endpoint
- OpenAPI endpoint
- scan-mode settings
- request seeds

The rule for this prototype is:

- change config first
- only change scripts if the target really needs new behavior

## Running It Locally

Once installed inside the target repo, the runner is invoked from the target repo itself:

```bash
chmod +x zerodast/run-scan.sh
ZERODAST_MODE=pr ./zerodast/run-scan.sh
```

On Windows with Git Bash + Podman, use an explicit container binary when needed:

```bash
ZERODAST_DOCKER_CMD='/c/Users/CM/AppData/Local/Programs/Podman/podman.exe' \
ZERODAST_MODE=pr \
./zerodast/run-scan.sh
```

## What Success Looks Like

For the current prototype, success means:

- reports are written under `zerodast/reports/`
- `summary.md` is produced
- the scan finishes cleanly
- the target still shows meaningful API-side signal

For the controlled Petclinic transplant, the current best-known PR profile is:

- `5` minute active scan
- `1` minute spider
- preserved API-side signal
- materially better runtime than the earlier heavier PR profile

## What To Expect In The Reports

The runner writes runtime outputs under:

- `zerodast/reports/`

Typical files include:

- `summary.md`
- `metrics.json`
- `zap-report.json`
- `zap-run.log`
- generated config/spec helper files

These are runtime artifacts, not part of the install footprint.

## Remove

To remove the prototype:

```powershell
./prototypes/model1-template/uninstall.ps1 -TargetRepoPath 'C:\path\to\target-repo'
```

That removes:

- `.github/workflows/zerodast-pr.yml`
- `.github/workflows/zerodast-nightly.yml`
- `zerodast/`

If more cleanup is required than that, the install shape has become too invasive.

## Current Caveats

This is still a prototype, not the final general-purpose installer.

Known caveats:

- the current config shape is tuned around the controlled Petclinic transplant
- Windows + Git Bash + Podman needs explicit path-conversion handling
- artifact lookup may need target-specific pattern changes
- PR runtime is improved, but still not lightweight enough to call universally comfortable

## Recommendation

Use this guide for:

- controlled transplants
- adoption rehearsals
- proving in-repo cleanliness and reversibility

Do not treat it yet as a universal one-command installer for arbitrary repositories.
