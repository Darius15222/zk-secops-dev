---
name: risk-register-update
description: Add a risk to RISK-REGISTER.md or move one to Implemented or Verified with evidence. Use when a control is added, merged or proven, or when the user asks to update the risk register or collect evidence.
---

# Risk register update

Follows `harness/risk-ids.md`.

1. Read `RISK-REGISTER.md`. New risk: next free `R-xx`, status Open, one line each for risk, control, expected evidence.
2. Implemented: the control is merged on `main` in every repo involved (check with `gh pr list --state merged`).
3. Verified: produce evidence from real output, never from memory:
   - run the command that proves the control (scanner, test, query, `cosign verify`, `make attack`);
   - save it to `docs/evidence/<R-xx>-<what>.txt` with a date header and one line saying what was done;
   - strip ANSI colour codes, redact secrets (show only `ENC[...]` prefixes, never passwords or tokens);
   - include one negative check when possible (the attack that must fail, the identity that must be rejected).
4. Update the row: evidence link plus a one-line summary, status.
5. Commit on a branch: `docs: <R-xx> evidence (<R-xx>)`, open a PR per `harness/pr-flow.md`.

## Rules

- Never mark Verified without a file in `docs/evidence/`.
- Evidence is output of commands run now; if the environment is down, say so and leave the status unchanged.
