#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-lock-cleanup.sh"

REPO=$(mktemp -d)
git -C "$REPO" init -q
git -C "$REPO" config user.email "t@t.com"
git -C "$REPO" config user.name "t"
git -C "$REPO" commit --allow-empty -q -m init

mkdir -p "$REPO/.git/slate-sessions"
echo '{"branch": "main", "worktree": "", "started_at": "2026-01-01T00:00:00Z"}' > "$REPO/.git/slate-sessions/sess-end.lock"

# Simulate a worktree this session left behind, to prove cleanup does not touch it.
WT="$REPO.leftover-worktree"
git -C "$REPO" worktree add -q "$WT" -b leftover-branch >/dev/null

echo '{"session_id":"sess-end"}' | CLAUDE_PROJECT_ROOT="$REPO" bash "$HOOK"

[ -f "$REPO/.git/slate-sessions/sess-end.lock" ] && { echo "FAIL: lock file still present after cleanup"; exit 1; }
echo "PASS: session-end removes this session's lock file"

[ -d "$WT" ] || { echo "FAIL: cleanup deleted the leftover worktree — it must not touch worktrees"; exit 1; }
echo "PASS: cleanup leaves worktrees and branches untouched"

git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || true
rm -rf "$REPO" "$WT"
echo ""
echo "All session-lock-cleanup tests passed."
