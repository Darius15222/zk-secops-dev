---
name: risk-register-update
description: Add a risk to RISK-REGISTER.md or move one to Implemented or Verified with evidence. Use when a control is added, merged or proven, or when the user asks to update the risk register or collect evidence.
---

# Risk register update

Follows `harness/risk-ids.md`.

1. Read `RISK-REGISTER.md`. New risk: next free `R-xx`, status Open, one line each for risk, control, expected evidence.
2. Implemented: the control is merged on `main` in every repo involved (the user checks with `! gh pr list --state merged -R Darius15222/<repo>`).
3. Verified: produce evidence from real output, never from memory:
   - run the command that proves the control (scanner, test, query); one that needs docker, the cluster or GitHub (`cosign verify`, `make attack`) the user runs it with `!` (CLAUDE.md, Sandbox) and saves the output to `.out/`, which the assistant then reads;
   - save it to `docs/evidence/<R-xx>-<what>.txt` with a date header and one line saying what was done;
   - strip ANSI colour codes, redact secrets (show only `ENC[...]` prefixes, never passwords or tokens);
   - include one negative check when possible (the attack that must fail, the identity that must be rejected).
4. Update the row: evidence link plus a one-line summary, status.
5. Write the commit message (`docs: <R-xx> evidence (<R-xx>)`) and the PR body to files and give the user the `!` commands to branch, commit, push and open the PR (`harness/pr-flow.md`).

## Rules

- Never mark Verified without a file in `docs/evidence/`.
- Evidence is output of commands run now; if the environment is down, say so and leave the status unchanged.
