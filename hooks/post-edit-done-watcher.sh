#!/usr/bin/env bash
# PostToolUse hook: when features/done.md gains a new entry, either open a PR
# (HARNESS_AUTO_PR=true) or send a notification.

set -u

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

INPUT=$(cat 2>/dev/null || true)
FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')

case "$FILE_PATH" in
  */features/done.md) ;;
  *) exit 0 ;;
esac

# shellcheck source=lib/load-config.sh
source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

SNAPSHOT="$PROJECT_ROOT/progress/.done.snapshot"
DONE_FILE="$PROJECT_ROOT/features/done.md"

# Acquire project lock
source "$LIB_DIR/hash-path.sh"
HASH=$(hash_path "$PROJECT_ROOT")
LOCKFILE="/tmp/claude-harness-$HASH.lock"
exec 9>"$LOCKFILE"
if ! bash "$LIB_DIR/acquire-lock.sh" 5 9; then
  "$LOG" post-edit-done-watcher WARNING reason=lock-timeout
  exit 0
fi

mkdir -p "$(dirname "$SNAPSHOT")"

# Detect new entries (treat missing snapshot as empty prev_ids — consistent
# with in-progress-watcher and required so test flows that rm the snapshot
# still reach the per-feature processing path).
current_ids=$(grep -E '^## FEAT-[0-9]+:' "$DONE_FILE" 2>/dev/null | sed -E 's/^## (FEAT-[0-9]+):.*/\1/' || true)
if [ -f "$SNAPSHOT" ]; then
  prev_ids=$(cat "$SNAPSHOT")
else
  prev_ids=""
fi

new_ids=$(comm -23 <(echo "$current_ids" | sort -u) <(echo "$prev_ids" | sort -u))

current_branch=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "")

for feat_id in $new_ids; do
  [ -z "$feat_id" ] && continue
  parse=$(bash "$LIB_DIR/read-feature.sh" "$DONE_FILE" "$feat_id" 2>/dev/null) || {
    "$LOG" post-edit-done-watcher ERROR feature="$feat_id" reason=parse-failed
    continue
  }
  branch=$(echo "$parse" | grep '^branch=' | cut -d= -f2-)

  if [ -n "$current_branch" ] && [ -n "$branch" ] && [ "$branch" != "none" ] && [ "$current_branch" != "$branch" ]; then
    "$LOG" post-edit-done-watcher WARNING reason=branch-mismatch feature="$feat_id" current="$current_branch" expected="$branch"
    continue
  fi

  if [ "$HARNESS_AUTO_PR" = "true" ]; then
    bash "$CLAUDE_PLUGIN_ROOT/scripts/harness/pr-open.sh" "$feat_id"
    "$LOG" post-edit-done-watcher SUCCESS feature="$feat_id" action=pr-open-invoked
  else
    "$LOG" post-edit-done-watcher INFO feature="$feat_id" action=feature-ready-for-pr cmd="bash scripts/harness/pr-open.sh $feat_id"
    # Note: no inline notification dispatch — the natural Stop hook handles user-facing alerts.
    # This prevents the done-watcher's "feature ready" event from suppressing the session-end
    # notification via the shared 30s debounce bucket.
  fi
done

# Update snapshot atomically
echo "$current_ids" > "$SNAPSHOT.tmp"
mv "$SNAPSHOT.tmp" "$SNAPSHOT"

exit 0
