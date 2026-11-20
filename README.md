# zk-secops

A small security operations lab. It has three parts:

- an authentication service with zero-knowledge (Schnorr) login;
- a self-hosted Elastic SIEM that watches it;
- the detection rules that turn its logs into alerts.

Everything runs on one machine in a k3d cluster, deployed with Terraform. Every security control in the lab is listed with its proof in [RISK-REGISTER.md](RISK-REGISTER.md).

This repository (`zk-secops-dev`) is the workspace that ties the lab together. It holds the shared rules, docs, evidence and the guardrails for the AI assistant (Claude Code) that works on the code. The code itself lives in three separate repositories.

## Repositories

| Repository | What it does | Main technologies |
|---|---|---|
| [zk-auth](https://github.com/Darius15222/zk-auth) | The monitored application. It offers two logins: Schnorr zero-knowledge (`/login/zk`) and a bcrypt password baseline (`/login/password`). Every decision is logged as one ECS JSON line. | Node.js 26 + TypeScript, `@noble/curves`, bcryptjs, distroless image |
| [zk-platform](https://github.com/Darius15222/zk-platform) | Infrastructure as code. It deploys onto the k3d cluster: TLS, Elasticsearch and Kibana, log collection, the Suricata IDS, zk-auth, network policies and the GitHub repository rulesets. | Terraform, k3d/k3s, ECK, cert-manager, Elastic Agent, Logstash, Suricata, SOPS + age |
| [zk-detections](https://github.com/Darius15222/zk-detections) | Detection as code: the Logstash pipeline that maps Suricata to ECS, the Suricata rules, the Sigma rules (compiled to Elastic ES\|QL), a Kibana dashboard and the runbooks. | Logstash, Suricata, Sigma (sigma-cli), Python unittest |

How they connect:

```
zk-auth ── CI: test, scan, sign image (cosign) ──> GHCR ── PR with the new digest ──> zk-platform
zk-detections ── pipelines, Suricata and Sigma rules ──> zk-platform (read from the sibling checkout)
zk-platform ── Terraform ──> k3d: zk-auth -> logs -> Elastic Agent / Suricata -> Logstash -> Elasticsearch -> Kibana alerts
```

The attack in `zk-platform/scripts/attack.sh` proves the chain end to end. It replays a proof, forges one and guesses passwords, and each detection rule must raise one alert. CI runs it on every zk-platform pull request.

## Workspace layout

```
zk-secops-dev/
├── repos/            the three repositories, each its own git clone (gitignored, see below)
├── .claude/          assistant guardrails: settings.json (sandbox, deny rules), hooks/ (guard.sh, inject-scan.sh), skills/
├── harness/          policies the assistant follows: secrets, pinning, PR flow, risk IDs, untrusted content
├── scripts/          checks for the guardrails: lockdown, red-team cases, sandbox probe
├── local-stack/      up.sh / down.sh: floci (Terraform state), local registry, k3d cluster
├── docs/
│   ├── running-locally/  how to run the lab, lab clone, troubleshooting
│   ├── evidence/         command output that proves each risk is closed (R-01 ... R-09)
│   ├── audit/            the 2026-11 three-round audit
│   ├── templates/        pull request template
│   └── kb/               project knowledge, written by the user only
├── CLAUDE.md         entry point for the assistant: repositories, triggers, sandbox model, commands
├── RISK-REGISTER.md  every risk, its control and its evidence
└── SECURITY.md       reporting and guarantees
```

### Why `repos/` is gitignored

Each of the three projects has its own history, CI, rulesets and release cycle. So they stay independent repositories, cloned side by side under `repos/`:

```bash
for r in zk-auth zk-platform zk-detections; do git clone git@github.com:Darius15222/$r.git repos/$r; done
```

The workspace does not track them: no submodules, no monorepo. A change to a project is reviewed in that project's pull request. The workspace keeps only what spans all three: rules, guardrails, evidence and the risk register. zk-platform expects the siblings in this layout (`../zk-detections`, `../zk-auth`, `../../local-stack`).

## Running the lab

Prerequisites and every `make` target are in [docs/running-locally/local-stack.md](docs/running-locally/local-stack.md). In short, from a lab clone (see below):

```bash
make -C repos/zk-platform up       # cluster, SIEM, zk-auth, detection rules
make -C repos/zk-platform attack   # simulated attack, waits for one alert per rule
make -C repos/zk-platform triage   # read-only JSON of recent alerts
make -C repos/zk-platform down
```

Kibana is at `https://kibana.zk.local`, zk-auth at `https://auth.zk.local`. Both listen on `127.0.0.1` only.

## Working with the AI assistant

Claude Code works on this workspace inside guardrails it cannot change (R-06):

- **Sandbox.** Every shell command runs in a bubblewrap sandbox. It cannot read secrets, cannot reach hosts outside an allowlist, and cannot write any `.git`, `.claude/` or `docs/kb/`.
- **The user acts outside the sandbox.** The user commits, pushes, opens and merges PRs, and runs the lab with the `!` prefix. Lab commands run from a separate clone (`~/zk-lab-run`) that only receives merged code. That way nothing the assistant writes can run outside the sandbox without first going through review.
- **Hooks.** `guard.sh` blocks destructive commands as a second layer. `inject-scan.sh` flags prompt injection in tool output.

[CLAUDE.md](CLAUDE.md) has the details. `scripts/claude-lockdown.sh` and `scripts/claude-sandbox-probe.sh` prove the guardrails hold.

## Security controls

| ID | Risk | Control |
|---|---|---|
| R-01 | Unreviewed changes reach `main` | GitHub rulesets managed by Terraform |
| R-02 | Plaintext secrets | SOPS + age, gitleaks |
| R-03 | Supply chain | Pins by digest/SHA, Trivy, SBOM, cosign signatures, Renovate/Dependabot |
| R-04 | Events not collected | Elastic Agent, Suricata, Logstash ECS pipelines |
| R-05 | Attacks on login undetected | Sigma rules in Elastic Security, dashboard |
| R-06 | AI assistant misuse | Sandbox, deny rules, hooks |
| R-07 | Password guessing | Lockout in zk-auth |
| R-08 | Lateral access to the SIEM | NetworkPolicy in `siem` |
| R-09 | AI reading untrusted content | Diff-only AI review in CI, read-only triage |

Each control's evidence and status: [RISK-REGISTER.md](RISK-REGISTER.md).
