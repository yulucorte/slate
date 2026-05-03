#!/usr/bin/env bash
# PreCompact hook: snapshots transcript and logs compaction event.

set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"
HISTORY="$PROJECT_ROOT/progress/history.md"
MATCHER="${1:-manual}"

if [ ! -d "$PROJECT_ROOT/progress" ]; then
  exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)

# Create transcripts dir
mkdir -p "$PROJECT_ROOT/progress/transcripts" 2>/dev/null || true

# Snapshot transcript if available
if [ -n "${CLAUDE_TRANSCRIPT_PATH:-}" ] && [ -f "$CLAUDE_TRANSCRIPT_PATH" ]; then
  SNAP_FILE="$PROJECT_ROOT/progress/transcripts/$(date +%s 2>/dev/null || echo 'snap').snap"
  cp "$CLAUDE_TRANSCRIPT_PATH" "$SNAP_FILE" 2>/dev/null || true
  {
    echo ""
    echo "## $TIMESTAMP — PreCompact triggered (matcher: $MATCHER) — snapshot: $SNAP_FILE"
  } >> "$HISTORY" 2>/dev/null || true
else
  {
    echo ""
    echo "## $TIMESTAMP — PreCompact triggered (matcher: $MATCHER) — no transcript available"
  } >> "$HISTORY" 2>/dev/null || true
fi
