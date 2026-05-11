#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness" "$TMPDIR/features"
git -C "$TMPDIR" init -q -b main
git -C "$TMPDIR" -c user.email=t@t.c -c user.name=t commit --allow-empty -qm init

HOOK="$PLUGIN_ROOT/hooks/post-edit-in-progress-watcher.sh"

# Empty in-progress.md establishes baseline snapshot
echo "" > "$TMPDIR/features/in-progress.md"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/in-progress.md"'"}}' | bash "$HOOK"

# Test 1: non-in-progress.md is ignored
echo '{"tool_input":{"file_path":"/tmp/other.md"}}' | bash "$HOOK"
echo "PASS: ignores non-in-progress.md files"

# Test 2: AUTO_BRANCH=false → log INFO with suggestion, no branch created
echo 'HARNESS_AUTO_BRANCH=false' > "$TMPDIR/.claude-harness/config.sh"
cp "$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" "$TMPDIR/features/in-progress.md"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/in-progress.md"'"}}' | bash "$HOOK"

branch=$(git -C "$TMPDIR" branch --show-current)
if [ "$branch" != "main" ]; then
  echo "FAIL: AUTO_BRANCH=false should not switch branches; on $branch"
  exit 1
fi
if ! grep -q "manual-branch-suggested" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected manual-branch-suggested log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: AUTO_BRANCH=false logs INFO, no switch"

# Reset snapshot so the next test sees the feature as new again
rm -f "$TMPDIR/progress/.in-progress.snapshot"

# Test 3: AUTO_BRANCH=true → git switch -c runs
echo 'HARNESS_AUTO_BRANCH=true' > "$TMPDIR/.claude-harness/config.sh"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/in-progress.md"'"}}' | bash "$HOOK"

branch=$(git -C "$TMPDIR" branch --show-current)
if [ "$branch" != "feat/feat-007-jwt-authentication" ]; then
  echo "FAIL: AUTO_BRANCH=true expected branch feat/feat-007-jwt-authentication; got '$branch'"
  exit 1
fi
echo "PASS: AUTO_BRANCH=true creates and switches to branch"

rm -rf "$TMPDIR"
echo "All in-progress-watcher tests passed."
