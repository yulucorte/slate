#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-heartbeat.sh"

REPO=$(mktemp -d)
git -C "$REPO" init -q
git -C "$REPO" config user.email "t@t.com"
git -C "$REPO" config user.name "t"
git -C "$REPO" commit --allow-empty -q -m init

mkdir -p "$REPO/.git/slate-sessions"
LOCK="$REPO/.git/slate-sessions/sess-hb.lock"
echo '{"branch": "main", "worktree": "", "started_at": "2020-01-01T00:00:00Z"}' > "$LOCK"
python3 -c "import os,time; t=time.time()-1000; os.utime('$LOCK',(t,t))"
OLD_MTIME=$(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK")

echo '{"session_id":"sess-hb"}' | CLAUDE_PROJECT_ROOT="$REPO" bash "$HOOK"
NEW_MTIME=$(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK")

[ "$NEW_MTIME" -gt "$OLD_MTIME" ] || { echo "FAIL: lock mtime not refreshed ($OLD_MTIME -> $NEW_MTIME)"; exit 1; }
echo "PASS: heartbeat refreshes lock mtime for an existing lock"

# --- Test: no lock file for this session -> no error, no file created ---
echo '{"session_id":"sess-none"}' | CLAUDE_PROJECT_ROOT="$REPO" bash "$HOOK"
[ -f "$REPO/.git/slate-sessions/sess-none.lock" ] && { echo "FAIL: heartbeat created a lock file it shouldn't have"; exit 1; }
echo "PASS: heartbeat is a no-op when this session has no lock"

rm -rf "$REPO"
echo ""
echo "All session-heartbeat tests passed."
