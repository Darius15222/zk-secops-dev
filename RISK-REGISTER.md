# Risk Register

Each row is one risk, the control that closes it and the evidence that proves it. Status: Open, Implemented (control exists), Verified (evidence in `docs/evidence/`).

| ID | Risk | Control | Evidence | Status |
|---|---|---|---|---|
| R-01 | Unreviewed changes reach `main` | GitHub ruleset per repo, managed by Terraform (`zk-platform/github`): PR required, no force-push, no deletion | [R-01-ruleset.txt](docs/evidence/R-01-ruleset.txt): no drift, direct push rejected (GH013) | Verified |
| R-02 | Plaintext secrets in git or on disk | SOPS + age, `.gitignore`, gitleaks in pre-commit and CI | [R-02-secrets-tls.txt](docs/evidence/R-02-secrets-tls.txt): ciphertext only in git, `make down && make up` twice, TLS chain valid | Verified |
| R-03 | Supply chain: mutable tags, unsigned images | Pin by SHA/digest, Trivy, SBOM (syft), cosign signatures | [R-03-supply-chain.txt](docs/evidence/R-03-supply-chain.txt): signature and SBOM attestation verified, wrong identity rejected, 6/6 actions SHA-pinned | Verified |
| R-04 | Security events not collected | Elastic Agent, Suricata, Logstash ECS pipelines with tests | [R-04-telemetry.txt](docs/evidence/R-04-telemetry.txt): zk-auth and Suricata events in Elasticsearch with ECS mappings, pipeline tests green | Verified |
| R-05 | Attacks on authentication go undetected | Sigma rules for brute force and proof replay, loaded into Elastic Security | [R-05-detections.txt](docs/evidence/R-05-detections.txt): 4 Sigma rules loaded, one alert per rule after a replayed attack | Verified |
| R-06 | AI assistant leaks secrets, runs destructive commands or follows injected instructions | `.claude/settings.json` deny rules, `guard.sh`, `inject-scan.sh` | [R-06-guardrails.txt](docs/evidence/R-06-guardrails.txt): 32 checks pass, live agent blocked on `cat .env` | Verified |
