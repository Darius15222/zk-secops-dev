#!/usr/bin/env bash
# Red-team for the Claude guardrails (R-06): replays bypass attempts and benign look-alikes through the hooks and scores them.
# Nothing is executed: each hook only receives the JSON a tool call would carry.
# A MISS or FALSE-POS is a finding, not a failure, so this is not a pre-commit gate.
# Usage: scripts/claude-redteam.sh   (HOOKS=<dir> scores candidate hooks before they are installed)
set -uo pipefail
cd "$(dirname "$0")/.."
H=$(realpath "${HOOKS:-.claude/hooks}")

declare -A field=([Bash]=command [WebFetch]=url) n=()
row() { # section result id note
  printf '%-9s %-4s %s\n' "$2" "$3" "$4"
  n[$1.all]=$((${n[$1.all]:-0} + 1))
  n[$1.$2]=$((${n[$1.$2]:-0} + 1))
}
score() { echo "$1: ${n[$1.ok]:-0}/${n[$1.all]:-0} correct, ${n[$1.MISS]:-0} missed, ${n[$1.FALSE-POS]:-0} false positives, ${n[$1.ERROR]:-0} errors"; }

echo "## guard.sh (PreToolUse): want 2 = must block, 0 = must allow"
while IFS=$'\t' read -r id want tool val note; do
  [[ -z $id || $id == \#* ]] && continue
  jq -n --arg t "$tool" --arg f "${field[$tool]:-file_path}" --arg v "$val" '{tool_name:$t, cwd:"/w", tool_input:{($f):$v}}' \
    | "$H/guard.sh" 2>/dev/null
  case $want$? in 22 | 00) r=ok ;; 20) r=MISS ;; 02) r=FALSE-POS ;; *) r=ERROR ;; esac
  row guard "$r" "$id" "$note"
done <scripts/redteam/guard.tsv

echo
echo "## inject-scan.sh (PostToolUse): want flag = must warn, clean = must stay silent"
# payloads are base64 in the file so that reading it does not trip the scanner; only ids and notes are printed.
# Each is wrapped like a Bash tool result, which the hook flattens to one JSON line (a newline becomes \n).
while IFS=$'\t' read -r id want b64 note; do
  [[ -z $id || $id == \#* ]] && continue
  out=$(base64 -d <<<"$b64" | jq -Rs '{tool_response: {stdout: .}}' | "$H/inject-scan.sh" 2>/dev/null)
  case $want${out:+!} in flag! | clean) r=ok ;; flag) r=MISS ;; clean!) r=FALSE-POS ;; *) r=ERROR ;; esac
  row inject "$r" "$id" "$note"
done <scripts/redteam/inject.tsv

echo
score guard
score inject
