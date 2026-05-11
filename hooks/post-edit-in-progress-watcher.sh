#!/usr/bin/env bash
# PostToolUse hook: when features/in-progress.md gains a new feature entry,
# either create the git branch (HARNESS_AUTO_BRANCH=true) or log a suggestion.

set -u

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

INPUT=$(cat 2>/dev/null || true)
FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')

case "$FILE_PATH" in
  */features/in-progress.md) ;;
  *) exit 0 ;;
esac

# shellcheck source=lib/load-config.sh
source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

SNAPSHOT="$PROJECT_ROOT/progress/.in-progress.snapshot"
IP_FILE="$PROJECT_ROOT/features/in-progress.md"

# Acquire project lock
HASH=$(echo -n "$PROJECT_ROOT" | shasum | cut -c1-8)
LOCKFILE="/tmp/claude-harness-$HASH.lock"
exec 9>"$LOCKFILE"
if ! bash "$LIB_DIR/acquire-lock.sh" 5 9; then
  "$LOG" post-edit-in-progress-watcher WARNING reason=lock-timeout
  exit 0
fi

mkdir -p "$(dirname "$SNAPSHOT")"

# Detect new entries
current_ids=$(grep -E '^## FEAT-[0-9]+:' "$IP_FILE" 2>/dev/null | sed -E 's/^## (FEAT-[0-9]+):.*/\1/' || true)
if [ -f "$SNAPSHOT" ]; then
  prev_ids=$(cat "$SNAPSHOT")
else
  prev_ids=""
fi

new_ids=$(comm -23 <(echo "$current_ids" | sort -u) <(echo "$prev_ids" | sort -u))

for feat_id in $new_ids; do
  [ -z "$feat_id" ] && continue
  parse=$(bash "$LIB_DIR/read-feature.sh" "$IP_FILE" "$feat_id" 2>/dev/null) || {
    "$LOG" post-edit-in-progress-watcher ERROR feature="$feat_id" reason=branch-field-invalid
    continue
  }
  branch=$(echo "$parse" | grep '^branch=' | cut -d= -f2-)
  if [ -z "$branch" ] || [ "$branch" = "none" ]; then
    "$LOG" post-edit-in-progress-watcher ERROR feature="$feat_id" reason=branch-missing-or-none
    continue
  fi

  if [ "$HARNESS_AUTO_BRANCH" = "true" ]; then
    if git -C "$PROJECT_ROOT" switch -c "$branch" 2>/dev/null; then
      "$LOG" post-edit-in-progress-watcher SUCCESS feature="$feat_id" branch="$branch" action=switched
    elif git -C "$PROJECT_ROOT" switch "$branch" 2>/dev/null; then
      "$LOG" post-edit-in-progress-watcher SUCCESS feature="$feat_id" branch="$branch" action=already-existed-switched
    else
      "$LOG" post-edit-in-progress-watcher ERROR feature="$feat_id" branch="$branch" reason=git-switch-failed
    fi
  else
    "$LOG" post-edit-in-progress-watcher INFO feature="$feat_id" action=manual-branch-suggested cmd="git switch -c $branch"
  fi
done

# Update snapshot atomically
echo "$current_ids" > "$SNAPSHOT.tmp"
mv "$SNAPSHOT.tmp" "$SNAPSHOT"

exit 0
