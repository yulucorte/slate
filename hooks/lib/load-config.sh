#!/usr/bin/env bash
# Loads project config with defaults fallback.
# Expects $PROJECT_ROOT and $LIB_DIR to be set by the caller.
# Source this; do not execute.

# 1. Always load defaults first
# shellcheck source=defaults.sh
source "$LIB_DIR/defaults.sh"

# 2. Load project config if present and syntactically valid
_HARNESS_CONFIG="$PROJECT_ROOT/.claude-harness/config.sh"
if [ -f "$_HARNESS_CONFIG" ]; then
  if bash -n "$_HARNESS_CONFIG" 2>/tmp/harness-syntax-err.$$; then
    # shellcheck source=/dev/null
    source "$_HARNESS_CONFIG"
  else
    err=$(cat /tmp/harness-syntax-err.$$ 2>/dev/null | tr '\n' ' ')
    "$LIB_DIR/log-hook-event.sh" load-config ERROR \
      reason=syntax-invalid \
      file="$_HARNESS_CONFIG" \
      err="$err"
    echo "[claude-harness] config.sh has syntax errors; using defaults. See progress/hooks.log" >&2
  fi
  rm -f /tmp/harness-syntax-err.$$
fi

# 3. Per-user local overrides (gitignored)
_HARNESS_LOCAL="$PROJECT_ROOT/.claude-harness/config.local.sh"
if [ -f "$_HARNESS_LOCAL" ] && bash -n "$_HARNESS_LOCAL" 2>/dev/null; then
  # shellcheck source=/dev/null
  source "$_HARNESS_LOCAL"
fi

unset _HARNESS_CONFIG _HARNESS_LOCAL
