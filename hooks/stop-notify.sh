#!/usr/bin/env bash
# Stop hook: OS notification with 30s debounce.

set -u

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

if [ "$HARNESS_NOTIFY" != "true" ]; then
  exit 0
fi

# Debounce: hash project root, track last fire time
source "$LIB_DIR/hash-path.sh"
HASH=$(hash_path "$PROJECT_ROOT")
STATE="/tmp/claude-harness-last-notify-$HASH"
NOW=$(date +%s)
LAST=$(cat "$STATE" 2>/dev/null || echo 0)
DELTA=$((NOW - LAST))
COUNTER_FILE="/tmp/claude-harness-counter-$HASH"

if [ "$DELTA" -lt 30 ]; then
  cur=$(cat "$COUNTER_FILE" 2>/dev/null || echo 1)
  echo $((cur + 1)) > "$COUNTER_FILE"
  "$LOG" stop-notify SKIP reason=debounce delta_s="$DELTA" queued="$(cat $COUNTER_FILE)"
  exit 0
fi

queued=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
rm -f "$COUNTER_FILE"
echo "$NOW" > "$STATE"

if [ "$queued" -gt 0 ]; then
  MSG="Claude finished. $queued event(s) queued."
else
  MSG="Claude finished. Check progress/current.md"
fi

dispatch() {
  if [ -n "${NOTIFY_TEST_MODE:-}" ]; then
    echo "$MSG" > "${NOTIFY_TEST_FILE:-/tmp/notify-test.out}"
    return 0
  fi
  case "$(uname -s)" in
    Darwin) osascript -e "display notification \"$MSG\" with title \"Claude Code\"" 2>/dev/null ;;
    Linux)  command -v notify-send >/dev/null 2>&1 && notify-send "Claude Code" "$MSG" ;;
  esac
}

dispatch
"$LOG" stop-notify SUCCESS queued="$queued"
exit 0
