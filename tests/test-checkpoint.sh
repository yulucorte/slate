#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"; rm -rf "$TMPDIR_REPO" 2>/dev/null || true' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKPOINT="$PLUGIN_ROOT/scripts/lib/checkpoint.sh"

# --- Setup: create a temp git repo ---
TMPDIR_REPO=$(mktemp -d)
cd "$TMPDIR_REPO"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

# Create initial commit so HEAD exists
echo "init" > init.txt
git add init.txt
git commit -q -m "init"

mkdir -p progress features

# --- Test 1: checkpoint creates a commit when there are changes ---
echo "# Current work" > progress/current.md
echo "in flight task" >> progress/current.md

commit_before=$(git rev-parse HEAD)
bash "$CHECKPOINT" "$TMPDIR_REPO" "test: checkpoint commit"
commit_after=$(git rev-parse HEAD)

if [ "$commit_before" = "$commit_after" ]; then
  echo "FAIL: expected a new commit to be created"
  rm -rf "$TMPDIR_REPO"
  exit 1
fi

msg=$(git log -1 --pretty=%s)
if [ "$msg" != "test: checkpoint commit" ]; then
  echo "FAIL: commit message wrong. Got: '$msg'"
  rm -rf "$TMPDIR_REPO"
  exit 1
fi
echo "PASS: checkpoint creates commit with correct message"

# --- Test 2: No new commit when nothing changed ---
commit_before=$(git rev-parse HEAD)
bash "$CHECKPOINT" "$TMPDIR_REPO" "test: should not commit"
commit_after=$(git rev-parse HEAD)

if [ "$commit_before" != "$commit_after" ]; then
  echo "FAIL: expected no new commit when nothing changed"
  rm -rf "$TMPDIR_REPO"
  exit 1
fi
echo "PASS: checkpoint does not create commit when no changes"

# --- Test 3: checkpoint is silent (exit 0) in a non-git directory ---
TMPDIR_NOGIT=$(mktemp -d)
bash "$CHECKPOINT" "$TMPDIR_NOGIT" "should be silent"
rm -rf "$TMPDIR_NOGIT"
echo "PASS: checkpoint exits 0 in non-git directory"

# Cleanup
rm -rf "$TMPDIR_REPO"

echo ""
echo "All checkpoint tests passed."
