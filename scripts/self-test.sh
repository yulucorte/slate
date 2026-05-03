#!/usr/bin/env bash
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PLUGIN_ROOT"

PASS=0
FAIL=0

for test in tests/test-*.sh; do
  echo "Running $test..."
  if bash "$test"; then
    echo "  PASS"
    PASS=$((PASS + 1))
  else
    echo "  FAIL"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Results: $PASS pass, $FAIL fail"
[ $FAIL -eq 0 ]
