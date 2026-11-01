# Secrets Handling

## Policy

Secrets exist in git only as SOPS ciphertext (`secrets/*.enc.yaml`). Plaintext secrets, private keys, age keys, kubeconfigs and Terraform state never enter git and are never read by the assistant.

## Execution Rules

- Never read, print, grep, copy or source: `.env`, `.env.*` (except `.env.example`), `*.key`, `keys.txt`, `~/.config/sops/`, `~/.kube/`, kubeconfig files, `*.tfstate`, plaintext files under `secrets/`.
- Never run `sops -d`, `env` or `printenv`. Decryption happens only inside `make` targets the user runs.
- New secret: the user encrypts it with `sops --encrypt`; the assistant only writes the `.sops.yaml` rule and the code that consumes the decrypted value.
- A new secret-bearing path must be added to `.gitignore`, `.claude/settings.json` deny rules and `.claude/hooks/guard.sh` in the same change.
- If a secret appears in output or a diff, stop and tell the user; do not repeat it.
