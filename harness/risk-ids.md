# Risk IDs

## Policy

`RISK-REGISTER.md` is the spine of the lab. Every control traces to a risk ID, and every risk marked Verified has evidence.

## Execution Rules

- Each commit and PR that adds or changes a control names its risk ID (`R-xx`).
- New risk: add a row with the next free ID, status Open.
- Implemented: the control is merged. Verified: evidence is saved in `docs/evidence/<risk-id>-<what>.{txt,png}` and linked in the row.
- Never mark Verified without a file in `docs/evidence/`.
