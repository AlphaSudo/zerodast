# Contributing to ZeroDAST

Welcome! We are glad you want to contribute. This guide covers the full contribution workflow.

## Prerequisites

- **Node.js 22+** (for `demo-app` lint/tests)
- **Python 3.11+** (for overlay validation)
- **Docker or Podman** (for running the demo application)

## Getting Started

1. Fork the repository and clone your fork.
2. Create a branch with a descriptive name:
   ```bash
   git checkout -b fix/your-fix-description
   ```
3. Make your changes, keeping them focused and small.
4. Open a pull request against `main`.

## Running demo-app lint and tests

```bash
cd demo-app
npm ci
npm run lint
npm test
```

## Validating an overlay

```bash
python db/seed/validate_overlay.py <path-to-overlay.sql>
```

## Security-sensitive contributions

If your change touches `overlay.sql` or database seeding logic, read [docs/CONTRIBUTING_SECURITY.md](docs/CONTRIBUTING_SECURITY.md) before submitting.

## PR checklist

- [ ] Changes are focused and minimal
- [ ] Code matches the existing style
- [ ] Tests pass (`npm test` in `demo-app`)
- [ ] Overlay validated if modified

## Good first issues

Looking for somewhere to start? Check issues labeled [`good first issue`](https://github.com/AlphaSudo/zerodast/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).

## Questions?

Open an issue or start a discussion — we are happy to help.
