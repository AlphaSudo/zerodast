# Repo Fleet Summary

- Tracked targets: 4
- Categories tracked: 3
- Auth modes tracked: 4

## Target Matrix

| Target | Category | Auth Mode | Profiles | Latest Proof | Timing |
| --- | --- | --- | --- | --- | ---: |
| ZeroDAST Demo App | core-demo | adapter | pr-delta, nightly-full | DAST Nightly #64 | 203s |
| Fullstack FastAPI T4 | external-benchmark | bearer-token | metadata, trusted-scan | Fullstack FastAPI T4 Scan #10 | 225s |
| Spring Petclinic T4 | external-benchmark | unauthenticated | metadata, trusted-scan | Petclinic T4 Scan #4 | 309s |
| Django Styleguide Auth Profile | external-auth-profile | session-header | auth-profile | Django Auth Profile #1 | 92s |

## ZeroDAST Demo App

- Repo: AlphaSudo/zerodast
- URL: https://github.com/AlphaSudo/zerodast
- Category: core-demo
- Auth mode: adapter
- Auth shapes: json-token, form-cookie
- Profiles supported: pr-delta, nightly-full
- Latest proof workflow: DAST Nightly #64
- Latest proof status: proven
- Latest proof timing: 203s
- Latest proof notes: Operational reliability artifact reported healthy state with complete runtime checks.

### Known Limitations

- Built-in demo target only
- Not evidence of generalized multi-repo control-plane parity

## Fullstack FastAPI T4

- Repo: fastapi/full-stack-fastapi-template
- URL: https://github.com/fastapi/full-stack-fastapi-template
- Category: external-benchmark
- Auth mode: bearer-token
- Auth shapes: jwt-bearer
- Profiles supported: metadata, trusted-scan
- Latest proof workflow: Fullstack FastAPI T4 Scan #10
- Latest proof status: proven
- Latest proof timing: 225s
- Latest proof notes: External hard-target proof with API inventory and code-hinted route metrics.

### Known Limitations

- OpenAPI importer still reported 0 imported URLs
- Observed OpenAPI routes remain partial rather than complete

## Spring Petclinic T4

- Repo: spring-petclinic/spring-petclinic-rest
- URL: https://github.com/spring-petclinic/spring-petclinic-rest
- Category: external-benchmark
- Auth mode: unauthenticated
- Auth shapes: public-rest
- Profiles supported: metadata, trusted-scan
- Latest proof workflow: Petclinic T4 Scan #4
- Latest proof status: proven
- Latest proof timing: 309s
- Latest proof notes: Second hard-target proof with full observed OpenAPI route coverage and strong code-hint alignment.

### Known Limitations

- Default benchmark path is unauthenticated
- Undocumented observed routes are mostly operational/UI surface

## Django Styleguide Auth Profile

- Repo: HackSoftware/Django-Styleguide-Example
- URL: https://github.com/HackSoftware/Django-Styleguide-Example
- Category: external-auth-profile
- Auth mode: session-header
- Auth shapes: session-header, session-cookie-compatible
- Profiles supported: auth-profile
- Latest proof workflow: Django Auth Profile #1
- Latest proof status: proven
- Latest proof timing: 92s
- Latest proof notes: External richer-auth proof using Authorization: Session <sessionid>.

### Known Limitations

- Auth-profile proof, not yet full T3/T4 benchmark parity
- Does not yet prove browser-cookie replay inside ZAP
