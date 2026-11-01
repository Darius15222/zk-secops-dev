# Security Policy

## Reporting

Report vulnerabilities privately through GitHub Security Advisories ("Report a vulnerability" on the repository). Do not open public issues for security problems.

## Scope

All repositories of the zk-secops lab: this workspace, `zk-auth`, `zk-platform`, `zk-detections`. `zk-auth` is a lab prototype, not a production authentication service.

## Guarantees

| Risk | Guarantee |
|---|---|
| R-01 | `main` changes only through pull requests with passing checks |
| R-02 | Secrets are never stored in plaintext in git; only SOPS ciphertext |
| R-03 | Images, actions, providers and hooks are pinned by digest or commit SHA |
| R-06 | The AI assistant cannot read secrets or run destructive commands (`.claude/hooks/guard.sh`) |

Details and evidence: `RISK-REGISTER.md`.
