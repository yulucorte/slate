#!/usr/bin/env bash
# session-guardian.sh — redesigned (FEAT-002 / BUG-002).
# The guardian blocks a sensitive git op only on a CONFIRMED clash with a LIVE
# PEER session; a session acting alone is never blocked (that removes the old
# false positive where changing your own branch got you blocked).
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-guardian.sh"

setup_repo() {
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" config user.email "t@t.com"
  git -C "$dir" config user.name "t"
  git -C "$dir" commit --allow-empty -q -m init
  echo "$dir"
}

payload() {
  # $1=session_id $2=cwd $3=command
  python3 -c "import json,sys; print(json.dumps({'session_id': sys.argv[1], 'cwd': sys.argv[2], 'tool_input': {'command': sys.argv[3]}}))" "$1" "$2" "$3"
}

write_lock() {
  # $1=repo $2=lockname $3=branch $4=head
  mkdir -p "$1/.git/slate-sessions"
  printf '{"branch": "%s", "worktree": "", "head": "%s", "started_at": "2026-01-01T00:00:00Z"}' "$3" "$4" > "$1/.git/slate-sessions/$2.lock"
}

is_deny() { echo "$1" | grep -q '"permissionDecision": "deny"'; }

# --- 1. unrelated command -> no-op, no output ---
REPO=$(setup_repo)
OUT=$(payload "s1" "$REPO" "git status" | bash "$HOOK")
[ -z "$OUT" ] || { echo "FAIL: unrelated command produced output: $OUT"; exit 1; }
echo "PASS: unrelated bash command produces no output"
rm -rf "$REPO"

# --- 2. alone (only own lock), own branch changed -> commit ALLOWED (fixes #2) ---
REPO=$(setup_repo)
git -C "$REPO" checkout -qb feature-x
write_lock "$REPO" "s-me" "some-old-branch" "$(git -C "$REPO" rev-parse HEAD)"
OUT=$(payload "s-me" "$REPO" "git commit -m x" | bash "$HOOK")
is_deny "$OUT" && { echo "FAIL: a solo session was blocked after changing its own branch (false positive #2). Output: $OUT"; exit 1; }
echo "PASS: a session alone is not blocked when it changes its own branch"
rm -rf "$REPO"

# --- 3. peer live on SAME branch -> commit DENIED ---
REPO=$(setup_repo)
BR=$(git -C "$REPO" branch --show-current)
write_lock "$REPO" "s-peer" "$BR" "$(git -C "$REPO" rev-parse HEAD)"
OUT=$(payload "s-me" "$REPO" "git commit -m x" | bash "$HOOK")
is_deny "$OUT" || { echo "FAIL: same-branch peer collision was NOT denied. Output: $OUT"; exit 1; }
echo "PASS: commit denied when a live peer holds the same branch"

# --- 3b. that same peer but STALE (>900s) -> allowed ---
python3 -c "import os,time;t=time.time()-1000;os.utime('$REPO/.git/slate-sessions/s-peer.lock',(t,t))"
OUT=$(payload "s-me" "$REPO" "git commit -m x" | bash "$HOOK")
is_deny "$OUT" && { echo "FAIL: a stale peer lock still blocked. Output: $OUT"; exit 1; }
echo "PASS: a stale peer lock (>900s) does not block"
rm -rf "$REPO"

# --- 4. branch-on-top: my HEAD built on a live peer's un-mainlined tip -> push DENIED ---
REPO=$(setup_repo)
git -C "$REPO" checkout -qb peer-branch
git -C "$REPO" commit --allow-empty -q -m "peer work B"
B=$(git -C "$REPO" rev-parse HEAD)
git -C "$REPO" checkout -qb my-branch
git -C "$REPO" commit --allow-empty -q -m "my work C"
write_lock "$REPO" "s-peer" "peer-branch" "$B"
OUT=$(payload "s-me" "$REPO" "git push origin my-branch" | bash "$HOOK")
is_deny "$OUT" || { echo "FAIL: branch-on-top push was NOT denied. Output: $OUT"; exit 1; }
echo "PASS: push denied when my branch is built on a live peer's un-mainlined tip"

# --- 4b. plain commit (not an integration op) on-top -> allowed ---
OUT=$(payload "s-me" "$REPO" "git commit -m more" | bash "$HOOK")
is_deny "$OUT" && { echo "FAIL: a plain commit on-top was blocked (only integration ops should be). Output: $OUT"; exit 1; }
echo "PASS: a plain commit is allowed on-top (only push/merge/rebase are guarded for on-top)"
rm -rf "$REPO"

# --- 5. legitimate: my branch from mainline, peer advanced elsewhere -> push ALLOWED ---
REPO=$(setup_repo)
BASE=$(git -C "$REPO" branch --show-current)
git -C "$REPO" checkout -qb peer-branch
git -C "$REPO" commit --allow-empty -q -m "peer work B"
B=$(git -C "$REPO" rev-parse HEAD)
git -C "$REPO" checkout -q "$BASE"
git -C "$REPO" checkout -qb my-feature
git -C "$REPO" commit --allow-empty -q -m "my independent work"
write_lock "$REPO" "s-peer" "peer-branch" "$B"
OUT=$(payload "s-me" "$REPO" "git push origin my-feature" | bash "$HOOK")
is_deny "$OUT" && { echo "FAIL: an independent branch push was blocked (false positive). Output: $OUT"; exit 1; }
echo "PASS: push allowed when my branch is independent of the peer's live tip"
rm -rf "$REPO"

# --- 6. shared stash: peer live, generic 'git stash pop' -> DENIED ---
REPO=$(setup_repo)
write_lock "$REPO" "s-peer" "some-other-branch" "$(git -C "$REPO" rev-parse HEAD)"
OUT=$(payload "s-me" "$REPO" "git stash pop" | bash "$HOOK")
is_deny "$OUT" || { echo "FAIL: generic 'git stash pop' with a live peer was NOT denied. Output: $OUT"; exit 1; }
echo "PASS: generic 'git stash pop' denied when a peer is live"

# --- 6b. explicit stash ref -> allowed ---
OUT=$(payload "s-me" "$REPO" "git stash apply stash@{0}" | bash "$HOOK")
is_deny "$OUT" && { echo "FAIL: explicit 'git stash apply stash@{0}' was denied. Output: $OUT"; exit 1; }
echo "PASS: an explicit stash reference is allowed even with a live peer"

# --- 6c. no live peer -> stash pop allowed ---
rm -f "$REPO/.git/slate-sessions/s-peer.lock"
OUT=$(payload "s-me" "$REPO" "git stash pop" | bash "$HOOK")
is_deny "$OUT" && { echo "FAIL: stash pop blocked with no live peer. Output: $OUT"; exit 1; }
echo "PASS: stash pop allowed when this session is alone"
rm -rf "$REPO"

echo ""
echo "All session-guardian tests passed."
