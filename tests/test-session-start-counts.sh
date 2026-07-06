#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"; rm -rf "$TMPDIR_PROJECT" 2>/dev/null || true' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-start.sh"

TMPDIR_PROJECT=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT/progress" "$TMPDIR_PROJECT/features" "$TMPDIR_PROJECT/bugs" "$TMPDIR_PROJECT/ideas"
touch "$TMPDIR_PROJECT/progress/history.md" "$TMPDIR_PROJECT/progress/current.md"
touch "$TMPDIR_PROJECT/features/in-progress.md"

cat > "$TMPDIR_PROJECT/bugs/open.md" <<'EOF'
# Open bugs

## BUG-001: Login button unresponsive
- **Status**: open

## BUG-002: Pagination off by one
- **Status**: open
EOF

cat > "$TMPDIR_PROJECT/ideas/inbox.md" <<'EOF'
# Ideas inbox

- 2026-07-01 10:00 — Add PDF export
EOF

OUTPUT=$(echo '{"source":"startup"}' | CLAUDE_PROJECT_ROOT="$TMPDIR_PROJECT" bash "$HOOK")

echo "$OUTPUT" | grep -q "Bugs abiertos: 2 (BUG-001,BUG-002)" || { echo "FAIL: bug count/IDs missing from output. Got: $OUTPUT"; exit 1; }
echo "PASS: bug count injected correctly"

echo "$OUTPUT" | grep -q "Ideas pendientes: 1" || { echo "FAIL: idea count missing from output. Got: $OUTPUT"; exit 1; }
echo "PASS: idea count injected correctly"

# --- Test: no bugs/ideas dirs -> hook does not error, no bug/idea lines ---
TMPDIR_PROJECT2=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT2/progress" "$TMPDIR_PROJECT2/features"
touch "$TMPDIR_PROJECT2/progress/history.md" "$TMPDIR_PROJECT2/progress/current.md" "$TMPDIR_PROJECT2/features/in-progress.md"

OUTPUT2=$(echo '{"source":"startup"}' | CLAUDE_PROJECT_ROOT="$TMPDIR_PROJECT2" bash "$HOOK")
echo "$OUTPUT2" | grep -q "Bugs abiertos" && { echo "FAIL: bug line present when bugs/ absent"; exit 1; }
echo "$OUTPUT2" | grep -q "Ideas pendientes" && { echo "FAIL: idea line present when ideas/ absent"; exit 1; }
echo "PASS: no bug/idea lines when directories absent, hook did not error"

# --- Test: bugs/open.md and ideas/inbox.md exist with template-only content
# (freshly installed, no real bugs/ideas yet) -> no count lines emitted ---
TMPDIR_PROJECT3=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT3/progress" "$TMPDIR_PROJECT3/features" "$TMPDIR_PROJECT3/bugs" "$TMPDIR_PROJECT3/ideas"
touch "$TMPDIR_PROJECT3/progress/history.md" "$TMPDIR_PROJECT3/progress/current.md" "$TMPDIR_PROJECT3/features/in-progress.md"

cp "$PLUGIN_ROOT/templates/bugs/open.md" "$TMPDIR_PROJECT3/bugs/open.md"
cp "$PLUGIN_ROOT/templates/ideas/inbox.md" "$TMPDIR_PROJECT3/ideas/inbox.md"

OUTPUT3=$(echo '{"source":"startup"}' | CLAUDE_PROJECT_ROOT="$TMPDIR_PROJECT3" bash "$HOOK")
echo "$OUTPUT3" | grep -q "Bugs abiertos" && { echo "FAIL: bug line present for template-only bugs/open.md. Got: $OUTPUT3"; exit 1; }
echo "$OUTPUT3" | grep -q "Ideas pendientes" && { echo "FAIL: idea line present for template-only ideas/inbox.md. Got: $OUTPUT3"; exit 1; }
echo "PASS: no bug/idea lines when files contain only template content"

rm -rf "$TMPDIR_PROJECT" "$TMPDIR_PROJECT2" "$TMPDIR_PROJECT3"
echo ""
echo "All session-start count tests passed."
