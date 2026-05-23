#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"; rm -rf "$TMPDIR_PROJECT" 2>/dev/null || true' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Test 1: init.sh generates progress/codebase-map.md ---
TMPDIR_PROJECT=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT/src" "$TMPDIR_PROJECT/tests" "$TMPDIR_PROJECT/progress"
touch "$TMPDIR_PROJECT/src/main.py" "$TMPDIR_PROJECT/src/utils.py"
touch "$TMPDIR_PROJECT/tests/test_main.py"
touch "$TMPDIR_PROJECT/README.md"
cp "$PLUGIN_ROOT/templates/init.sh" "$TMPDIR_PROJECT/init.sh"

( cd "$TMPDIR_PROJECT" && bash init.sh >/dev/null 2>&1 )

MAP="$TMPDIR_PROJECT/progress/codebase-map.md"
[ -f "$MAP" ] || { echo "FAIL: codebase-map.md not generated"; exit 1; }
grep -q "## Project Structure" "$MAP" || { echo "FAIL: missing Project Structure section"; exit 1; }
grep -q "Python" "$MAP" || { echo "FAIL: Python not detected"; exit 1; }
grep -q "node_modules" "$MAP" && { echo "FAIL: node_modules leaked into map"; exit 1; }
echo "PASS: codebase-map.md generated with structure + language detection"
rm -rf "$TMPDIR_PROJECT"

# --- Test 2: codebase-map.md is regenerated (not idempotent) ---
TMPDIR_PROJECT=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT/progress" "$TMPDIR_PROJECT/src"
echo "old content" > "$TMPDIR_PROJECT/progress/codebase-map.md"
touch "$TMPDIR_PROJECT/src/app.ts"
cp "$PLUGIN_ROOT/templates/init.sh" "$TMPDIR_PROJECT/init.sh"

( cd "$TMPDIR_PROJECT" && bash init.sh >/dev/null 2>&1 )

grep -q "old content" "$TMPDIR_PROJECT/progress/codebase-map.md" && { echo "FAIL: old content not replaced"; exit 1; }
grep -q "TypeScript" "$TMPDIR_PROJECT/progress/codebase-map.md" || { echo "FAIL: TypeScript not detected"; exit 1; }
echo "PASS: codebase-map.md is regenerated each run"
rm -rf "$TMPDIR_PROJECT"

echo ""
echo "All codebase-map tests passed."
