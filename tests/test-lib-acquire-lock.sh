#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"

SCRIPT="$PLUGIN_ROOT/hooks/lib/acquire-lock.sh"

# Test 1: acquires immediately when free
if ! (
  exec 9>"$TMPDIR/test.lock"
  bash "$SCRIPT" 2 9
); then
  echo "FAIL acquire: should succeed when lock is free"
  exit 1
fi
echo "PASS: acquires immediately when free"

# Test 2: times out when held
(
  exec 9>"$TMPDIR/held.lock"
  flock 9
  sleep 3
) &
holder_pid=$!
sleep 0.3

set +e
(
  exec 9>"$TMPDIR/held.lock"
  bash "$SCRIPT" 1 9
)
rc=$?
set -e

wait "$holder_pid" 2>/dev/null || true

if [ "$rc" -eq 0 ]; then
  echo "FAIL timeout: should have returned non-zero"
  exit 1
fi
echo "PASS: returns non-zero on timeout"

rm -rf "$TMPDIR"
echo "All acquire-lock tests passed."
