# Threat Model

## Assets
- GitHub repository contents
- CI runner trust boundary
- DAST report integrity
- Base seed data integrity
- Optional PR-supplied overlay SQL

## Attack Vectors
### Poisoned seed or overlay data
Risk:
- PR attempts to smuggle destructive or exfiltrating SQL through `overlay.sql`.
Mitigation:
- AST-based overlay validation
- Additive-only policy
- Explicit function and statement blacklist

### Poisoned application code/image
Risk:
- PR image contains malicious behavior during DAST execution.
Mitigation:
- Separate trusted `workflow_run` lane
- Artifact handoff instead of direct write-authority reuse
- Read-only/report-separated runner model
- Container hardening flags

### Container escape or excessive runtime capability
Risk:
- Untrusted app abuses container capabilities during scan.
Mitigation:
- `--cap-drop=ALL`
- `no-new-privileges`
- read-only filesystem
- tmpfs for `/tmp`
- pids/memory constraints
- isolated Docker network

### Token/session hijacking inside scan lane
Risk:
- Auth bootstrap token is reused or leaked.
Mitigation:
- Throwaway test identities
- local scan-time token generation
- no privileged repository write in the scan job

### ZAP/network exfiltration
Risk:
- Scan tooling attempts outbound network access.
Mitigation:
- app/db/zap run on Docker `--internal` network
- runner remains outside the isolated network for artifact/report handling

## Fork PR Behavior
Fork PRs are intentionally not given the same trusted DAST path until code is merged or otherwise handled by trusted workflow conditions. This is a deliberate trade-off in favor of repository safety.

## Residual Risk
- Hypervisor/runtime escape remains a platform-level concern outside repo control.
- Trusted images such as ZAP are still external dependencies, even when pinned.
- Workflow logic errors can still weaken intended isolation if later edits bypass the trusted/untrusted split.
