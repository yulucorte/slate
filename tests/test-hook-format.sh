#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness" "$TMPDIR/src" "$TMPDIR/features"

HOOK="$PLUGIN_ROOT/hooks/post-edit-format.sh"

# Test 1: skip files in features/
echo "junk" > "$TMPDIR/features/in-progress.md"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/in-progress.md"'"}}' | bash "$HOOK"
rc=$?
if [ "$rc" -ne 0 ]; then echo "FAIL skip features: rc=$rc"; exit 1; fi
if [ -f "$TMPDIR/progress/hooks.log" ] && grep -q "post-edit-format" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL skip features: should not log silent skip"
  exit 1
fi
echo "PASS: skips files in features/ silently"

# Test 2: HARNESS_FORMATTER=none → silent skip (no log entry, default config)
echo 'HARNESS_FORMATTER=none' > "$TMPDIR/.claude-harness/config.sh"
echo "const x=1" > "$TMPDIR/src/foo.ts"
# Ensure no pre-existing entry pollutes the check
rm -f "$TMPDIR/progress/hooks.log"
echo '{"tool_input":{"file_path":"'"$TMPDIR/src/foo.ts"'"}}' | bash "$HOOK"
if [ -f "$TMPDIR/progress/hooks.log" ] && grep -q "post-edit-format" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL formatter=none: expected NO log entry (silent skip)"
  cat "$TMPDIR/progress/hooks.log" 2>/dev/null
  exit 1
fi
echo "PASS: HARNESS_FORMATTER=none skips silently (no log entry)"

# Test 3: missing formatter binary → log SKIP, exit 0
echo 'HARNESS_FORMATTER=prettier' > "$TMPDIR/.claude-harness/config.sh"
echo "const x=1" > "$TMPDIR/src/foo.ts"
# Preserve core utilities but ensure prettier is not on PATH.
# Use an empty bin dir prepended to a minimal core PATH so bash + grep + sed still work,
# but no formatter binaries are reachable.
EMPTY_BIN="$TMPDIR/empty-bin"
mkdir -p "$EMPTY_BIN"
OLD_PATH="$PATH"
export PATH="$EMPTY_BIN:/usr/bin:/bin"   # no prettier here (assuming none installed system-wide)
# If prettier IS installed system-wide, this test is a no-op for this machine — skip it.
if command -v prettier >/dev/null 2>&1; then
  echo "SKIP test 3: prettier is installed system-wide; cannot simulate missing"
  export PATH="$OLD_PATH"
else
  echo '{"tool_input":{"file_path":"'"$TMPDIR/src/foo.ts"'"}}' | bash "$HOOK"
  rc=$?
  export PATH="$OLD_PATH"
  if [ "$rc" -ne 0 ]; then echo "FAIL missing formatter exit: rc=$rc"; exit 1; fi
  if ! grep -q "SKIP.*reason=formatter-missing" "$TMPDIR/progress/hooks.log"; then
    echo "FAIL missing formatter log"
    cat "$TMPDIR/progress/hooks.log"
    exit 1
  fi
  echo "PASS: missing formatter degrades gracefully"
fi

rm -rf "$TMPDIR"
echo "All post-edit-format tests passed."
