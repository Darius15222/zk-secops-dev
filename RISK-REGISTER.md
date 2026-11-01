# Risk Register

Each row is one risk, the control that closes it and the evidence that proves it. Status: Open, Implemented (control exists), Verified (evidence in `docs/evidence/`).

| ID | Risk | Control | Evidence | Status |
|---|---|---|---|---|
| R-01 | Unreviewed changes reach `main` | GitHub ruleset per repo, managed by Terraform (`zk-platform/github`): PR required, no force-push, no deletion | `terraform plan` output, ruleset screenshot | Open |
| R-02 | Plaintext secrets in git or on disk | SOPS + age, `.gitignore`, gitleaks in pre-commit and CI | `git log -p` shows only `ENC[...]`, gitleaks report | Open |
| R-03 | Supply chain: mutable tags, unsigned images | Pin by SHA/digest, Trivy, SBOM (syft), cosign signatures | CI run, `cosign verify` output | Open |
| R-04 | Security events not collected | Elastic Agent, Suricata, Logstash ECS pipelines with tests | pytest run, events in Kibana | Open |
| R-05 | Attacks on authentication go undetected | Sigma rules for brute force and proof replay, loaded into Elastic Security | Alert screenshot | Open |
| R-06 | AI assistant leaks secrets, runs destructive commands or follows injected instructions | `.claude/settings.json` deny rules, `guard.sh`, `inject-scan.sh` | `scripts/claude-lockdown.sh` output | Open |
