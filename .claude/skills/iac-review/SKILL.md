---
name: iac-review
description: Review a Terraform change in zk-platform for risk before it is applied. Use when the user asks to review IaC, before merging a zk-platform PR, or when a plan shows destroys or replacements.
---

# IaC review

1. Static checks in `repos/zk-platform`: `terraform fmt -check -recursive`, `terraform validate` per root, `tflint --recursive`, `checkov -d . --framework terraform --quiet --compact`.
2. Plan the affected root: `make plan` (`envs/local`), `make github-plan` (`github`), or `terraform -chdir=envs/detections plan`.
3. Summarize the plan as a table: resource, action (create, update, replace, destroy), risk.
4. Flag, in this order:
   - any destroy or replace, and whether data is lost (Elasticsearch volume, state, repositories have `prevent_destroy`);
   - security context loosened: privileged, host network or paths, added capabilities, `run_as_user = 0`, writable root filesystem;
   - a new `checkov:skip` without a concrete reason;
   - images or charts not pinned (digest for images, exact version for charts and providers);
   - secrets in plain values instead of SOPS or the CI-only `zk_admin_password` variable;
   - ruleset changes that weaken R-01 (fewer required checks, approvals, bypass actors).
5. Verdict: safe to apply, apply with care (say what to watch), or do not apply.

## Rules

- Review only. Applying is the user's action (`make up`, `make github-apply`); `guard.sh` blocks `terraform apply` outside `envs/local` and every `destroy`.
