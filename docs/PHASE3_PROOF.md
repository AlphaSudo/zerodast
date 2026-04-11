# Phase 3 Proof: Richer Authentication Adapters

This document closes the **Phase 3 proof debt** for ZeroDAST's current target slice.

It is not claiming that every future auth feature is finished.
It is claiming that the repo now has enough measured proof to say:

- auth support is materially broader than bearer-token-only flows
- at least three auth styles are proven cleanly
- at least two non-demo external repos are proven with nontrivial auth adapters
- browser-grade auth was intentionally kept out of the PR lane

Current assessment date:
- `2026-04-11`

## What Phase 3 Needed To Prove

For the current claim package, the important Phase 3 questions were:

1. Is ZeroDAST still effectively bearer-only?
2. Can the adapter model handle more than one auth transport cleanly?
3. Can richer auth be proven on public non-demo targets, not just the built-in app?
4. Can we do that without dragging browser-grade auth into the PR lane and blowing timing budgets?

The answer to those questions is now **yes** for the current REST-first scope.

## Proven Auth Styles

The repo now has clean proof for at least these auth styles:

1. **JSON body login -> bearer header**
- built-in demo app
- adapter:
  - [json-token-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/json-token-login.sh)

2. **Form/cookie session login**
- built-in demo app
- adapter:
  - [form-cookie-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/form-cookie-login.sh)
- CI proof:
  - `Auth Adapter Smoke #1`

3. **JSON session login -> session header**
- external Django target
- adapter:
  - [json-session-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/json-session-login.sh)

4. **Form-urlencoded OAuth2-style login -> bearer header**
- external FastAPI target
- adapter:
  - [form-urlencoded-token-login.sh](C:/Java%20Developer/DAST/scripts/auth-adapters/form-urlencoded-token-login.sh)

That is enough to say the current system is no longer meaningfully "bearer-only."

## External Non-Demo Proof

### 1. Django session-auth profile

Target:
- `HackSoftware/Django-Styleguide-Example`

Workflow:
- [django-auth-profile.yml](C:/Java%20Developer/DAST/.github/workflows/django-auth-profile.yml)

Runner:
- [run-auth-profile.sh](C:/Java%20Developer/DAST/benchmarks/django-styleguide-example/run-auth-profile.sh)

Proven behavior:
- session login
- protected-route validation
- admin-route validation
- auth transport:
  - `Authorization: Session <sessionid>`

Measured proof:
- local cold run:
  - `26s`
- CI proof:
  - `Django Auth Profile #1`
  - `92s`

### 2. FastAPI form-urlencoded bearer auth profile

Target:
- `fastapi/full-stack-fastapi-template`

Workflow:
- [fullstack-fastapi-auth-profile.yml](C:/Java%20Developer/DAST/.github/workflows/fullstack-fastapi-auth-profile.yml)

Runner:
- [run-auth-profile.sh](C:/Java%20Developer/DAST/benchmarks/fullstack-fastapi-template/run-auth-profile.sh)

Proven behavior:
- public signup for a normal user
- form-urlencoded token login
- protected-route validation on `/api/v1/users/me`
- admin-route validation on `/api/v1/users/?skip=0&limit=10`
- auth transport:
  - `Authorization: Bearer <access_token>`

Measured proof:
- CI proof:
  - `Fullstack FastAPI Auth Profile`
  - successful run on commit `40cf5d1`
  - runtime from workflow timestamps:
    - about `52s`

Important note:
- the runner hard-fails on signup, token bootstrap, protected validation, or admin validation
- so a successful workflow run is meaningful proof that those checks all passed

## Timing / PR Discipline

What is true now:
- richer auth exists
- richer auth has CI proof
- browser-grade auth is still **not** in the PR lane
- the core PR lane remains bounded and fast

That means the Phase 3 auth widening did not require violating the CI timing discipline.

## What This Does Not Claim

This proof does **not** claim:

- SSO / SAML / OIDC federation support
- MFA / TOTP flows
- browser-recorded login replay
- multi-step login scripting is finished
- refresh-token/session-refresh handling is finished

Those are still future auth-breadth items.

But they are no longer required to say the current auth model is materially broader than bearer-only bootstrap.

## Conclusion

For ZeroDAST's current REST-first target slice, **Phase 3 proof debt is now closed**.

That is because the repo now has:

- at least three cleanly proven auth styles
- two non-demo external auth-profile proofs
- one external session-oriented public target
- one external OAuth2 form-urlencoded token target
- continued PR/nightly timing discipline without browser-grade auth in the PR path
