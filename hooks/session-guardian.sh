#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): session-lock guardian, layer 2.
# Blocks git commit/push if the active branch no longer matches what this
# session's lock claimed. Safety net for when layer 1 (session-lock.sh) is
# bypassed — e.g. the branch was changed by hand after the session started.
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"

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

CMD=$(printf '%s' "$STDIN_JSON" | python3 -c "import sys,json
try:
    print((json.load(sys.stdin).get('tool_input') or {}).get('command') or '')
except Exception:
    print('')" 2>/dev/null || true)
[ -z "$CMD" ] && exit 0

echo "$CMD" | grep -qE '(^|[;&|]|&&)[[:space:]]*git[[:space:]]+(commit|push)\b' || exit 0

CWD=$(printf '%s' "$STDIN_JSON" | python3 -c "import sys,json
try:
    print((json.load(sys.stdin).get('cwd') or '').strip())
except Exception:
    print('')" 2>/dev/null || true)
[ -z "$CWD" ] && CWD="$PROJECT_ROOT"

cd "$CWD" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)"
[ -z "$GIT_COMMON_DIR" ] && exit 0
case "$GIT_COMMON_DIR" in
  /*) : ;;
  *) GIT_COMMON_DIR="$CWD/$GIT_COMMON_DIR" ;;
esac
GIT_COMMON_DIR="$(cd "$GIT_COMMON_DIR" 2>/dev/null && pwd -P)"
[ -z "$GIT_COMMON_DIR" ] && exit 0

LOCK_FILE="$GIT_COMMON_DIR/slate-sessions/$SESSION_ID.lock"
[ -f "$LOCK_FILE" ] || exit 0   # no claim on record, nothing to guard

CLAIMED_BRANCH=$(python3 -c "import json
try:
    print(json.load(open('$LOCK_FILE')).get('branch',''))
except Exception:
    print('')" 2>/dev/null || true)
[ -z "$CLAIMED_BRANCH" ] && exit 0

ACTUAL_BRANCH="$(git branch --show-current 2>/dev/null)"

if [ -n "$ACTUAL_BRANCH" ] && [ "$ACTUAL_BRANCH" != "$CLAIMED_BRANCH" ]; then
  REASON="La rama activa ('${ACTUAL_BRANCH}') no coincide con la que esta sesion reclamo ('${CLAIMED_BRANCH}'). Alguien cambio de rama por debajo de esta sesion. Commit/push bloqueado por session-guardian."
  python3 -c "import json,sys
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny', 'permissionDecisionReason': sys.argv[1]}}))
" "$REASON"
fi

exit 0
