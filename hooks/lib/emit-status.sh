#!/usr/bin/env bash
# Usage: emit-status.sh <icon> <hook-name> <message> [key=value]...
# Emits a user-visible line to stderr AND logs to progress/hooks.log.
#
# Icons: ok | block | suggest | warn | (anything else → •)
# Stderr format: "<glyph> harness: <message>"
# Log format:    "[ts] <hook> STATUS_<UPPER_ICON> msg=\"...\" key=value..."

set -u

ICON="${1:-info}"
HOOK_NAME="${2:-unknown}"
MESSAGE="${3:-}"
shift 3 2>/dev/null || true

case "$ICON" in
  ok)      GLYPH="✓"; LEVEL="STATUS_OK" ;;
  block)   GLYPH="✗"; LEVEL="STATUS_BLOCK" ;;
  suggest) GLYPH="→"; LEVEL="STATUS_SUGGEST" ;;
  warn)    GLYPH="!"; LEVEL="STATUS_WARN" ;;
  *)       GLYPH="•"; LEVEL="STATUS_INFO" ;;
esac

# Stderr (user-visible)
echo "$GLYPH harness: $MESSAGE" >&2

# Log (machine-readable, includes any extra key=value pairs)
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_SCRIPT="$CLAUDE_PLUGIN_ROOT/hooks/lib/log-hook-event.sh"
if [ -x "$LOG_SCRIPT" ] || [ -f "$LOG_SCRIPT" ]; then
  bash "$LOG_SCRIPT" "$HOOK_NAME" "$LEVEL" "msg=\"$MESSAGE\"" "$@"
fi
