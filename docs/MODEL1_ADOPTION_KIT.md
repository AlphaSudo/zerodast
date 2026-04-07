# Model 1 Adoption Kit

## Purpose

The model 1 adoption kit is the first attempt to make the in-repo ZeroDAST prototype feel like a reusable package instead of a pile of benchmark-side files.

The goal is not full installer polish yet.
The goal is a cleaner handoff shape.

## What The Kit Contains

The export keeps the same two-zone install contract:

- `.github/workflows/zerodast-pr.yml`
- `.github/workflows/zerodast-nightly.yml`
- `zerodast/`

It also includes:

- `examples/`
- `install.ps1`
- `uninstall.ps1`
- `PROTOTYPE_GUIDE.md`
- `manifest.json`

## Export The Kit

From the ZeroDAST repo root:

```powershell
./prototypes/model1-template/package.ps1 -Force
```

Default outputs:

- `prototypes/model1-template/dist/model1-kit/`
- `prototypes/model1-template/dist/model1-kit.zip`

## Included Examples

The kit now ships with two concrete example configs:

- `examples/petclinic-config.json`
- `examples/eventdebug-config.json`

These are not universal defaults.
They are example shapes for the two runtime classes currently proven by the prototype:

- `artifact`
- `compose`

## Why This Matters

Without a kit export step, model 1 still feels coupled to the ZeroDAST repo layout.

The kit export gives us:

- a self-contained handoff directory
- a zipped artifact for adoption rehearsals
- a manifest tied to a specific ZeroDAST source commit
- example configs for both supported runtime classes

That makes the prototype easier to evaluate as a product surface.

## What This Does Not Solve Yet

The adoption kit is still only a prototype package.

It does **not** yet provide:

- target auto-detection
- universal target config generation
- one-click install for arbitrary repositories
- multi-platform runtime guarantees beyond the patterns already proven locally

## Recommendation

Use the kit when:

- rehearsing model 1 adoption on a controlled repo
- sharing a frozen prototype shape with another engineer
- comparing install surfaces across targets

Do not treat it yet as the final distribution format for ZeroDAST.
