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

# Test 2: AUTO_PR=false → suggest log + stderr → harness:
echo 'HARNESS_AUTO_PR=false
HARNESS_NOTIFY=false' > "$TMPDIR/.claude-harness/config.sh"
cp "$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" "$TMPDIR/features/done.md"
suggest_err=$(echo '{"tool_input":{"file_path":"'"$TMPDIR/features/done.md"'"}}' | bash "$HOOK" 2>&1 1>/dev/null)
if ! grep -q "feature-ready-for-pr" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected feature-ready-for-pr log entry"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
case "$suggest_err" in
  *"→ harness:"*"FEAT-007"*"ready for PR"*) ;;
  *) echo "FAIL: AUTO_PR=false stderr missing → harness: suggest line; got: $suggest_err"; exit 1 ;;
esac
if ! grep -q 'feature=FEAT-007' "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: feature=FEAT-007 not preserved in suggest log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
if ! grep -q 'cmd=bash scripts/harness/pr-open.sh FEAT-007' "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: cmd= key not preserved in suggest log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: AUTO_PR=false logs feature-ready-for-pr, emits → harness:, preserves keys"

# Test 3: branch mismatch → WARNING + skip + stderr ! harness:
rm -f "$TMPDIR/progress/.done.snapshot"
git -C "$TMPDIR" checkout -q main
warn_err=$(echo '{"tool_input":{"file_path":"'"$TMPDIR/features/done.md"'"}}' | bash "$HOOK" 2>&1 1>/dev/null)
if ! grep -q "branch-mismatch" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected branch-mismatch log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
case "$warn_err" in
  *"! harness:"*"FEAT-007"*"marked done"*"current branch"*) ;;
  *) echo "FAIL: branch-mismatch stderr missing ! harness: warn line; got: $warn_err"; exit 1 ;;
esac
if ! grep -q 'current=main' "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: current=main not preserved in branch-mismatch log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
if ! grep -q 'expected=feat/feat-007-jwt-authentication' "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected=... not preserved in branch-mismatch log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: branch mismatch logs WARNING, emits ! harness:, preserves current/expected keys"

# Test 4: AUTO_PR=true → ✓ harness: success path
# pr-open.sh always exits 0 (logs an ERROR if gh missing, but exit 0)
rm -f "$TMPDIR/progress/.done.snapshot"
git -C "$TMPDIR" checkout -q feat/feat-007-jwt-authentication
echo 'HARNESS_AUTO_PR=true
HARNESS_NOTIFY=false' > "$TMPDIR/.claude-harness/config.sh"
ok_err=$(echo '{"tool_input":{"file_path":"'"$TMPDIR/features/done.md"'"}}' | bash "$HOOK" 2>&1 1>/dev/null)
case "$ok_err" in
  *"✓ harness:"*"PR opened for FEAT-007"*) ;;
  *) echo "FAIL: AUTO_PR=true stderr missing ✓ harness: line; got: $ok_err"; exit 1 ;;
esac
if ! grep -q 'action=pr-open-invoked' "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: action=pr-open-invoked not preserved in log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: AUTO_PR=true emits ✓ harness: PR opened, preserves action= key"

# Test 5: malformed feature (no recognized markdown for read-feature.sh) → ! harness: warn
rm -f "$TMPDIR/progress/.done.snapshot"
cat > "$TMPDIR/features/done.md" <<'EOF'
## FEAT-888: Broken feature

This entry has no structured fields and read-feature should fail or yield empty.
EOF
warn2_err=$(echo '{"tool_input":{"file_path":"'"$TMPDIR/features/done.md"'"}}' | bash "$HOOK" 2>&1 1>/dev/null)
case "$warn2_err" in
  *"! harness:"*"FEAT-888"*) ;;
  *) echo "FAIL: malformed feature stderr missing ! harness: warn; got: $warn2_err"; exit 1 ;;
esac
if ! grep -q 'feature=FEAT-888' "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: feature=FEAT-888 not preserved in malformed log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: malformed done feature emits ! harness:, preserves feature= key"

rm -rf "$TMPDIR"
echo "All done-watcher tests passed."
