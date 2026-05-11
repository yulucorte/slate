#!/usr/bin/env bash
# PostToolUse hook: formats the edited file based on extension.
# Silent skip for files inside features/, progress/, .claude-harness/.
# Never blocks Claude (exit 0 always).

set -u

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

# Read JSON from stdin
INPUT=$(cat 2>/dev/null || true)
FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')

[ -z "${FILE_PATH:-}" ] && exit 0

# Silent skip for harness-managed paths
case "$FILE_PATH" in
  */features/*|*/progress/*|*/.claude-harness/*) exit 0 ;;
esac

# Load config (provides HARNESS_FORMATTER)
# shellcheck source=lib/load-config.sh
source "$LIB_DIR/load-config.sh"

LOG="$LIB_DIR/log-hook-event.sh"

if [ "$HARNESS_FORMATTER" = "none" ]; then
  # Silent skip: formatter disabled is the default config; logging would spam.
  exit 0
fi

# Map extension → formatter command (only for configured formatter)
ext="${FILE_PATH##*.}"
case "$HARNESS_FORMATTER" in
  prettier)
    case "$ext" in
      ts|tsx|js|jsx|json|md|css|scss|html|yaml|yml) cmd="prettier --write" ;;
      *) "$LOG" post-edit-format SKIP reason=ext-not-supported file="$FILE_PATH" ext="$ext"; exit 0 ;;
    esac ;;
  gofmt)
    case "$ext" in
      go) cmd="gofmt -w" ;;
      *) "$LOG" post-edit-format SKIP reason=ext-not-supported file="$FILE_PATH" ext="$ext"; exit 0 ;;
    esac ;;
  ruff)
    case "$ext" in
      py) cmd="ruff format" ;;
      *) "$LOG" post-edit-format SKIP reason=ext-not-supported file="$FILE_PATH" ext="$ext"; exit 0 ;;
    esac ;;
  *)
    "$LOG" post-edit-format ERROR reason=unknown-formatter formatter="$HARNESS_FORMATTER"
    exit 0 ;;
esac

bin="${cmd%% *}"
if ! command -v "$bin" >/dev/null 2>&1; then
  "$LOG" post-edit-format SKIP reason=formatter-missing formatter="$HARNESS_FORMATTER"
  exit 0
fi

if $cmd "$FILE_PATH" >/dev/null 2>&1; then
  "$LOG" post-edit-format SUCCESS file="$FILE_PATH" formatter="$HARNESS_FORMATTER"
else
  "$LOG" post-edit-format ERROR file="$FILE_PATH" formatter="$HARNESS_FORMATTER"
fi

exit 0
