#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$PLUGIN_ROOT/hooks/lib/hash-path.sh"

# Test 1: deterministic — same input always produces same output
h1=$(hash_path "/tmp/test/project")
h2=$(hash_path "/tmp/test/project")
if [ "$h1" != "$h2" ]; then
  echo "FAIL: not deterministic ('$h1' vs '$h2')"
  exit 1
fi
echo "PASS: hash is deterministic"

# Test 2: different inputs → different hashes (collision check)
ha=$(hash_path "/tmp/project-a")
hb=$(hash_path "/tmp/project-b")
if [ "$ha" = "$hb" ]; then
  echo "FAIL: collision on distinct paths"
  exit 1
fi
echo "PASS: distinct paths produce distinct hashes"

# Test 3: 8 chars output
h=$(hash_path "/some/path")
if [ "${#h}" -ne 8 ]; then
  echo "FAIL: expected 8 chars, got ${#h}: '$h'"
  exit 1
fi
echo "PASS: output is 8 chars"

echo "All hash-path tests passed."
