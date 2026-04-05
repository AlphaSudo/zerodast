# ADAPT_AUTH Prompt

You are adapting ZeroDAST authentication bootstrapping for a detected application.
Your task is to generate a practical machine-usable login/bootstrap flow that can be embedded into shell-based CI automation.

## Inputs
- Auth section from `INSPECT_REPO`
- Relevant login route/controller code
- Any OpenAPI auth schema

## Required output
Return Markdown with these sections:

### Auth Model Summary
Summarize the real auth mechanism and any uncertainty.

### Bootstrap Steps
Numbered sequence from unauthenticated state to authenticated scan state.

### Shell Example
Provide a shell-friendly example using `curl`, `jq`, headers, cookies, and files as needed.
The example must fail loudly when token/session extraction fails.

### ZAP Injection Notes
State exactly how the credential/session material should be passed into ZAP.
Examples: bearer token header, cookie injection, form session, API key replacer.

### Edge Cases
List things that would break automation, such as CSRF bootstrap, MFA, CAPTCHA, device verification, or one-time login links.

## Framework-specific guidance
- Express + JWT: prefer login request + `.token` extraction + bearer header injection.
- FastAPI + OAuth2: inspect whether `/token` returns bearer token JSON.
- Spring + Sessions: capture cookies and CSRF token if required.
- Go + API key: identify seed/setup path for static or generated API keys.

## Rules
- Generate executable-style steps, not abstract advice.
- If multiple auth modes exist, choose the one most suitable for CI and explain why.
- If auth is infeasible, say `bootstrap_feasible: false` in the summary and explain the blocker.
