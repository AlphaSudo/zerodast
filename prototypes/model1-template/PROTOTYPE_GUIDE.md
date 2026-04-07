# Model 1 Prototype Guide

This template is the first controlled **model 1** transplant shape.

## What It Proves

- ZeroDAST can live inside a target repository without scattering files
- workflows can stay thin
- target-specific settings can stay under `zerodast/config.json`
- removal is obvious and scriptable

## Install Footprint

The installer copies exactly:

- `.github/workflows/zerodast-pr.yml`
- `.github/workflows/zerodast-nightly.yml`
- `zerodast/`

## Install

```powershell
./prototypes/model1-template/install.ps1 -TargetRepoPath 'C:\path\to\target-repo'
```

Use `-Force` only if you intentionally want to replace an existing prototype install.

## Remove

```powershell
./prototypes/model1-template/uninstall.ps1 -TargetRepoPath 'C:\path\to\target-repo'
```

## Current Limits

This is still a controlled prototype:

- the runner is intentionally simple
- the config is Petclinic-flavored for the first transplant
- it proves install cleanliness before it proves maximum scan sophistication
