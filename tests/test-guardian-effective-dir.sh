#!/usr/bin/env bash
# BUG-005: las reglas 0/1/2 del guardian juzgan la carpeta donde correra git
# ('cd X &&' previo o 'git -C X'), no la del cwd de la sesion -- pero solo
# cuando X es un worktree del MISMO repo. Ante duda, comportamiento anterior.
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUARDIAN="$PLUGIN_ROOT/hooks/session-guardian.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0

R="$TMP/repo"; W="$TMP/wt"; OTHER="$TMP/other"
mkdir -p "$R" "$OTHER"
for d in "$R" "$OTHER"; do
  git -C "$d" init -q -b main .
  git -C "$d" config user.email t@t.co; git -C "$d" config user.name t
  echo x > "$d/f.txt"; git -C "$d" add -A; git -C "$d" commit -qm init
done
git -C "$R" worktree add -q "$W" -b feat/w
R="$(cd "$R" && pwd -P)"; W="$(cd "$W" && pwd -P)"; OTHER="$(cd "$OTHER" && pwd -P)"
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"
mkdir -p "$R/.git/slate-sessions"

# set_peer <cwd-del-peer> [rama]
set_peer() {
  python3 - "$R" "$HEAD_SHA" "$1" "${2:-main}" <<'PY'
import json, sys
repo, head, pcwd, br = sys.argv[1:5]
json.dump({"branch": br, "worktree": "", "head": head, "started_at": "2026-07-26T00:00:00Z",
           "cwd": pcwd, "files": []}, open(repo + "/.git/slate-sessions/peer.lock", "w"))
PY
}

decision() {
  local cmd="$1" payload
  payload=$(python3 -c '
import json, sys
print(json.dumps({"session_id": "me", "cwd": sys.argv[1], "tool_name": "Bash",
                  "tool_input": {"command": sys.argv[2]}}))' "$R" "$cmd")
  printf '%s' "$payload" | (cd "$R" && bash "$GUARDIAN" 2>/dev/null) | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
if not raw:
    print("allow"); sys.exit()
try:
    print(json.loads(raw).get("hookSpecificOutput", {}).get("permissionDecision", "allow"))
except Exception:
    print("allow")'
}

expect() {
  local want="$1" desc="$2" cmd="$3" got
  got=$(decision "$cmd")
  if [ "$got" = "$want" ]; then echo "PASS: $desc -> $got"; else echo "FAIL: $desc -> $got (esperado $want)"; FAILED=1; fi
}

# Peer vivo en main, en la carpeta principal (misma que esta sesion).
set_peer "$R"
expect allow "cd a worktree propio no choca con peer en main" "cd $W && git commit -m x"
expect allow "git -C worktree no choca con peer en main" "git -C $W commit -m x"
expect deny  "git commit sin cd ni -C sigue denegando (regla 1)" "git commit -m x"
expect deny  "git -C otro-repo se juzga con el cwd" "git -C $OTHER commit -m x"
# shellcheck disable=SC2016
expect deny  "cd con variable sin expandir cae al cwd" 'cd "$W" && git commit -m x'
expect deny  "cd || git: el cd no aplica" "cd $W || git checkout main"
expect deny  "cd | git: el cd no aplica" "cd $W | git checkout main"
expect deny  "cd & git: el cd no aplica" "cd $W & git checkout main"
expect deny  "cd a otro repo se juzga con el cwd" "cd $OTHER && git commit -m x"

# Peer vivo en el worktree: la regla 0 debe ver el cd previo.
set_peer "$W" "feat/w"
expect deny  "cd a worktree con peer dentro: checkout denegado (regla 0)" "cd $W && git checkout main"
expect allow "checkout sin cd: el peer esta en otra carpeta" "git checkout main"

echo
if [ "$FAILED" -eq 0 ]; then echo "All guardian effective-dir tests passed."; exit 0; fi
echo "guardian effective-dir tests FAILED."
exit 1
