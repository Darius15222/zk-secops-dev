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
| R-03 | Images are pinned by digest, actions and hooks by commit SHA, providers and charts by exact version with a committed lock file; the deployed zk-auth image must carry the signature of zk-auth CI |
| R-06 | The AI assistant runs shell commands in a sandbox that cannot read secret paths or reach unlisted hosts; permission deny rules cover its file tools; no command is excluded from it, so docker, the cluster and the GitHub login are out of its reach (the user runs those); `.claude/hooks/guard.sh` blocks destructive commands as a second layer |

Details and evidence: `RISK-REGISTER.md`.
