#!/usr/bin/env bash
# Test: doctor.sh exits 0 on healthy install, prints fix hints on failures.
set -u
TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

assert_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
assert_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# Test 1: doctor.sh runs without crashing in an empty project
mkdir -p "$TESTDIR/empty"
out=$(cd "$TESTDIR/empty" && PROJECT_ROOT="$TESTDIR/empty" bash "$REPO_ROOT/scripts/harness/doctor.sh" 2>&1) || true
case "$out" in
  *"claude-harness doctor"*) assert_pass "doctor prints header" ;;
  *) assert_fail "no header in: $out" ;;
esac

# Test 2: doctor.sh detects missing .claude-harness/config.sh and prints fix
case "$out" in
  *"config.sh"*"Fix:"*"install-into-project.sh"*) assert_pass "missing config produces install fix hint" ;;
  *) assert_fail "no install hint in: $out" ;;
esac

# Test 3: with a healthy install (config exists, dirs present), doctor exits 0
mkdir -p "$TESTDIR/healthy/.claude-harness" "$TESTDIR/healthy/features" "$TESTDIR/healthy/progress"
touch "$TESTDIR/healthy/features/in-progress.md" "$TESTDIR/healthy/features/done.md" "$TESTDIR/healthy/features/backlog.md"
echo "# config" > "$TESTDIR/healthy/.claude-harness/config.sh"
PROJECT_ROOT="$TESTDIR/healthy" bash "$REPO_ROOT/scripts/harness/doctor.sh" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  assert_pass "healthy install exits 0"
else
  assert_fail "healthy install exited $rc"
fi

# Test 4: corrupt config.sh produces a "Fix:" hint
echo "this is not valid bash (((" > "$TESTDIR/healthy/.claude-harness/config.sh"
out=$(PROJECT_ROOT="$TESTDIR/healthy" bash "$REPO_ROOT/scripts/harness/doctor.sh" 2>&1) || true
case "$out" in
  *"config.sh"*"syntax"*"Fix:"*) assert_pass "corrupt config produces fix hint" ;;
  *) assert_fail "no syntax fix in: $out" ;;
esac

# Test 5: missing gh CLI WHEN HARNESS_AUTO_PR=true is reported (skip if gh installed)
if ! command -v gh >/dev/null 2>&1; then
  echo "# config" > "$TESTDIR/healthy/.claude-harness/config.sh"
  out=$(HARNESS_AUTO_PR=true PROJECT_ROOT="$TESTDIR/healthy" bash "$REPO_ROOT/scripts/harness/doctor.sh" 2>&1) || true
  case "$out" in
    *"gh CLI"*"Fix:"*"brew install gh"*) assert_pass "missing gh when AUTO_PR produces install hint" ;;
    *) assert_fail "no gh hint: $out" ;;
  esac
else
  echo "SKIP: gh CLI present, cannot test absent-gh path"
fi

echo "---"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
