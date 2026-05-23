#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"; rm -rf "$TMPDIR_PROJECT" 2>/dev/null || true' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$PLUGIN_ROOT/scripts/install-into-project.sh"

# --- Test 1: creates CLAUDE.md when none exists ---
TMPDIR_PROJECT=$(mktemp -d)
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" >/dev/null
[ -f "$TMPDIR_PROJECT/CLAUDE.md" ] || { echo "FAIL: CLAUDE.md not created"; exit 1; }
grep -q "<!-- claude-harness -->" "$TMPDIR_PROJECT/CLAUDE.md" || { echo "FAIL: marker missing"; exit 1; }
grep -q "init.sh" "$TMPDIR_PROJECT/CLAUDE.md" || { echo "FAIL: protocol text missing"; exit 1; }
echo "PASS: creates CLAUDE.md when absent"
rm -rf "$TMPDIR_PROJECT"

# --- Test 2: appends to existing CLAUDE.md without altering content ---
TMPDIR_PROJECT=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT"
printf "# My Project\n\nExisting instructions here.\n" > "$TMPDIR_PROJECT/CLAUDE.md"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" >/dev/null
grep -q "# My Project" "$TMPDIR_PROJECT/CLAUDE.md" || { echo "FAIL: original heading lost"; exit 1; }
grep -q "Existing instructions here." "$TMPDIR_PROJECT/CLAUDE.md" || { echo "FAIL: original body lost"; exit 1; }
grep -q "<!-- claude-harness -->" "$TMPDIR_PROJECT/CLAUDE.md" || { echo "FAIL: marker missing after append"; exit 1; }
echo "PASS: appends to existing CLAUDE.md"
rm -rf "$TMPDIR_PROJECT"

# --- Test 3: idempotent — running installer twice does not duplicate block ---
TMPDIR_PROJECT=$(mktemp -d)
echo "# x" > "$TMPDIR_PROJECT/CLAUDE.md"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" >/dev/null
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" >/dev/null
count=$(grep -c "<!-- claude-harness -->" "$TMPDIR_PROJECT/CLAUDE.md" || true)
[ "$count" = "1" ] || { echo "FAIL: marker count $count (expected 1)"; exit 1; }
echo "PASS: installer is idempotent on CLAUDE.md"
rm -rf "$TMPDIR_PROJECT"

# --- Test 4: prefers existing lowercase claude.md over creating CLAUDE.md ---
# Note: macOS default FS is case-insensitive, so check the actual recorded
# filename via `ls` rather than `[ -f ]`.
TMPDIR_PROJECT=$(mktemp -d)
echo "# my project" > "$TMPDIR_PROJECT/claude.md"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" >/dev/null
grep -q "<!-- claude-harness -->" "$TMPDIR_PROJECT/claude.md" || { echo "FAIL: lowercase claude.md not updated"; exit 1; }
ls "$TMPDIR_PROJECT/" | grep -qx 'claude.md' || { echo "FAIL: lowercase claude.md filename lost"; exit 1; }
ls "$TMPDIR_PROJECT/" | grep -qx 'CLAUDE.md' && { echo "FAIL: should not create uppercase CLAUDE.md when lowercase exists"; exit 1; }
echo "PASS: respects existing lowercase claude.md"
rm -rf "$TMPDIR_PROJECT"

echo ""
echo "All CLAUDE.md injection tests passed."
