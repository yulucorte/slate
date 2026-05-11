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

SCRIPT="$PLUGIN_ROOT/scripts/harness/pr-merge.sh"
MOCK=$(mktemp -d)
# Isolate PATH so the real gh on this system (e.g. /opt/homebrew/bin/gh) is
# not picked up before the mock.
export PATH="$MOCK:/usr/bin:/bin:/usr/sbin:/sbin"

# Test 1: changes requested → ERROR
cat > "$MOCK/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr list") echo '[{"number":42}]' ;;
  "pr view") echo '{"state":"OPEN","reviewDecision":"CHANGES_REQUESTED"}' ;;
  *) echo "unexpected: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$MOCK/gh"
bash "$SCRIPT" FEAT-007
if ! grep -q "changes-requested" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected changes-requested"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: refuses to merge when CHANGES_REQUESTED"

# Test 2: approved → merges, captures SHA, updates done.md
cat > "$MOCK/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr list") echo '[{"number":42}]' ;;
  "pr view")
    if [[ "$*" == *mergeCommit* ]]; then
      echo '{"mergeCommit":{"oid":"abc1234deadbeef"}}'
    else
      echo '{"state":"OPEN","reviewDecision":"APPROVED"}'
    fi ;;
  "pr merge") exit 0 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$MOCK/gh"
bash "$SCRIPT" FEAT-007
if ! grep -q "abc1234" "$TMPDIR/progress/history.md"; then
  echo "FAIL: merge SHA not in history"
  cat "$TMPDIR/progress/history.md"
  exit 1
fi
if ! grep -qE "Merged\*{0,2}: abc1234" "$TMPDIR/features/done.md"; then
  echo "FAIL: done.md not updated with Merged: SHA"
  cat "$TMPDIR/features/done.md"
  exit 1
fi
echo "PASS: merge updates history and done.md"

# Test 3: reviewDecision=null (repo without review requirement) → merges
# Reset feature state so done.md doesn't already contain "Merged:" from Test 2
cp "$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" "$TMPDIR/features/done.md"
echo "# History" > "$TMPDIR/progress/history.md"
rm -f "$TMPDIR/progress/hooks.log"
cat > "$MOCK/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr list") echo '[{"number":42}]' ;;
  "pr view")
    if [[ "$*" == *mergeCommit* ]]; then
      echo '{"mergeCommit":{"oid":"deadbee1234567"}}'
    else
      echo '{"state":"OPEN","reviewDecision":null}'
    fi ;;
  "pr merge") exit 0 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$MOCK/gh"
bash "$SCRIPT" FEAT-007
if ! grep -qE "Merged\*{0,2}: deadbee" "$TMPDIR/features/done.md"; then
  echo "FAIL: reviewDecision=null should still merge"
  cat "$TMPDIR/features/done.md"
  exit 1
fi
echo "PASS: merges when reviewDecision is null (review not required)"

rm -rf "$TMPDIR" "$MOCK"
echo "All pr-merge tests passed."
