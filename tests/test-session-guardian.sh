#!/usr/bin/env bash
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

# --- Test: branch matches lock -> commit allowed (no deny output) ---
REPO=$(setup_repo)
BR=$(git -C "$REPO" branch --show-current)
mkdir -p "$REPO/.git/slate-sessions"
echo "{\"branch\": \"$BR\", \"worktree\": \"\", \"started_at\": \"2026-01-01T00:00:00Z\"}" > "$REPO/.git/slate-sessions/sess-ok.lock"

OUT1=$(payload "sess-ok" "$REPO" "git commit -m test" | bash "$HOOK")
echo "$OUT1" | grep -q '"permissionDecision": "deny"' && { echo "FAIL: matching branch was denied. Output: $OUT1"; exit 1; }
echo "PASS: commit allowed when branch matches lock"

# --- Test: branch does NOT match lock -> commit denied ---
git -C "$REPO" checkout -qb other-branch
OUT2=$(payload "sess-ok" "$REPO" "git commit -m test" | bash "$HOOK")
echo "$OUT2" | grep -q '"permissionDecision": "deny"' || { echo "FAIL: mismatched branch was NOT denied. Output: $OUT2"; exit 1; }
echo "PASS: commit denied when active branch no longer matches the session's lock"

# --- Test: unrelated command -> hook is a no-op, no output ---
OUT3=$(payload "sess-ok" "$REPO" "git status" | bash "$HOOK")
[ -z "$OUT3" ] || { echo "FAIL: unrelated command produced output: $OUT3"; exit 1; }
echo "PASS: unrelated bash command produces no output"

# --- Test: git push also guarded ---
OUT4=$(payload "sess-ok" "$REPO" "git push origin other-branch" | bash "$HOOK")
echo "$OUT4" | grep -q '"permissionDecision": "deny"' || { echo "FAIL: mismatched-branch push was NOT denied. Output: $OUT4"; exit 1; }
echo "PASS: push is guarded the same way as commit"

# --- Test: no lock for this session -> nothing to guard, allowed ---
OUT5=$(payload "sess-unknown" "$REPO" "git commit -m test" | bash "$HOOK")
echo "$OUT5" | grep -q '"permissionDecision": "deny"' && { echo "FAIL: session with no lock was denied. Output: $OUT5"; exit 1; }
echo "PASS: session with no recorded claim is not blocked"

rm -rf "$REPO"
echo ""
echo "All session-guardian tests passed."
