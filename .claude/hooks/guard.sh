#!/usr/bin/env bash
# PreToolUse guardrails (R-06). Reads the hook JSON on stdin; exit 2 blocks the call and shows stderr to the assistant.
# Levels: 1 files (Read/Edit/Write), 2 shell (Bash), 3 network (WebFetch).
set -euo pipefail

in=$(cat)
tool=$(jq -r '.tool_name // ""' <<<"$in")
block() { echo "Blocked by policy (guard.sh): $1. See harness/secrets-handling.md." >&2; exit 2; }

# .env.example is the only allowed .env file; secrets/*.enc.yaml is ciphertext and may be read
secret_re='(^|[/ "'\''=])\.env($|[. "'\''])|\.key($|[ "'\''])|(^|/)keys\.txt|\.config/sops|\.kube/|kubeconfig|\.tfstate'
is_secret() {
  local s=${1//.env.example/}
  grep -qE "$secret_re" <<<"$s" && return 0
  # plaintext under secrets/: any secrets/<file> that is not *.enc.yaml
  grep -oE 'secrets/[^[:space:]"'\'';|&]+' <<<"$s" | grep -qvE '\.enc\.yaml$'
}

case $tool in
  Read|Edit|Write)
    p=$(jq -r '.tool_input.file_path // ""' <<<"$in")
    is_secret "$p" && block "secret path $p"
    # memory-poisoning guard: project knowledge is written by the user only
    [[ $tool != Read && $p == */docs/kb/* ]] && block "docs/kb/ is user-written"
    ;;
  Bash)
    c=$(jq -r '.tool_input.command // ""' <<<"$in")
    cwd=$(jq -r '.cwd // ""' <<<"$in")
    is_secret "$c" && block "command touches a secret path"
    grep -qE '(^|[;&|(` ])(env|printenv)([;&|)` ]|$)' <<<"$c" && block "dumping the environment"
    grep -qE 'sops +(.* )?(-d|--decrypt)' <<<"$c" && block "sops decrypt"
    grep -qE 'git .*push .*(-f|--force)' <<<"$c" && block "force push"
    grep -qE 'git .*(reset +--hard|clean )' <<<"$c" && block "destructive git command"
    grep -qE 'terraform .*destroy' <<<"$c" && block "terraform destroy"
    if grep -qE 'terraform .*apply' <<<"$c" && ! grep -qE 'envs/local' <<<"$c $cwd"; then
      block "terraform apply outside envs/local"
    fi
    grep -qE '(curl|wget)[^|]*\|[[:space:]]*(sudo +)?(ba|z)?sh' <<<"$c" && block "piping a download into a shell"
    ;;
  WebFetch)
    u=$(jq -r '.tool_input.url // ""' <<<"$in")
    host=$(sed -E 's#^[a-z]+://([^/:]+).*#\1#' <<<"$u")
    # ponytail: static allowlist, move to a file if it grows past a screen
    allow='^(.+\.)?(github\.com|githubusercontent\.com|elastic\.co|hashicorp\.com|terraform\.io|kubernetes\.io|cert-manager\.io|k3d\.io|suricata\.io|readthedocs\.io|sigmahq\.io|getsops\.io|anthropic\.com|claude\.com)$'
    grep -qE "$allow" <<<"$host" || block "host $host is not in the WebFetch allowlist"
    ;;
esac
exit 0
