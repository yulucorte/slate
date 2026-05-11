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
git -C "$TMPDIR" checkout -q -b feat/feat-007-jwt-authentication

HOOK="$PLUGIN_ROOT/hooks/post-edit-done-watcher.sh"

# Establish baseline
echo "" > "$TMPDIR/features/done.md"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/done.md"'"}}' | bash "$HOOK"

# Test 1: non-done.md ignored
echo '{"tool_input":{"file_path":"/tmp/other.md"}}' | bash "$HOOK"
echo "PASS: ignores non-done.md files"

# Test 2: AUTO_PR=false → notification log
echo 'HARNESS_AUTO_PR=false
HARNESS_NOTIFY=false' > "$TMPDIR/.claude-harness/config.sh"
cp "$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" "$TMPDIR/features/done.md"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/done.md"'"}}' | bash "$HOOK"
if ! grep -q "feature-ready-for-pr" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected feature-ready-for-pr log entry"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: AUTO_PR=false logs feature-ready-for-pr"

# Test 3: branch mismatch → WARNING + skip
rm -f "$TMPDIR/progress/.done.snapshot"
git -C "$TMPDIR" checkout -q main
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/done.md"'"}}' | bash "$HOOK"
if ! grep -q "branch-mismatch" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected branch-mismatch log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: branch mismatch logs WARNING"

rm -rf "$TMPDIR"
echo "All done-watcher tests passed."
