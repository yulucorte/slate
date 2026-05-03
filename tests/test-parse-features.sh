#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$PLUGIN_ROOT/tests/fixtures/sample-feature-list.md"

# Source the library under test
# shellcheck source=../scripts/lib/parse-features.sh
source "$PLUGIN_ROOT/scripts/lib/parse-features.sh"

# --- Test: list_feature_ids ---
result=$(list_feature_ids "$FIXTURE")
expected="FEAT-001
FEAT-002
FEAT-003"
if [ "$result" != "$expected" ]; then
  echo "FAIL list_feature_ids: expected '$expected', got '$result'"
  exit 1
fi
echo "PASS: list_feature_ids returns FEAT-001, FEAT-002, FEAT-003"

# --- Test: next_feature_id ---
# Create a temp dir with the fixture as the only .md file
TMPDIR_NF=$(mktemp -d)
cp "$FIXTURE" "$TMPDIR_NF/sample-feature-list.md"
result=$(next_feature_id "$TMPDIR_NF")
if [ "$result" != "FEAT-004" ]; then
  echo "FAIL next_feature_id: expected FEAT-004, got '$result'"
  rm -rf "$TMPDIR_NF"
  exit 1
fi
rm -rf "$TMPDIR_NF"
echo "PASS: next_feature_id returns FEAT-004"

# --- Test: next_feature_id on empty dir ---
TMPDIR_EMPTY=$(mktemp -d)
result=$(next_feature_id "$TMPDIR_EMPTY")
if [ "$result" != "FEAT-001" ]; then
  echo "FAIL next_feature_id (empty): expected FEAT-001, got '$result'"
  rm -rf "$TMPDIR_EMPTY"
  exit 1
fi
rm -rf "$TMPDIR_EMPTY"
echo "PASS: next_feature_id returns FEAT-001 for empty dir"

# --- Test: feature_status ---
result=$(feature_status "$FIXTURE" "FEAT-001")
if [ "$result" != "in_progress" ]; then
  echo "FAIL feature_status FEAT-001: expected 'in_progress', got '$result'"
  exit 1
fi
echo "PASS: feature_status FEAT-001 = in_progress"

result=$(feature_status "$FIXTURE" "FEAT-002")
if [ "$result" != "backlog" ]; then
  echo "FAIL feature_status FEAT-002: expected 'backlog', got '$result'"
  exit 1
fi
echo "PASS: feature_status FEAT-002 = backlog"

result=$(feature_status "$FIXTURE" "FEAT-003")
if [ "$result" != "done" ]; then
  echo "FAIL feature_status FEAT-003: expected 'done', got '$result'"
  exit 1
fi
echo "PASS: feature_status FEAT-003 = done"

# --- Test: count_subtasks ---
# FEAT-001 has 2 checked [x] and 1 unchecked [ ]
checked=$(count_subtasks "$FIXTURE" "FEAT-001" "\[x\]")
if [ "$checked" != "2" ]; then
  echo "FAIL count_subtasks checked: expected 2, got '$checked'"
  exit 1
fi
echo "PASS: count_subtasks FEAT-001 checked = 2"

unchecked=$(count_subtasks "$FIXTURE" "FEAT-001" "\[ \]")
if [ "$unchecked" != "1" ]; then
  echo "FAIL count_subtasks unchecked: expected 1, got '$unchecked'"
  exit 1
fi
echo "PASS: count_subtasks FEAT-001 unchecked = 1"

echo ""
echo "All parse-features tests passed."
