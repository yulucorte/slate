#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness"

HOOK="$PLUGIN_ROOT/hooks/pre-tool-safety.sh"

# Test 1: blocks rm -rf $HOME
set +e
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf $HOME/foo"}}' | bash "$HOOK" 2>/tmp/safety-err
rc=$?
set -e
if [ "$rc" -ne 2 ]; then
  echo "FAIL rm -rf HOME: expected exit 2, got $rc"
  exit 1
fi
if ! grep -q "RM_HOME" /tmp/safety-err; then
  echo "FAIL rm -rf HOME: expected RM_HOME in stderr"
  cat /tmp/safety-err
  exit 1
fi
echo "PASS: blocks rm -rf \$HOME with exit 2 + rule ID"

# Test 2: blocks git push --force to main (force flag before branch)
set +e
echo '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}' | bash "$HOOK" 2>/dev/null
rc=$?
set -e
if [ "$rc" -ne 2 ]; then echo "FAIL force push main"; exit 1; fi
echo "PASS: blocks git push --force to main"

# Test 2b: blocks git push with --force AFTER branch (common ordering)
set +e
echo '{"tool_name":"Bash","tool_input":{"command":"git push origin main --force"}}' | bash "$HOOK" 2>/dev/null
rc=$?
set -e
if [ "$rc" -ne 2 ]; then echo "FAIL force push main (post-positioned --force): rc=$rc"; exit 1; fi
echo "PASS: blocks git push origin main --force (post-positioned)"

# Test 3: blocks edits to .claude-harness/config.sh
set +e
echo '{"tool_name":"Edit","tool_input":{"file_path":"'"$TMPDIR/.claude-harness/config.sh"'"}}' | bash "$HOOK" 2>/dev/null
rc=$?
set -e
if [ "$rc" -ne 2 ]; then echo "FAIL config edit"; exit 1; fi
echo "PASS: blocks edits to config.sh"

# Test 4: HARNESS_ALLOW_RM_HOME=true bypasses
echo 'HARNESS_ALLOW_RM_HOME=true' > "$TMPDIR/.claude-harness/config.sh"
set +e
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf $HOME/foo"}}' | bash "$HOOK" 2>/dev/null
rc=$?
set -e
if [ "$rc" -ne 0 ]; then echo "FAIL allow override: rc=$rc"; exit 1; fi
echo "PASS: HARNESS_ALLOW_RM_HOME=true bypasses block"

# Test 5: permissive mode logs but does not block
echo 'HARNESS_SAFETY_RULES=permissive' > "$TMPDIR/.claude-harness/config.sh"
set +e
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf $HOME/foo"}}' | bash "$HOOK" 2>/dev/null
rc=$?
set -e
if [ "$rc" -ne 0 ]; then echo "FAIL permissive: rc=$rc"; exit 1; fi
if ! grep -q "permissive" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL permissive: expected log entry"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: permissive mode logs but does not block"

# Test 6: safe command passes
echo 'HARNESS_SAFETY_RULES=strict' > "$TMPDIR/.claude-harness/config.sh"
echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | bash "$HOOK"
echo "PASS: safe command passes"

rm -rf "$TMPDIR"
echo "All pre-tool-safety tests passed."
