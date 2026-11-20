---
name: pipeline-check
description: Run the same checks CI runs, locally, before pushing a zk-secops change. Use before opening a PR, after editing a workflow, or when the user asks to "check" or "validate" a repo.
---

# Pipeline check

Run in the repo that changed (`repos/<name>`), report pass or fail per step, stop at the first failure and show its output. Steps marked `!` need docker, the cluster or a GitHub login, which the sandbox does not reach: give the user the exact command to run with `!`, or leave them to CI.

| Repo | Steps |
|---|---|
| any | `pre-commit run --all-files` |
| `zk-auth` | `npm test`, `! docker build -t zk-auth:dev .` |
| `zk-detections` | `python3 tests/test_suricata.py -v`, `rules/build.sh` then `git diff --exit-code rules/elastic/` |
| `zk-platform` | `terraform fmt -check -recursive`, `terraform -chdir=<root> validate` for `github`, `envs/local`, `envs/detections`; `! make plan` (local stack must be up); `! cosign verify <image> --certificate-oidc-issuer https://token.actions.githubusercontent.com --certificate-identity https://github.com/<owner>/zk-auth/.github/workflows/ci.yml@refs/heads/main` for a changed `zk_auth_image` (the same check as CI lint) |
| workspace | `scripts/claude-lockdown.sh` |

For a workflow change, also check:

- every `uses:` is pinned to a 40-character SHA with a version comment (`harness/pinning.md`);
- every job has an explicit `permissions:` block;
- `actions/checkout` has `persist-credentials: false`;
- no `${{ github.event.* }}` value is interpolated directly into `run:` (pass it through `env:`).

## Rules

- Read-only: never `terraform apply`, push or merge from this skill.
- `rules/build.sh` needs sigma-cli: `pip install --require-hashes -r requirements-sigma.txt` in a venv.
