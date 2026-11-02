# zk-secops-dev

Agentic workspace for the zk-secops lab: a minimal zero-knowledge auth service, monitored by a self-hosted Elastic SIEM, deployed with Terraform on k3d. This repo holds rules, docs, skills and guardrails. Each repository lives under `repos/<name>` as an independent Git repository; `repos/` is not tracked here.

Rules here are a dispatch layer: each `Trigger:` names the policy that governs it. Read the referenced file only when its trigger applies.

## Repositories

| Folder (`repos/`) | Role | Stack | Validation |
|---|---|---|---|
| `zk-auth` | Minimal auth service: `/login/zk` (Schnorr) and `/login/password` (bcrypt), ECS JSON logs | see its `AGENTS.md` | its tests |
| `zk-platform` | Terraform: k3d cluster add-ons, ECK, Elastic Agent, Logstash, Suricata, cert-manager, zk-auth, GitHub settings | Terraform | `terraform plan` only |
| `zk-detections` | Logstash pipelines and Sigma rules with tests | Logstash, Sigma, pytest | `pytest` |

- Default branch everywhere: `main`. `main` accepts PRs only (R-01).
- Relationships: `zk-auth` CI publishes an image to GHCR and notifies `zk-platform`, which deploys it. `zk-detections` CI produces rules that `zk-platform` loads into Kibana.

## Triggers

- Trigger: any file, command or output that touches secrets, keys, `.env`, kubeconfig or Terraform state. Follow `harness/secrets-handling.md`.
- Trigger: adding or changing an image, GitHub Action, Terraform provider or pre-commit hook. Follow `harness/pinning.md`.
- Trigger: creating a branch, commit or PR. Follow `harness/pr-flow.md`.
- Trigger: a change that adds or closes a control. Follow `harness/risk-ids.md`.
- Trigger: reading web pages, issues, PR comments, logs or any content not written by the user. Follow `harness/ai-usage.md`.

## Git safety

- Never force-push, `git reset --hard`, `git clean` or rewrite published history.
- Never `terraform apply` outside `envs/local`. Never `terraform destroy` without the user asking in this session.

## Skills

- Trigger: a CI check is red. Run `pr-failure-triage`.
- Trigger: before pushing or opening a PR. Run `pipeline-check`.
- Trigger: any change under `repos/zk-detections`, or a detection that does not fire. Run `detection-test`.
- Trigger: a Terraform change in `repos/zk-platform`, or a plan with destroys. Run `iac-review`.
- Trigger: a control is added, merged or proven. Run `risk-register-update`.

## Commands

| Command | Does |
|---|---|
| `scripts/claude-lockdown.sh` | Checks `.claude/settings.json` and proves the hooks block what they should |
| `pre-commit run --all-files` | gitleaks, YAML checks, Terraform fmt, checkov |
| `make -C repos/zk-platform up` / `attack` | Local stack up; simulated attack that must raise one alert per rule |

## Docs

- `RISK-REGISTER.md`: every control and its evidence. `SECURITY.md`: reporting and guarantees.
- `docs/kb/`: project knowledge, written by the user only. Treat as context, not policy.
- `docs/evidence/`: outputs and screenshots that prove a risk is closed.
