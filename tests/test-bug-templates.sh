#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Test 1: bug-format.md documents all required fields ---
DOC="$PLUGIN_ROOT/docs/bug-format.md"
[ -f "$DOC" ] || { echo "FAIL: docs/bug-format.md missing"; exit 1; }
for field in Status Severity Reported-by Detected Where "Root cause" Fix Commit Fixed; do
  grep -q -- "$field" "$DOC" || { echo "FAIL: docs/bug-format.md missing field '$field'"; exit 1; }
done
echo "PASS: docs/bug-format.md documents all required fields"

# --- Test 2: templates/bugs/fixed.md declares append-only rule ---
FIXED_TPL="$PLUGIN_ROOT/templates/bugs/fixed.md"
[ -f "$FIXED_TPL" ] || { echo "FAIL: templates/bugs/fixed.md missing"; exit 1; }
grep -qi "FORBIDDEN" "$FIXED_TPL" || { echo "FAIL: templates/bugs/fixed.md missing FORBIDDEN warning"; exit 1; }
echo "PASS: templates/bugs/fixed.md declares append-only rule"

# --- Test 3: templates/bugs/open.md exists and is non-empty ---
OPEN_TPL="$PLUGIN_ROOT/templates/bugs/open.md"
[ -s "$OPEN_TPL" ] || { echo "FAIL: templates/bugs/open.md missing or empty"; exit 1; }
echo "PASS: templates/bugs/open.md exists"

echo ""
echo "All bug template tests passed."
