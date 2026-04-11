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

### Model 1 Adapter Selection
State which of the four bundled ZeroDAST adapters to use:

| Adapter | When to use |
| --- | --- |
| `json-token-login` | JSON POST login returning a token field (JWT, API key) |
| `form-cookie-login` | Form POST login returning a Set-Cookie session |
| `json-session-login` | JSON POST login returning a session ID field |
| `form-urlencoded-token-login` | Form-urlencoded POST returning a token (OAuth2 password grant) |

If none of the four fit, state `custom` and explain what would need to change.

### Model 1 config.json Auth Block
Emit the exact JSON block that should be placed in the `"auth"` section of `zerodast/config.json`:

```json
{
  "adapter": "<adapter-name>",
  "loginPath": "<login-endpoint-path>",
  "contentType": "<application/json or application/x-www-form-urlencoded>",
  "emailField": "<field-name-for-email-or-username>",
  "passwordField": "<field-name-for-password>",
  "responseTokenField": "<field-name-in-response-containing-token>",
  "headerName": "<header-name, e.g. Authorization or xc-auth>",
  "headerPrefix": "<prefix, e.g. 'Bearer ' or empty string>",
  "user": {
    "email": "<placeholder>",
    "password": "<placeholder>"
  },
  "admin": {
    "email": "<placeholder>",
    "password": "<placeholder>"
  },
  "protectedRoute": {
    "path": "<an-authenticated-endpoint>",
    "expectedStatus": 200
  },
  "adminRoute": {
    "path": "<an-admin-only-endpoint>",
    "expectedStatus": 200
  }
}
```

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
