# Pinning

## Policy

Every external dependency that executes code is pinned to an immutable reference. Tags are mutable: a moved tag on a GitHub Action or image runs someone else's code in CI (R-03).

## Execution Rules

| Dependency | Pin as | Example |
|---|---|---|
| GitHub Action | full commit SHA + tag comment | `uses: actions/checkout@<40-char-sha> # v4.2.2` |
| Container image | digest | `docker.elastic.co/elasticsearch/elasticsearch:8.x@sha256:<digest>` |
| Helm chart | exact version | `version = "2.16.0"` |
| Terraform provider | exact version + committed `.terraform.lock.hcl` | `version = "6.6.0"` |
| pre-commit hook | commit SHA in `rev` + tag comment | `rev: 83d9cd6... # v8.30.1` |

- Resolve a SHA with `curl -s https://api.github.com/repos/<owner>/<repo>/commits/<tag> | jq -r .sha` (works in the sandbox for public repos); a digest with `! docker buildx imagetools inspect <image:tag>` (the user runs it).
- Never use `latest`, a major-only tag (`v4`) or a floating branch.
- Bumps arrive as PRs and pass CI like any change. Dependabot (`.github/dependabot.yml`) covers Actions, npm, pip, Dockerfiles and Terraform providers; Renovate (`renovate.json`) covers what Dependabot cannot see: `image:tag@sha256:` strings in workflows, Terraform and tests, and Helm chart versions. The zk-auth image in zk-platform is bumped by zk-auth CI (R-03).
