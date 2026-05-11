#!/usr/bin/env bash
# PreToolUse hook: blocks dangerous operations.
# Exits with code 2 on block (stderr message fed back to Claude).
# Exits 0 on pass.

set -u

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

INPUT=$(cat 2>/dev/null || true)
TOOL_NAME=$(echo "$INPUT" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"tool_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
COMMAND=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"command"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')

source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

HOOK_PATH="$CLAUDE_PLUGIN_ROOT/hooks/pre-tool-safety.sh"

emit_block() {
  local rule_id="$1" reason="$2" allow_var="HARNESS_ALLOW_$1"
  cat >&2 <<EOF
[claude-harness:pre-tool-safety] Blocked by rule $rule_id.
Reason: $reason
Escape hatches (least → most invasive):
  1. Allow this rule:    $allow_var=true in .claude-harness/config.sh
  2. Disable category:   HARNESS_SAFETY_RULES=permissive
  3. Disable hook:       chmod -x $HOOK_PATH
EOF
  "$LOG" pre-tool-safety BLOCK rule="$rule_id" tool="$TOOL_NAME"
  exit 2
}

check_rule() {
  local rule_id="$1" reason="$2"
  local allow_var="HARNESS_ALLOW_$rule_id"
  local allow_val="${!allow_var:-false}"

  if [ "$HARNESS_SAFETY_RULES" = "permissive" ]; then
    "$LOG" pre-tool-safety PASS mode=permissive rule="$rule_id" tool="$TOOL_NAME"
    return 0
  fi
  if [ "$allow_val" = "true" ]; then
    "$LOG" pre-tool-safety PASS mode=allowed rule="$rule_id" tool="$TOOL_NAME"
    return 0
  fi
  emit_block "$rule_id" "$reason"
}

# RM_HOME: rm -rf affecting / ~ or $HOME
if [ "$TOOL_NAME" = "Bash" ] && echo "$COMMAND" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*[[:space:]]+|-[a-zA-Z]*f[a-zA-Z]*[[:space:]]+|--recursive[[:space:]]+|--force[[:space:]]+)+(/|~|\$HOME)'; then
  check_rule RM_HOME "'rm -rf' against /, ~, or \$HOME would erase critical data."
fi

# FORCE_PUSH_MAIN
if [ "$TOOL_NAME" = "Bash" ] && echo "$COMMAND" | grep -qE 'git[[:space:]]+push[[:space:]]+.*(--force|-f)[[:space:]].*(main|master)'; then
  check_rule FORCE_PUSH_MAIN "Force-pushing to main/master overwrites shared history."
fi

# RESET_HARD
if [ "$TOOL_NAME" = "Bash" ] && echo "$COMMAND" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard\b'; then
  check_rule RESET_HARD "'git reset --hard' discards uncommitted work irreversibly."
fi

# CONFIG_EDIT
if { [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "MultiEdit" ]; } && \
   echo "$FILE_PATH" | grep -qE '\.claude-harness/config\.sh$'; then
  check_rule CONFIG_EDIT "Editing .claude-harness/config.sh changes hook behavior project-wide."
fi

exit 0
