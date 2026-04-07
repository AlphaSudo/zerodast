# Model 1 Install Guide

## Purpose

This guide explains how to install the **model 1 in-repo ZeroDAST prototype** into a target repository.

It is based on the controlled Petclinic transplant and the harder EventDebug adaptation path.

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

## Supported Runtime Modes

The prototype currently supports two runtime modes in `zerodast/config.json`:

### 1. `artifact`

Use this when the target can be modeled as:

- build one application artifact
- run one application container
- scan one primary HTTP target

This is the simpler Petclinic-style path.

### 2. `compose`

Use this when the target needs a composed local stack, for example:

- app + database
- app + database + Kafka
- any repo where the proven local boot path is already defined by compose services

This is the harder EventDebug-style path.

## Before You Install

The current prototype assumes a target repo can provide one of these:

- an artifact-style local boot path
- or a compose-style local boot path

And in both cases:

- a reachable health endpoint
- a reachable OpenAPI JSON endpoint
- Docker or Podman-compatible container execution

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

- runtime mode
- build command or compose commands
- artifact lookup pattern
- target working directory
- port
- base path
- health endpoint
- OpenAPI endpoint
- scan-mode settings
- request seeds
- API signal prefix when the target does not follow the Petclinic-style `/api/` convention

The rule for this prototype is:

- change config first
- only change scripts if the target really needs new behavior

## Artifact Mode Example

Use `artifact` mode for targets like Petclinic:

```json
{
  "target": {
    "runtimeMode": "artifact",
    "buildCommand": "./mvnw -q -DskipTests package",
    "artifactPattern": "target/spring-petclinic-rest-*.jar"
  }
}
```

## Compose Mode Example

Use `compose` mode for targets like EventDebug:

```json
{
  "target": {
    "runtimeMode": "compose",
    "workingDirectory": ".",
    "port": 9090,
    "basePath": "/api/v1",
    "apiSignalPathPrefix": "/api/v1/",
    "healthPath": "/api/v1/health/ready",
    "openApiPath": "/api/v1/openapi.json",
    "compose": {
      "upCommand": "<compose-up-command>",
      "downCommand": "<compose-down-command>",
      "networkName": "<target-network>",
      "appHost": "<app-hostname-on-network>"
    }
  }
}
```

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
- the target still shows meaningful API-side signal, if that target has proven signal in earlier benchmarks

For the controlled Petclinic transplant, the current best-known PR profile is:

- `5` minute active scan
- `1` minute spider
- preserved API-side signal
- materially better runtime than the earlier heavier PR profile

For EventDebug-style targets, the kit can now boot and scan the composed stack, but API-side alert lift may still remain weak.

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

- the current config shape is still benchmark-informed
- Windows + Git Bash + Podman needs explicit path-conversion handling
- artifact lookup may need target-specific pattern changes
- compose mode needs accurate target network and service host values
- PR runtime is improved, but still not lightweight enough to call universally comfortable
- harder targets may complete operationally while still producing weak API-side alert lift

## Recommendation

Use this guide for:

- controlled transplants
- adoption rehearsals
- proving in-repo cleanliness and reversibility
- exercising the kit across different runtime classes

Do not treat it yet as a universal one-command installer for arbitrary repositories.
