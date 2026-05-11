#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness" "$TMPDIR/features"
echo "# History" > "$TMPDIR/progress/history.md"
cp "$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" "$TMPDIR/features/done.md"
echo "" > "$TMPDIR/features/in-progress.md"

MOCK=$(mktemp -d)
# Isolate PATH so the real `gh` (e.g. /opt/homebrew/bin/gh) is not picked up.
export PATH="$MOCK:/usr/bin:/bin:/usr/sbin:/sbin"
cat > "$MOCK/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr list") echo '[{"number":42}]' ;;
  "pr view") echo '{"comments":[{"author":{"login":"reviewer"},"body":"Please add tests."}]}' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$MOCK/gh"

bash "$PLUGIN_ROOT/scripts/harness/rollback-feature.sh" FEAT-007

if grep -q "## FEAT-007:" "$TMPDIR/features/done.md"; then
  echo "FAIL: FEAT-007 should have been removed from done.md"
  exit 1
fi
if ! grep -q "## FEAT-007:" "$TMPDIR/features/in-progress.md"; then
  echo "FAIL: FEAT-007 should be in in-progress.md"
  cat "$TMPDIR/features/in-progress.md"
  exit 1
fi
if ! grep -q "Please add tests" "$TMPDIR/features/in-progress.md"; then
  echo "FAIL: reviewer comment should be in notes"
  cat "$TMPDIR/features/in-progress.md"
  exit 1
fi
echo "PASS: rollback moves feature + appends review comments"

rm -rf "$TMPDIR" "$MOCK"
echo "All rollback tests passed."
