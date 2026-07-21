#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"; rm -rf "$TMPDIR_PROJECT" 2>/dev/null || true' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$PLUGIN_ROOT/scripts/install-into-project.sh"

# --- Test 1: installs all expected files into empty dir ---
TMPDIR_PROJECT=$(mktemp -d)

CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" > /dev/null

expected_files=(
  "init.sh"
  "AGENTS.md"
  "docs/slate/progress/current.md"
  "docs/slate/progress/history.md"
  "docs/slate/features/README.md"
  "docs/slate/features/backlog.md"
  "docs/slate/features/in-progress.md"
  "docs/slate/features/done.md"
  "docs/slate/bugs/open.md"
  "docs/slate/bugs/fixed.md"
  "docs/slate/ideas/inbox.md"
  "docs/slate/ideas/triaged.md"
)

for f in "${expected_files[@]}"; do
  if [ ! -f "$TMPDIR_PROJECT/$f" ]; then
    echo "FAIL: expected file '$f' not found in target dir"
    rm -rf "$TMPDIR_PROJECT"
    exit 1
  fi
done
echo "PASS: all expected files installed"

# --- Test 2: init.sh is executable ---
if [ ! -x "$TMPDIR_PROJECT/init.sh" ]; then
  echo "FAIL: init.sh is not executable"
  rm -rf "$TMPDIR_PROJECT"
  exit 1
fi
echo "PASS: init.sh is executable"

# --- Test 3: idempotency — existing files are NOT overwritten ---
echo "CUSTOM CONTENT" > "$TMPDIR_PROJECT/docs/slate/progress/current.md"
original_content=$(cat "$TMPDIR_PROJECT/docs/slate/progress/current.md")

CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" > /dev/null

content_after=$(cat "$TMPDIR_PROJECT/docs/slate/progress/current.md")
if [ "$original_content" != "$content_after" ]; then
  echo "FAIL: install overwrote existing docs/slate/progress/current.md"
  rm -rf "$TMPDIR_PROJECT"
  exit 1
fi
echo "PASS: idempotency — existing files not overwritten"

# --- Test 4: docs/slate/progress/subagents dir exists ---
if [ ! -d "$TMPDIR_PROJECT/docs/slate/progress/subagents" ]; then
  echo "FAIL: docs/slate/progress/subagents/ not created"
  rm -rf "$TMPDIR_PROJECT"
  exit 1
fi
echo "PASS: docs/slate/progress/subagents/ exists"

# --- Test 5: docs/slate/bugs/ and docs/slate/ideas/ dirs exist ---
for d in "docs/slate/bugs" "docs/slate/ideas"; do
  if [ ! -d "$TMPDIR_PROJECT/$d" ]; then
    echo "FAIL: $d/ not created"
    rm -rf "$TMPDIR_PROJECT"
    exit 1
  fi
done
echo "PASS: docs/slate/bugs/ and docs/slate/ideas/ exist"

rm -rf "$TMPDIR_PROJECT"

echo ""
echo "All install tests passed."
