#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-lock.sh"

REPO=$(mktemp -d)
git -C "$REPO" init -q
git -C "$REPO" config user.email "t@t.com"
git -C "$REPO" config user.name "t"
git -C "$REPO" commit --allow-empty -q -m init

# Session A runs in the main checkout, claims its branch.
echo '{"session_id":"sess-A"}' | CLAUDE_PROJECT_ROOT="$REPO" bash "$HOOK" >/dev/null

# Add a second, independent worktree by hand (simulates a second checkout
# of the same repo that a second Claude Code session could be pointed at).
WT2="$(mktemp -d)/wt2"
git -C "$REPO" worktree add -q "$WT2" -b manual-second-checkout >/dev/null

# From worktree B, the shared lock directory must resolve to the SAME path
# as from the main checkout, and session A's lock file must be visible there.
COMMON_A="$(git -C "$REPO" rev-parse --git-common-dir)"
case "$COMMON_A" in /*) : ;; *) COMMON_A="$REPO/$COMMON_A" ;; esac
COMMON_A="$(cd "$COMMON_A" && pwd -P)"
COMMON_B="$(git -C "$WT2" rev-parse --git-common-dir)"
case "$COMMON_B" in /*) : ;; *) COMMON_B="$WT2/$COMMON_B" ;; esac
COMMON_B="$(cd "$COMMON_B" && pwd -P)"

[ "$COMMON_A" = "$COMMON_B" ] || { echo "FAIL: git-common-dir differs between checkouts: $COMMON_A vs $COMMON_B"; exit 1; }
[ -f "$COMMON_B/slate-sessions/sess-A.lock" ] || { echo "FAIL: session A's lock not visible from worktree B at $COMMON_B/slate-sessions/"; exit 1; }
echo "PASS: lock directory is shared and visible across worktrees of the same repo"

git -C "$REPO" worktree remove --force "$WT2" 2>/dev/null || true
rm -rf "$REPO" "$(dirname "$WT2")" 2>/dev/null

echo ""
echo "All session-lock worktree-visibility tests passed."
