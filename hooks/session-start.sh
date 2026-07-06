#!/usr/bin/env bash
# SessionStart hook: injects LIGHTWEIGHT harness state into Claude's session.
# Emits JSON with additionalContext. Never exits non-zero.
#
# Design notes:
#  - Does NOT dump the SKILL.md (the protocol loads via the Skill tool on demand).
#  - Does NOT dump features/backlog.md (read on demand via managing-feature-list).
#  - in-progress is injected as an INDEX (one line per FEAT), not full blocks.
#  - history is capped to the last line(s), not tail -30.
#  - Behaviour differs by session source (startup|clear vs compact|resume).
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${CURSOR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}}"
PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"

# Claude Code passes the SessionStart payload as JSON on stdin; the "source"
# field is one of: startup | clear | resume | compact. Read it so we can inject
# less on compact/resume (the agent already internalized the protocol).
STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON=$(cat 2>/dev/null || true)
fi
SOURCE=$(printf '%s' "$STDIN_JSON" | python3 -c "import sys,json
try:
    print((json.load(sys.stdin).get('source') or '').strip())
except Exception:
    print('')" 2>/dev/null || true)
[ -z "$SOURCE" ] && SOURCE="startup"

# Only operate if this project has been initialized with slate
if [ ! -d "$PROJECT_ROOT/progress" ] || [ ! -d "$PROJECT_ROOT/features" ]; then
  exit 0
fi

# Run init.sh if present, append output to history
if [ -f "$PROJECT_ROOT/init.sh" ]; then
  {
    echo ""
    echo "## $(date '+%Y-%m-%d %H:%M:%S') — SessionStart init.sh"
    bash "$PROJECT_ROOT/init.sh" 2>&1 || true
  } >> "$PROJECT_ROOT/progress/history.md" 2>/dev/null || true
fi

# in-progress as an INDEX: one line per FEAT (ID + title + status). Full
# descriptions, criteria and subtasks stay in the file; the agent opens it when
# it actually works that feature.
INPROGRESS_INDEX=""
if [ -f "$PROJECT_ROOT/features/in-progress.md" ]; then
  INPROGRESS_INDEX=$(awk '
    function flush(){ if(id!=""){ printf "- %s%s\n", id, (st!=""?" ["st"]":"") } }
    /^## FEAT-/ { flush(); id=substr($0,4); st=""; next }
    /^- \*\*Status\*\*:/ { s=$0; sub(/^- \*\*Status\*\*:[ ]*/,"",s); st=s }
    END { flush() }
  ' "$PROJECT_ROOT/features/in-progress.md" 2>/dev/null || true)
fi
[ -z "$INPROGRESS_INDEX" ] && INPROGRESS_INDEX="(ninguna feature en progreso)"

# Bugs open + ideas pending: counts and IDs only, never full entry bodies —
# same "index, not dump" principle as INPROGRESS_INDEX above. Skip cleanly
# if bugs/ or ideas/ don't exist (projects installed before this feature).
BUGS_LINE=""
if [ -f "$PROJECT_ROOT/bugs/open.md" ]; then
  BUG_IDS=$(grep -o '^## BUG-[0-9]\{3\}' "$PROJECT_ROOT/bugs/open.md" 2>/dev/null | sed 's/^## //' | paste -sd, - || true)
  BUG_COUNT=$(printf '%s' "$BUG_IDS" | tr ',' '\n' | grep -c . || true)
  [ "${BUG_COUNT:-0}" -gt 0 ] 2>/dev/null && BUGS_LINE="## Bugs abiertos: ${BUG_COUNT} (${BUG_IDS})"
fi

IDEAS_LINE=""
if [ -f "$PROJECT_ROOT/ideas/inbox.md" ]; then
  IDEA_COUNT=$(grep -c '^- ' "$PROJECT_ROOT/ideas/inbox.md" 2>/dev/null || true)
  [ "${IDEA_COUNT:-0}" -gt 0 ] 2>/dev/null && IDEAS_LINE="## Ideas pendientes: ${IDEA_COUNT} (correr /ideas-triage)"
fi

# Last N non-empty lines of history.md.
history_tail() {
  local n="$1"
  [ -f "$PROJECT_ROOT/progress/history.md" ] || return 0
  grep -v '^[[:space:]]*$' "$PROJECT_ROOT/progress/history.md" 2>/dev/null | tail -n "$n" || true
}

case "$SOURCE" in
  compact|resume)
    # The agent already has the protocol in context. Inject the bare minimum:
    # in-progress index + the single most recent history line. No header.
    CONTEXT="## In-progress (índice)
${INPROGRESS_INDEX}

## History (última)
$(history_tail 1)"
    [ -n "$BUGS_LINE" ] && CONTEXT="${CONTEXT}
${BUGS_LINE}"
    [ -n "$IDEAS_LINE" ] && CONTEXT="${CONTEXT}
${IDEAS_LINE}"
    ;;
  *)  # startup | clear (and any unknown source, treated as a cold start)
    CURRENT_WORK=""
    if [ -f "$PROJECT_ROOT/progress/current.md" ]; then
      CURRENT_WORK=$(cat "$PROJECT_ROOT/progress/current.md" 2>/dev/null || true)
    fi
    CONTEXT="Slate activo — estado abajo. Protocolo completo en la skill using-slate si lo necesitas.

## In-progress (índice)
${INPROGRESS_INDEX}

## En vuelo
${CURRENT_WORK}

## History (reciente)
$(history_tail 2)"
    [ -n "$BUGS_LINE" ] && CONTEXT="${CONTEXT}
${BUGS_LINE}"
    [ -n "$IDEAS_LINE" ] && CONTEXT="${CONTEXT}
${IDEAS_LINE}"
    ;;
esac

CONTEXT_JSON=$(printf '%s' "$CONTEXT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
  || printf '"%s"' "$(printf '%s' "$CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')")
printf '{"additionalContext": %s}\n' "$CONTEXT_JSON" 2>/dev/null || exit 0
