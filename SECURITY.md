# Security Policy

## Reporting a Vulnerability

If you discover a security issue in ZeroDAST itself, please report it privately before opening a public issue.

Preferred process:
- Email the maintainer or repository owner directly if a contact is available.
- If private contact details are not yet published, open a GitHub issue only for non-sensitive security hardening questions, not for exploit details or secrets.

Please include:
- a clear description of the issue
- affected files, workflow, or component
- reproduction steps
- impact assessment
- suggested remediation if available

## Scope

This repository intentionally contains a demo application with vulnerable endpoints used to validate DAST behavior. Findings in the demo app are expected unless they fall outside the documented intentional vulnerability surfaces.

Expected intentional demo findings include:
- SQL Injection
- Cross Site Scripting
- IDOR / authorization bypass behavior
- Application Error Disclosure

Security reports that are in scope for this repository include:
- workflow privilege boundary failures
- overlay validator bypasses
- unsafe trusted/untrusted artifact handling
- container isolation or hardening regressions
- secrets exposure in workflows or scripts
- vulnerabilities in the adaptation or verification tooling itself

## Supported Versions

This project is currently pre-1.0 and under active development.

| Version | Supported |
| --- | --- |
| 0.1.x | Yes |
| < 0.1.0 | No |

## Hardening Notes

Before public deployment or broader reuse:
- replace placeholder action SHAs with pinned, reviewed SHAs where required
- validate fork PR behavior in GitHub Actions
- rerun local and CI DAST verification after dependency or workflow changes
- never deploy the demo app to a production environment
