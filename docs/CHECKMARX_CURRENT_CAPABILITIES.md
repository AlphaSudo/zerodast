# Checkmarx DAST Current Public Capability Inventory

## Purpose

This document is a **public-docs-based capability inventory** for Checkmarx DAST.

It is intended to mirror [CURRENT_CAPABILITIES.md](C:/Java%20Developer/DAST/docs/CURRENT_CAPABILITIES.md), but with an important limitation:

- this inventory is based on **official public Checkmarx documentation and product pages**
- it is **not** based on private Checkmarx implementation details
- it should be treated as a view of **documented capability**, not an internal architecture audit

## Scope Boundary

This file does **not** claim insight into:
- private engine internals
- proprietary heuristics
- private deployment architecture
- non-public roadmap commitments
- non-public feature flags or enterprise-only custom behavior

It describes what Checkmarx publicly documents today for DAST and closely related DAST platform features.

## What Checkmarx DAST Is Publicly Documented As

Checkmarx publicly describes DAST as a language-agnostic dynamic application security testing tool within the Checkmarx One platform, intended to scan running web applications and APIs as part of CI/CD and runtime-oriented security workflows.

Primary public references:
- [Checkmarx DAST docs](https://docs.checkmarx.com/en/34965-433898-checkmarx-dast.html)
- [Checkmarx DAST product page](https://checkmarx.com/checkmarx-dast/)

## High-Level Coverage Map

| Area | Publicly Documented State |
| --- | --- |
| Runtime / black-box DAST | Implemented |
| CI/CD integration | Implemented |
| Environment-based scanning model | Implemented |
| API scanning | Implemented |
| OpenAPI / API file support | Implemented |
| Web scanning | Implemented |
| Multiple auth modes | Implemented |
| Scripted / ZEST-based auth flows | Implemented |
| TOTP support | Implemented in limited form |
| Result triage / state updates | Implemented |
| Alerts and path-based result views | Implemented |
| Group / permission model | Implemented |
| DAST-specific permissions | Implemented |
| API inventory / API security integration | Implemented via Checkmarx API Security |
| Shadow / zombie API discovery | Publicly claimed in API Security offering |
| ASPM / cross-signal correlation | Publicly claimed at platform level |
| Full internal engine architecture details | Not publicly documented |

## Public Capability Details

## A. Runtime DAST / Black-Box Testing

### Status
Publicly documented as implemented.

### What is publicly stated
Checkmarx DAST is described as a dynamic testing tool that scans running web applications and APIs and is used to identify runtime vulnerabilities, configuration issues, and authentication/encryption issues.

Sources:
- [Checkmarx DAST docs](https://docs.checkmarx.com/en/34965-433898-checkmarx-dast.html)
- [Checkmarx DAST product page](https://checkmarx.com/checkmarx-dast/)

## B. CI/CD Integration

### Status
Publicly documented as implemented.

### What is publicly documented
Checkmarx provides documented CI/CD integration paths and a DAST CLI / Docker image workflow for multiple platforms, including pipeline execution examples.

Supported examples in public docs include:
- Azure DevOps
- Bamboo
- Bitbucket Pipelines
- CircleCI
- Docker-based pipeline usage
- Jenkins
- TeamCity
- TravisCI

Sources:
- [Installing the DAST CLI in a Pipeline](https://docs.checkmarx.com/en/34965-154704-dast-installing-the-dast-cli-in-a-pipeline.html)
- [Using the DAST CLI](https://docs.checkmarx.com/en/34965-501341-using-the-dast-cli.html)

## C. Environment-Based Scanning Model

### Status
Publicly documented as implemented.

### What is publicly documented
Checkmarx DAST uses an environment model where a scan is associated with an environment representing the target URL or API source, with tags and group assignments.

Documented environment concepts include:
- environment name
- URL / API source
- tags
- group assignments
- environment-linked scan history and results

Source:
- [Creating Environments](https://docs.checkmarx.com/en/34965-154695-dast-creating-environments.html)

## D. API Scanning

### Status
Publicly documented as implemented.

### What is publicly documented
Checkmarx DAST publicly documents API scanning support and requires selecting the file type containing the endpoints to test for API environments.

The public CLI docs also show API scanning with file-based inputs such as OpenAPI, Postman, or HAR-style flows.

Sources:
- [Running a Scan](https://docs.checkmarx.com/en/34965-154700-dast-running-a-scan.html)
- [Using the DAST CLI](https://docs.checkmarx.com/en/34965-501341-using-the-dast-cli.html)

## E. Web Scanning

### Status
Publicly documented as implemented.

### What is publicly documented
The DAST CLI exposes dedicated web scanning commands, and public pipeline examples include web application scanning.

Source:
- [Using the DAST CLI](https://docs.checkmarx.com/en/34965-501341-using-the-dast-cli.html)

## F. Authentication Support

### Status
Publicly documented as implemented, with explicit supported and unsupported modes.

### Publicly documented supported auth types
Checkmarx documents support for:
- no authentication
- form-based authentication
- JSON-based authentication
- Basic HTTP / NTLM authentication
- SSO using custom scripts
- multi-step authentication using custom scripts
- SSO using ZEST scripts from the ZAP browser extension
- multi-step authentication using ZEST scripts from the ZAP browser extension
- TOTP-based MFA in limited onboarding-wizard-driven form

### Publicly documented unsupported auth types
Checkmarx documents that some auth types are not supported, including examples such as:
- dynamic credentials
- CAPTCHA authentication
- pop-up authentication
- some encryption/decryption-dependent auth flows
- some OTP/MFA variants beyond the documented supported case

### Additional documented auth capability
Checkmarx documents an **Authentication Report** that shows authentication status, screenshots, and step-by-step login details for an environment.

Source:
- [Authentication Support](https://docs.checkmarx.com/en/34965-433921-authentication-support.html)

## G. CLI / Docker Execution Model

### Status
Publicly documented as implemented.

### What is publicly documented
Checkmarx publishes a DAST CLI and Docker-image-based execution model.

Documented CLI commands include:
- `scan`
- `web`
- `api`
- `setup`
- `version`

The CLI docs also describe:
- required authentication to Checkmarx One
- environment IDs
- config file settings
- custom headers
- session management
- scan options
- automation scripts
- correlation scan settings

Source:
- [Using the DAST CLI](https://docs.checkmarx.com/en/34965-501341-using-the-dast-cli.html)

## H. Results, Alerts, Paths, and Scan History

### Status
Publicly documented as implemented.

### What is publicly documented
Checkmarx exposes DAST results through environment-linked views that include:
- alerts view
- paths view
- results table
- site tree
- scan history
- partial / failed / completed scan distinction
- downloadable scan logs

Documented result attributes include:
- severity
- vulnerability type
- instances
- compliance markers
- state
- status
- notes

Source:
- [Viewing Results](https://docs.checkmarx.com/en/34965-154701-dast-viewing-results.html)

## I. Triage / Result State Management

### Status
Publicly documented as implemented.

### What is publicly documented
Public docs show that results can be triaged and updated, including state/severity/comment-style adjustments in the wider Checkmarx One model.

For DAST specifically, permissions exist for updating results and result states.

Sources:
- [Viewing Results](https://docs.checkmarx.com/en/34965-154701-dast-viewing-results.html)
- [DAST Permissions](https://docs.checkmarx.com/en/34965-438667-dast-permissions.html)

## J. Permissions / RBAC Surface

### Status
Publicly documented as implemented.

### What is publicly documented
Checkmarx documents DAST-specific permissions such as:
- `dast-admin`
- `dast-create-environment`
- `dast-create-scan`
- `dast-update-scan`
- `dast-update-results`
- `dast-update-result-severity`
- `dast-update-result-states`
- `dast-cancel-scan`
- `dast-delete-scan`
- `dast-delete-environment`
- `dast-view-environments`
- `dast-external-scans`

It also documents group assignment to environments and role assignment to groups within the broader platform.

Sources:
- [DAST Permissions](https://docs.checkmarx.com/en/34965-438667-dast-permissions.html)
- [Managing Groups](https://docs.checkmarx.com/en/34965-68602-managing-groups.html)
- [Creating Environments](https://docs.checkmarx.com/en/34965-154695-dast-creating-environments.html)

## K. API Security Platform Integration

### Status
Publicly claimed / documented at product level.

### What is publicly stated
Checkmarx API Security publicly claims:
- global API inventory
- API discovery
- API documentation scanning
- API change tracking
- DAST integration into that API inventory layer

Public materials also claim discovery of shadow and zombie APIs through the API Security product.

Sources:
- [Checkmarx API Security](https://checkmarx.com/product/api-security/)
- [Checkmarx API Security knowledge hub](https://checkmarx.com/learn/api-security/)

### Important nuance
This is broader than standalone DAST and belongs to the wider Checkmarx platform story, not just the bare DAST engine.

## L. Platform-Level Correlation / ASPM Story

### Status
Publicly claimed at product/platform level.

### What is publicly stated
Checkmarx publicly markets unified platform capabilities across scanners and broader application security signals, including platform-level correlation and posture-management-style workflows.

Relevant public references:
- [Checkmarx DAST product page](https://checkmarx.com/checkmarx-dast/)
- [Checkmarx API Security](https://checkmarx.com/product/api-security/)

### Important nuance
Public marketing and product documentation clearly indicate platform-level correlation direction, but this file does not claim detailed internal parity or private implementation specifics.

## M. Operational Safety / Usage Constraints

### Status
Publicly documented.

### What is publicly documented
Checkmarx explicitly publishes an Acceptable Use Policy for DAST and warns against unauthorized or unsafe scanning behavior, including scanning systems not owned or controlled by the customer or scanning live production without authorization.

Source:
- [Checkmarx DAST docs](https://docs.checkmarx.com/en/34965-433898-checkmarx-dast.html)

## N. What Public Docs Strongly Suggest Checkmarx Has That ZeroDAST Does Not Yet Have

Based on public documentation, Checkmarx clearly has or strongly presents the following classes of capability beyond current ZeroDAST:

- richer auth coverage breadth
- environment-centric management model
- explicit DAST permissions and RBAC surface
- result-state and triage model at platform scale
- broader CI/CD packaging and official pipeline patterns
- wider platform integration story across scanners and API inventory

## O. What Public Docs Do Not Let Us Prove

From public documentation alone, we cannot responsibly conclude:
- private engine heuristics
- exact detection quality relative to competitors
- exact false-positive rates in customer environments
- internal scaling architecture
- private worker/orchestration implementation details
- precise operational latency under enterprise customer load

## P. Practical Summary

### Publicly documented current-state bottom line
Checkmarx DAST publicly presents as a mature enterprise DAST offering with:
- runtime DAST
- environment-based management
- CI/CD integration
- API and web scanning
- broad authentication support
- result management and triage
- DAST-specific permissions
- wider platform integration into Checkmarx One

### What this file should be used for
Use this inventory to compare:
- what ZeroDAST implements today in code
- versus what Checkmarx publicly documents as product capability

Use it as a **truthful public-feature comparison baseline**, not as a claim of private insight into Checkmarx internals.

## Sources

Primary official sources used in this file:
- [Checkmarx DAST docs](https://docs.checkmarx.com/en/34965-433898-checkmarx-dast.html)
- [Authentication Support](https://docs.checkmarx.com/en/34965-433921-authentication-support.html)
- [Creating Environments](https://docs.checkmarx.com/en/34965-154695-dast-creating-environments.html)
- [Running a Scan](https://docs.checkmarx.com/en/34965-154700-dast-running-a-scan.html)
- [Viewing Results](https://docs.checkmarx.com/en/34965-154701-dast-viewing-results.html)
- [Installing the DAST CLI in a Pipeline](https://docs.checkmarx.com/en/34965-154704-dast-installing-the-dast-cli-in-a-pipeline.html)
- [Using the DAST CLI](https://docs.checkmarx.com/en/34965-501341-using-the-dast-cli.html)
- [DAST Permissions](https://docs.checkmarx.com/en/34965-438667-dast-permissions.html)
- [Managing Groups](https://docs.checkmarx.com/en/34965-68602-managing-groups.html)
- [Checkmarx DAST product page](https://checkmarx.com/checkmarx-dast/)
- [Checkmarx API Security](https://checkmarx.com/product/api-security/)
