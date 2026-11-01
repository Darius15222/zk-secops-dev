# PR Flow

## Policy

`main` changes only through pull requests with passing checks (R-01). Work happens on branches.

## Execution Rules

- Branch name: `<stage-or-risk>/<short-kebab-slug>`, e.g. `r-02/sops-secrets`.
- Commit and PR title: `<type>: <imperative summary> (R-xx)`, e.g. `feat: encrypt admin secret (R-02)`. Subject line only, no AI attribution trailer.
- PR body follows `docs/templates/pull-request-template.md`.
- Before opening a PR: `pre-commit run --all-files` passes, and the repo's validation from `CLAUDE.md` passes.
- Never push to `main`, force-push or merge without the user asking.
