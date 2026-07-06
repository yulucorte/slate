#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Test 1: idea-format.md documents both entry formats ---
DOC="$PLUGIN_ROOT/docs/idea-format.md"
[ -f "$DOC" ] || { echo "FAIL: docs/idea-format.md missing"; exit 1; }
grep -q "Area" "$DOC" || { echo "FAIL: docs/idea-format.md missing Area field"; exit 1; }
grep -q "Priority" "$DOC" || { echo "FAIL: docs/idea-format.md missing Priority field"; exit 1; }
grep -q "Outcome" "$DOC" || { echo "FAIL: docs/idea-format.md missing Outcome field"; exit 1; }
echo "PASS: docs/idea-format.md documents required fields"

# --- Test 2: templates/ideas/triaged.md declares append-only rule ---
TRIAGED_TPL="$PLUGIN_ROOT/templates/ideas/triaged.md"
[ -f "$TRIAGED_TPL" ] || { echo "FAIL: templates/ideas/triaged.md missing"; exit 1; }
grep -qi "FORBIDDEN" "$TRIAGED_TPL" || { echo "FAIL: templates/ideas/triaged.md missing FORBIDDEN warning"; exit 1; }
echo "PASS: templates/ideas/triaged.md declares append-only rule"

# --- Test 3: templates/ideas/inbox.md exists and is non-empty ---
INBOX_TPL="$PLUGIN_ROOT/templates/ideas/inbox.md"
[ -s "$INBOX_TPL" ] || { echo "FAIL: templates/ideas/inbox.md missing or empty"; exit 1; }
echo "PASS: templates/ideas/inbox.md exists"

echo ""
echo "All idea template tests passed."
