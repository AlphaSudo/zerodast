# Supply Chain Rules

## 6-Rule Framing
This repo documents and implements a practical six-rule supply-chain posture inspired by AlphaSudo/sbtr-benchmark framing:
- R0: PIN
- R1: QUARANTINE
- R2: ISOLATE
- R3: REBUILD
- R4: ARTIFACT QUARANTINE
- R5: VALIDATE

## How ZeroDAST Maps to the Rules
### R0: PIN
- GitHub Actions are pinned by commit SHA.
- ZAP image version is pinned via `security/zap/.zap-version`.
- Runner OS is explicitly selected as `ubuntu-22.04`.

### R1: QUARANTINE
- PR output is packaged as artifacts before trusted DAST consumption.
- Overlay SQL is treated as untrusted until validated.

### R2: ISOLATE
- The scan runtime uses Docker `--internal` networking.
- App, DB, and ZAP communicate in a private container network.

### R3: REBUILD
- PR lane rebuilds the demo image from source before artifact export.
- Nightly/mainline lane rebuilds from trusted repo state.

### R4: ARTIFACT QUARANTINE
- Trusted DAST consumes image tar + metadata from the artifact bundle rather than reusing the original PR runner state.
- Rule 4b exception: DAST requires scanning the built application artifact itself, but the artifact crosses into a constrained and isolated environment rather than directly into a write-capable reporting context.

### R5: VALIDATE
- `validate_overlay.py` validates additive SQL overlays.
- Delta detection falls back to `FULL` when uncertain.
- Canary verification checks expected scanner visibility.

## SBTR Mapping
The repo describes itself as self-benchmarked rather than certified. ZeroDAST is positioned as a T3-style implementation: materially better isolation than simple scanner CI, but still short of a fully bespoke platform.
