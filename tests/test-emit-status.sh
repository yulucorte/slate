#!/usr/bin/env bash
# Test: emit-status.sh writes formatted line to stderr AND appends to hooks.log
set -u
TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PROJECT_ROOT="$TESTDIR"
export HARNESS_LOG_MAX_BYTES=5242880
export HARNESS_LOG_ROTATIONS=3

PASS=0
FAIL=0

assert_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
assert_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# Test 1: ok icon goes to stderr with check mark
out=$(bash "$REPO_ROOT/hooks/lib/emit-status.sh" ok test-hook "operation succeeded" 2>&1 1>/dev/null)
case "$out" in
  *"✓ harness:"*"operation succeeded"*) assert_pass "ok emits ✓ to stderr" ;;
  *) assert_fail "ok stderr was: $out" ;;
esac

# Test 2: block icon emits ✗
out=$(bash "$REPO_ROOT/hooks/lib/emit-status.sh" block test-hook "dangerous op" 2>&1 1>/dev/null)
case "$out" in
  *"✗ harness:"*"dangerous op"*) assert_pass "block emits ✗ to stderr" ;;
  *) assert_fail "block stderr was: $out" ;;
esac

# Test 3: suggest emits →
out=$(bash "$REPO_ROOT/hooks/lib/emit-status.sh" suggest test-hook "consider doing X" 2>&1 1>/dev/null)
case "$out" in
  *"→ harness:"*"consider doing X"*) assert_pass "suggest emits → to stderr" ;;
  *) assert_fail "suggest stderr was: $out" ;;
esac

# Test 4: warn emits !
out=$(bash "$REPO_ROOT/hooks/lib/emit-status.sh" warn test-hook "something off" 2>&1 1>/dev/null)
case "$out" in
  *"! harness:"*"something off"*) assert_pass "warn emits ! to stderr" ;;
  *) assert_fail "warn stderr was: $out" ;;
esac

# Test 5: also appends to hooks.log
bash "$REPO_ROOT/hooks/lib/emit-status.sh" ok test-hook "logged too" key=value 2>/dev/null
if grep -q "test-hook STATUS_OK msg=\"logged too\" key=value" "$TESTDIR/progress/hooks.log" 2>/dev/null; then
  assert_pass "ok also appended to hooks.log"
else
  assert_fail "log was: $(cat "$TESTDIR/progress/hooks.log" 2>/dev/null || echo MISSING)"
fi

# Test 6: unknown icon defaults to • (dot) and does not crash
out=$(bash "$REPO_ROOT/hooks/lib/emit-status.sh" gibberish test-hook "fallback" 2>&1 1>/dev/null)
case "$out" in
  *"• harness:"*"fallback"*) assert_pass "unknown icon falls back to •" ;;
  *) assert_fail "fallback stderr was: $out" ;;
esac

echo "---"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
