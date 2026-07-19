#!/usr/bin/env bash
# PostToolUse hook (all tools): session-lock guardian, heartbeat refresh.
# Touches this session's lock file so it isn't reaped as stale. Strictly
# passive — PostToolUse cannot block anything, and this script never tries.
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"
cd "$PROJECT_ROOT" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)"
[ -z "$GIT_COMMON_DIR" ] && exit 0
case "$GIT_COMMON_DIR" in
  /*) : ;;
  *) GIT_COMMON_DIR="$PROJECT_ROOT/$GIT_COMMON_DIR" ;;
esac
GIT_COMMON_DIR="$(cd "$GIT_COMMON_DIR" 2>/dev/null && pwd -P)"
[ -z "$GIT_COMMON_DIR" ] && exit 0

STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON=$(cat 2>/dev/null || true)
fi
SESSION_ID=$(printf '%s' "$STDIN_JSON" | python3 -c "import sys,json
try:
    print((json.load(sys.stdin).get('session_id') or '').strip())
except Exception:
    print('')" 2>/dev/null || true)
[ -z "$SESSION_ID" ] && exit 0

LOCK_FILE="$GIT_COMMON_DIR/slate-sessions/$SESSION_ID.lock"
[ -f "$LOCK_FILE" ] && touch "$LOCK_FILE" 2>/dev/null
exit 0
