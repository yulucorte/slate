#!/usr/bin/env bash
# Usage: log-hook-event.sh <hook-name> <event-type> [key=value]...
# Appends a structured event to $PROJECT_ROOT/progress/hooks.log.
# Rotates when file exceeds $HARNESS_LOG_MAX_BYTES; keeps $HARNESS_LOG_ROTATIONS rotations,
# oldest gzipped.

set -u

HOOK_NAME="${1:-unknown}"
EVENT_TYPE="${2:-INFO}"
shift 2 || true

# Defaults if env not loaded
: "${PROJECT_ROOT:=$(pwd)}"
: "${HARNESS_LOG_MAX_BYTES:=5242880}"
: "${HARNESS_LOG_ROTATIONS:=3}"

LOG="$PROJECT_ROOT/progress/hooks.log"
mkdir -p "$(dirname "$LOG")"

# Build line
TS="$(date '+%Y-%m-%d %H:%M:%S')"
LINE="[$TS] $HOOK_NAME $EVENT_TYPE"
for kv in "$@"; do
  LINE="$LINE $kv"
done

# Append atomically
echo "$LINE" >> "$LOG"

# Rotate if needed
size=$(wc -c < "$LOG" 2>/dev/null | tr -d ' ')
if [ "${size:-0}" -gt "$HARNESS_LOG_MAX_BYTES" ]; then
  # Drop oldest (.N or .N.gz)
  oldest_n="$HARNESS_LOG_ROTATIONS"
  [ -f "$LOG.$oldest_n" ] && rm -f "$LOG.$oldest_n"
  [ -f "$LOG.$oldest_n.gz" ] && rm -f "$LOG.$oldest_n.gz"

  # Shift each rotation up by one (from oldest-1 down to 1)
  i=$((oldest_n - 1))
  while [ "$i" -ge 1 ]; do
    next=$((i + 1))
    if [ -f "$LOG.$i.gz" ]; then
      mv "$LOG.$i.gz" "$LOG.$next.gz"
    elif [ -f "$LOG.$i" ]; then
      # If we're about to become the OLDEST kept rotation, gzip
      if [ "$next" -eq "$oldest_n" ]; then
        gzip -c "$LOG.$i" > "$LOG.$next.gz"
        rm -f "$LOG.$i"
      else
        mv "$LOG.$i" "$LOG.$next"
      fi
    fi
    i=$((i - 1))
  done

  # Rotate current → .1
  mv "$LOG" "$LOG.1"
  : > "$LOG"
fi
