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

HOOK="$PLUGIN_ROOT/hooks/post-edit-in-progress-watcher.sh"

# Empty in-progress.md establishes baseline snapshot
echo "" > "$TMPDIR/features/in-progress.md"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/in-progress.md"'"}}' | bash "$HOOK"

# Test 1: non-in-progress.md is ignored
echo '{"tool_input":{"file_path":"/tmp/other.md"}}' | bash "$HOOK"
echo "PASS: ignores non-in-progress.md files"

# Test 2: AUTO_BRANCH=false → log INFO with suggestion, no branch created, stderr shows → harness:
echo 'HARNESS_AUTO_BRANCH=false' > "$TMPDIR/.claude-harness/config.sh"
cp "$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" "$TMPDIR/features/in-progress.md"
suggest_err=$(echo '{"tool_input":{"file_path":"'"$TMPDIR/features/in-progress.md"'"}}' | bash "$HOOK" 2>&1 1>/dev/null)

branch=$(git -C "$TMPDIR" branch --show-current)
if [ "$branch" != "main" ]; then
  echo "FAIL: AUTO_BRANCH=false should not switch branches; on $branch"
  exit 1
fi
if ! grep -q "manual-branch-suggested" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected manual-branch-suggested log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
case "$suggest_err" in
  *"→ harness:"*"ready"*) ;;
  *) echo "FAIL: AUTO_BRANCH=false stderr missing → harness: prefix; got: $suggest_err"; exit 1 ;;
esac
if ! grep -q 'feature=FEAT-007' "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: structured key feature=FEAT-007 not preserved in log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
if ! grep -q 'branch=feat/feat-007-jwt-authentication' "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: structured key branch=... not preserved in log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: AUTO_BRANCH=false logs INFO, emits → harness: to stderr, preserves keys"

# Reset snapshot so the next test sees the feature as new again
rm -f "$TMPDIR/progress/.in-progress.snapshot"

# Test 3: AUTO_BRANCH=true → git switch -c runs, stderr shows ✓ harness:
echo 'HARNESS_AUTO_BRANCH=true' > "$TMPDIR/.claude-harness/config.sh"
ok_err=$(echo '{"tool_input":{"file_path":"'"$TMPDIR/features/in-progress.md"'"}}' | bash "$HOOK" 2>&1 1>/dev/null)

branch=$(git -C "$TMPDIR" branch --show-current)
if [ "$branch" != "feat/feat-007-jwt-authentication" ]; then
  echo "FAIL: AUTO_BRANCH=true expected branch feat/feat-007-jwt-authentication; got '$branch'"
  exit 1
fi
case "$ok_err" in
  *"✓ harness:"*"branch feat/feat-007-jwt-authentication created"*) ;;
  *) echo "FAIL: AUTO_BRANCH=true stderr missing ✓ harness: success line; got: $ok_err"; exit 1 ;;
esac
if ! grep -q 'action=switched' "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: action=switched not preserved in log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: AUTO_BRANCH=true creates branch, emits ✓ harness: to stderr, preserves keys"

# Test 4: malformed feature (Branch: none) → stderr shows ! harness: warn
rm -f "$TMPDIR/progress/.in-progress.snapshot"
git -C "$TMPDIR" checkout -q main
cat > "$TMPDIR/features/in-progress.md" <<'EOF'
## FEAT-999: No branch feature

- **Status**: in_progress
- **Branch**: none
- **Verification**: `true`

### Subtasks
- [ ] do thing
EOF
warn_err=$(echo '{"tool_input":{"file_path":"'"$TMPDIR/features/in-progress.md"'"}}' | bash "$HOOK" 2>&1 1>/dev/null)
case "$warn_err" in
  *"! harness:"*"FEAT-999"*"Branch"*) ;;
  *) echo "FAIL: malformed-feature stderr missing ! harness: warn; got: $warn_err"; exit 1 ;;
esac
if ! grep -q 'reason=branch-missing-or-none' "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: reason=branch-missing-or-none not preserved in log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
if ! grep -q 'feature=FEAT-999' "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: feature=FEAT-999 not preserved in warn log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: malformed feature emits ! harness: to stderr, preserves reason= key"

rm -rf "$TMPDIR"
echo "All in-progress-watcher tests passed."
