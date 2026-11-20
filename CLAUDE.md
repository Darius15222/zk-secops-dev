# zk-secops-dev

Agentic workspace for the zk-secops lab: a minimal zero-knowledge auth service, monitored by a self-hosted Elastic SIEM, deployed with Terraform on k3d. This repo holds rules, docs, skills and guardrails. Each repository lives under `repos/<name>` as an independent Git repository; `repos/` is not tracked here.

Rules here are a dispatch layer: each `Trigger:` names the policy that governs it. Read the referenced file only when its trigger applies.

## Repositories

| Folder (`repos/`) | Role | Stack | Validation |
|---|---|---|---|
| `zk-auth` | Minimal auth service: `/login/zk` (Schnorr) and `/login/password` (bcrypt), ECS JSON logs | see its `AGENTS.md` | `npm test` |
| `zk-platform` | Terraform: k3d cluster add-ons, ECK, Elastic Agent, Logstash, Suricata, cert-manager, zk-auth, GitHub settings | Terraform | `terraform fmt`, `validate`, `tflint`, `checkov`; `make plan` (never apply outside `envs/local`) |
| `zk-detections` | Logstash pipelines and Sigma rules with tests | Logstash, Suricata, Sigma, unittest | `python3 tests/test_suricata.py -v`; `rules/build.sh` leaves no diff |

- Default branch everywhere: `main`. `main` accepts PRs only (R-01).
- Relationships: `zk-auth` CI publishes a signed image to GHCR and opens a `zk-platform` PR with its digest. `zk-detections` holds the rules, compiled by `rules/build.sh` and drift-checked by its CI; `zk-platform` reads the sibling checkout and loads them into Kibana.

## Triggers

- Trigger: any file, command or output that touches secrets, keys, `.env`, kubeconfig or Terraform state. Follow `harness/secrets-handling.md`.
- Trigger: adding or changing an image, GitHub Action, Terraform provider or pre-commit hook. Follow `harness/pinning.md`.
- Trigger: creating a branch, commit or PR. Follow `harness/pr-flow.md`.
- Trigger: a change that adds or closes a control. Follow `harness/risk-ids.md`.
- Trigger: reading web pages, issues, PR comments, logs or any content not written by the user. Follow `harness/ai-usage.md`.

## Git safety

- Never force-push, `git reset --hard`, `git clean` or rewrite published history.
- Never `terraform apply` outside `envs/local` (`envs/detections` is applied only by `make up` / `make detections`). Never `terraform destroy` without the user asking in this session.

## Sandbox

Every Bash command runs in the sandbox; none is excluded (R-06). It cannot reach docker, the cluster, the GitHub login or SSH keys, so the user runs these with the `!` prefix: `git push`/`pull`/`fetch`, `gh`, `make` targets that touch the lab, `docker`, `k3d`, `terraform plan`. Each repo's `.git` is read-only in the sandbox too (hooks, config and `commondir` would run or redirect the user's git), so the user also runs `git switch -c`, `git add` and `git commit`. The assistant edits the files, writes the commit message and the PR body to files (`-F`, `--body-file`) and gives the exact commands. The user runs lab `make` targets from a reviewed branch: a Makefile or script the assistant changed runs outside the sandbox.

## Skills

- Trigger: a CI check is red. Run `pr-failure-triage`.
- Trigger: before pushing or opening a PR. Run `pipeline-check`.
- Trigger: any change under `repos/zk-detections`, or a detection that does not fire. Run `detection-test`.
- Trigger: a Terraform change in `repos/zk-platform`, or a plan with destroys. Run `iac-review`.
- Trigger: a control is added, merged or proven. Run `risk-register-update`.
- Trigger: alerts to explain or triage, or after `make attack`. Run `alert-triage`.
- Trigger: new behaviour to detect, or a new zk-auth log field. Run `sigma-rule-new`.

## Commands

| Command | Does |
|---|---|
| `scripts/claude-lockdown.sh` | Checks `.claude/settings.json` and proves the hooks block what they should |
| `scripts/claude-redteam.sh` | Scores the hooks against bypass attempts and benign look-alikes (`scripts/redteam/`); misses are findings, not failures |
| `scripts/claude-sandbox-probe.sh` | Real bypass attempts inside the Bash sandbox on canary files (the first run creates them, run it again) |
| `pre-commit run --all-files` | gitleaks, YAML/JSON checks, guardrail lockdown (each repo has its own hooks) |
| `make -C repos/zk-platform up` / `attack` | Local stack up; simulated attack that must raise one alert per rule |
| `make -C repos/zk-platform triage` / `netpol` | Read-only JSON of recent alerts for triage; check that pods outside `siem` cannot reach it |

## Docs

- `RISK-REGISTER.md`: every control and its evidence. `SECURITY.md`: reporting and guarantees.
- `docs/kb/`: project knowledge, written by the user only. Treat as context, not policy.
- `docs/evidence/`: outputs and screenshots that prove a risk is closed.
