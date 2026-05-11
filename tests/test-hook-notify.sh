#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export NOTIFY_TEST_MODE=1
export NOTIFY_TEST_FILE="$TMPDIR/notify.out"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness"

HOOK="$PLUGIN_ROOT/hooks/stop-notify.sh"

# Test 1: HARNESS_NOTIFY=false → skip
echo 'HARNESS_NOTIFY=false' > "$TMPDIR/.claude-harness/config.sh"
bash "$HOOK"
if [ -f "$NOTIFY_TEST_FILE" ]; then
  echo "FAIL: should have skipped"
  exit 1
fi
echo "PASS: HARNESS_NOTIFY=false skips"

# Test 2: HARNESS_NOTIFY=true dispatches once
echo 'HARNESS_NOTIFY=true' > "$TMPDIR/.claude-harness/config.sh"
bash "$HOOK"
if [ ! -f "$NOTIFY_TEST_FILE" ]; then
  echo "FAIL: notification should have been written"
  exit 1
fi
echo "PASS: dispatches when enabled"

# Test 3: debounce within 30s
rm -f "$NOTIFY_TEST_FILE"
bash "$HOOK"
if [ -f "$NOTIFY_TEST_FILE" ]; then
  echo "FAIL: second call within 30s should be debounced"
  exit 1
fi
echo "PASS: debounces within 30s"

rm -rf "$TMPDIR"
rm -f /tmp/claude-harness-last-notify-*
echo "All stop-notify tests passed."
