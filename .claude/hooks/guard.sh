#!/usr/bin/env bash
# PreToolUse guardrails (R-06). Reads the hook JSON on stdin; exit 2 blocks the call and shows stderr to the assistant.
# Levels: 1 files (Read/Edit/Write/Grep/Glob), 2 shell (Bash), 3 network (WebFetch).
# ponytail: text matching only; Bash secret paths are left to the sandbox except for excluded commands. scripts/claude-redteam.sh lists the bypasses it cannot see (globs, encodings, interpreters).
set -euo pipefail

in=$(cat)
tool=$(jq -r '.tool_name // ""' <<<"$in")
block() { echo "Blocked by policy (guard.sh): $1. See harness/secrets-handling.md." >&2; exit 2; }

# .env.example is the only allowed .env file; secrets/*.enc.yaml is ciphertext and secrets/*.md is documentation.
# The credential stores at the end match sandbox.filesystem.denyRead in settings.json.
secret_re='(^|[/ "'\''=])\.env($|[. "'\'':])|\.(key|pem)($|[ "'\''])|(^|/)keys\.txt|\.config/sops|\.kube/|kubeconfig|\.tfstate|\.ssh/|(^|/)id_(rsa|ecdsa|ed25519)|\.aws($|[/ "'\''])|\.git-credentials|\.netrc|\.docker/config\.json|\.claude/\.credentials\.json|credentials\.tfrc\.json'
is_secret() {
  local s=${1//.env.example/}
  grep -qE "$secret_re" <<<"$s" && return 0
  # plaintext under secrets/: any secrets/<file> that is not *.enc.yaml or *.md
  grep -oE 'secrets/[^[:space:]"'\'';|&]+' <<<"$s" | grep -qvE '\.(enc\.yaml|md)$'
}

case $tool in
  Read|Edit|Write|Grep|Glob)
    p=$(jq -r '.tool_input.file_path // .tool_input.path // ""' <<<"$in")
    is_secret "$p" && block "secret path $p"
    # memory-poisoning guard: project knowledge is written by the user only
    [[ $tool == Edit || $tool == Write ]] && [[ $p == */docs/kb/* ]] && block "docs/kb/ is user-written"
    ;;
  Bash)
    c=$(jq -r '.tool_input.command // ""' <<<"$in")
    cwd=$(jq -r '.cwd // ""' <<<"$in")
    # R-06: inside the sandbox the kernel refuses reads of secret paths however the command spells them (sandbox.filesystem
    # in settings.json). The text rule stays only for commands the sandbox lets out (sandbox.excludedCommands); any segment
    # that starts with one, after optional VAR=value prefixes, keeps the rule on for the whole command.
    unsandboxed='(^|[;&|(`]) *([A-Za-z_][A-Za-z0-9_]*=[^ ]* +)*(make|terraform|docker|k3d|gh|git +(push|pull|fetch))( |$)'
    grep -qE "$unsandboxed" <<<"$c" && is_secret "$c" && block "command touches a secret path"
    # the excluded commands must not become a way around the sandbox: options that run arbitrary code or reach the host
    grep -qE 'git[^;&|]* (--(receive|upload)-pack|--exec)([ =]|$)|git[^;&|]* -c +[^ ]*(sshcommand|hookspath|fsmonitor|askpass)=|ext::' <<<"${c,,}" && block "git option that runs a command"
    grep -qE '(^|[;&|(`]) *make[^;&|]* (-f|--file|--makefile|--eval|-E)( |=|$)' <<<"$c" && block "make with a makefile or code the assistant supplies"
    grep -qE 'docker[^;&|]* (--mount|--privileged|--pid[= ]host|--network[= ]host)( |=|$)' <<<"$c" && block "docker option that reaches the host"
    vol_re='docker[^;&|]* (-v|--volume)[ =]+["'\'']?(/|~|\$HOME|\$\{HOME)'
    grep -qE "$vol_re" <<<"$c" && block "docker volume from outside the project (mount \$PWD/... instead)"
    grep -qE 'kubectl[^;&|]* (get|describe|edit)[^;&|]* secrets?([ /]|$)' <<<"$c" && block "reading Kubernetes secrets"
    grep -qE 'k3d[^;&|]* kubeconfig +(get|write|merge)' <<<"$c" && block "printing a cluster config"
    grep -qE 'gh[^;&|]* auth +(token|status[^;&|]* (-t|--show-token))' <<<"$c" && block "printing the GitHub token"
    grep -qE '(^|[ /])github-apply( |$)' <<<"$c" && block "github-apply changes the repository rulesets (R-01); the user runs it"
    # environment dumps: env/printenv as a command (not "kubectl set env"), bare set, export -p, procfs, whole env objects
    grep -qE '(^|[;&|(`]) *(env|printenv)([;&|)` ]|$)' <<<"$c" && block "dumping the environment"
    grep -qE '(^|[;&|(`]) *(set|export +-p|declare +-p)( *[;&|)`]| *$)' <<<"$c" && block "dumping the environment"
    grep -qE '/proc/[^ ]*/environ|os\.environ([^.[]|$)|process\.env([^.[]|$)' <<<"$c" && block "dumping the environment"
    grep -qE 'sops +(.* )?(-d|--decrypt|decrypt|exec-env|exec-file)( |$)' <<<"$c" && block "sops decrypt"
    grep -qE '(^|[ /])show-password( |$)' <<<"$c" && block "make target that decrypts a secret"
    # git push and a force flag in the same command (no ; & | between them), also inside combined short flags (-uf);
    # a -f in a later command is not a force push
    grep -qE 'git[^;&|]* push[^;&|]* (-[a-zA-Z]*f[a-zA-Z]*|--force|--force-with-lease)( |=|$)' <<<"$c" && block "force push"
    # +ref forces, :ref deletes the remote branch
    grep -qE 'git[^;&|]* push[^;&|]* [+:][^ ;&|]' <<<"$c" && block "force push or remote branch delete"
    grep -qE 'git[^;&|]* --no-verify' <<<"$c" && block "skipping the pre-commit scanners"
    grep -qE 'git .*(reset +--hard|clean )' <<<"$c" && block "destructive git command"
    # destroy (or apply -destroy) as a word in the same command as terraform: "destroyed" in a later grep is not a destroy
    grep -qE 'terraform[^;&|]* -?destroy( |$|[;&|)])' <<<"$c" && block "terraform destroy"
    if grep -qE 'terraform .*apply' <<<"$c"; then
      # -chdir names the root that is applied; without it, the root is the last cd target, or the working directory
      chdir=$(grep -oE 'terraform[^;&|]* -chdir=[^ ;&|]+' <<<"$c" | sed -E 's/.*-chdir=//' || true)
      dir=${chdir:-$(grep -oE '(^|[;&|(] *)cd +[^ ;&|)]+' <<<"$c" | tail -1 | sed -E 's/.*cd +//' || true)}
      [[ ${dir:-$cwd} =~ (^|/)envs/local/?$ ]] || block "terraform apply outside envs/local"
    fi
    grep -qE '(curl|wget)[^|]*\|[[:space:]]*(sudo +)?((ba|z)?sh|python[0-9.]*|node|perl|ruby)([^[:alnum:]_-]|$)' <<<"$c" && block "piping a download into an interpreter"
    grep -qE '<\( *(curl|wget) ' <<<"$c" && block "running a download through process substitution"
    # guardrails and project knowledge written through the shell (reading them is fine)
    grep -qE '(>>?|tee( +-a)?) *[^ ;&|]*(\.claude|docs/kb)/|sed +-i[^;&|]*(\.claude|docs/kb)/|(cp|mv|rm|install|ln)( [^;&|]*)? [^ ;&|]*(\.claude|docs/kb)/[^ ;&|]*( *$| *[;&|])' <<<"$c" && block ".claude/ and docs/kb/ are user-written"
    ;;
  WebFetch)
    u=$(jq -r '.tool_input.url // ""' <<<"$in")
    # a real URL parser, not a regex: rejects whitespace, control characters and backslashes (parsers disagree on them),
    # lowercases the scheme and host, and drops userinfo, port, path and fragment
    host=$(python3 -I -c 'import sys, urllib.parse as up
u = sys.argv[1]
if any(ch.isspace() or ord(ch) < 32 or ch == "\\" for ch in u): sys.exit(1)
p = up.urlsplit(u)
if p.scheme.lower() not in ("http", "https") or not p.hostname: sys.exit(1)
print(p.hostname)' "$u") || block "malformed or non-HTTP URL"
    # ponytail: static allowlist, move to a file if it grows past a screen. gist.* is out: anyone can publish there.
    allow='^(.+\.)?(github\.com|elastic\.co|hashicorp\.com|terraform\.io|kubernetes\.io|cert-manager\.io|k3d\.io|suricata\.io|readthedocs\.io|sigmahq\.io|getsops\.io|anthropic\.com|claude\.com)$|^(raw|objects)\.githubusercontent\.com$'
    [[ $host =~ $allow ]] || block "host $host is not in the WebFetch allowlist"
    ;;
esac
exit 0
