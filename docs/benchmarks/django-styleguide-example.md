# `HackSoftware/Django-Styleguide-Example`

## Benchmark Role

This repository is the next external **Phase 3** target for ZeroDAST.

Its purpose is not to replace the authenticated FastAPI benchmark.
Instead, it adds a stronger auth-adapter benchmark shape:

- Django
- cookie-based session authentication
- session-as-header fallback
- JWT login also present

That makes it a better fit for proving richer auth adapters than the current bearer-token-first FastAPI target.

## Frozen Target

- Repository: `HackSoftware/Django-Styleguide-Example`
- Frozen SHA: `a70ef43d7df03706c1211d4fcfd70b4b0120ba1e`
- Local benchmark clone: [C:\Java Developer\django-styleguide-benchmark](C:/Java%20Developer/django-styleguide-benchmark)

## Why This Repo Was Chosen

ZeroDAST Phase 3 needs a public repository where session/cookie auth is a real first-class path, not an artificial add-on.

This target is a strong fit because it already documents and implements:

- session login at `/api/auth/session/login/`
- protected user information at `/api/auth/me/`
- session logout at `/api/auth/session/logout/`
- user-list API at `/api/users/`
- session-as-header support through `Authorization: Session <sessionid>`
- JWT login/logout as a parallel auth shape

That gives ZeroDAST a credible public repo for testing:

- cookie/session adapter behavior
- protected-route validation beyond bearer tokens
- adapter flexibility against a real Django/DRF auth model

## Relevant Repo Surfaces

- auth APIs:
  - [styleguide_example/authentication/apis.py](C:/Java%20Developer/django-styleguide-benchmark/styleguide_example/authentication/apis.py)
  - [styleguide_example/authentication/urls.py](C:/Java%20Developer/django-styleguide-benchmark/styleguide_example/authentication/urls.py)
- auth mixins:
  - [styleguide_example/api/mixins.py](C:/Java%20Developer/django-styleguide-benchmark/styleguide_example/api/mixins.py)
- protected user API:
  - [styleguide_example/users/apis.py](C:/Java%20Developer/django-styleguide-benchmark/styleguide_example/users/apis.py)
- project overview:
  - [README.md](C:/Java%20Developer/django-styleguide-benchmark/README.md)

## Initial Auth Targets

### Session / Cookie Path

- login:
  - `POST /api/auth/session/login/`
- protected self-check:
  - `GET /api/auth/me/`
- additional protected API:
  - `GET /api/users/`

### Session-As-Header Path

The repo also supports:

- `Authorization: Session <sessionid>`

This is useful because it gives ZeroDAST an intermediate auth shape between:

- browser-cookie-only flows
- and simple bearer-token flows

### JWT Path

- login:
  - `POST /api/auth/jwt/login/`
- logout:
  - `POST /api/auth/jwt/logout/`

This is not the main reason to choose the repo, but it gives us a fallback benchmark path if the session route introduces setup friction.

## Phase 3 Success Criteria For This Repo

The first success bar is not “full T4 immediately.”
The right proof ladder is:

1. bootstrap the repo locally in benchmark form
2. prove session login works
3. prove protected-route validation works on `/api/auth/me/`
4. prove additional protected API reach on `/api/users/`
5. choose whether the best ZeroDAST adapter for this repo is:
   - cookie/session
   - session-as-header
   - or JWT fallback

## What This Repo Can Teach Us

This target should answer:

- whether ZeroDAST’s adapter model really extends beyond bearer tokens
- whether session/cookie auth remains CI-friendly in a public repo
- whether a public Django/DRF target changes the timing or complexity profile materially

## Current Status

- repo chosen: yes
- SHA frozen: yes
- local clone created: yes
- auth/profile review: initial pass complete
- benchmark implementation: not started
