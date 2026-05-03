#!/usr/bin/env bash
# SessionStart hook: injects harness context into Claude's session if project is initialized.
# Emits JSON with additionalContext. Never exits non-zero.

set -uo pipefail

# Detect plugin root (Claude Code, Cursor, fallback)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${CURSOR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}}"
PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"

# Only operate if this project has been initialized with claude-harness
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

# Gather context pieces
SKILL_CONTENT=""
if [ -f "$PLUGIN_ROOT/skills/using-claude-harness/SKILL.md" ]; then
  SKILL_CONTENT=$(cat "$PLUGIN_ROOT/skills/using-claude-harness/SKILL.md" 2>/dev/null || true)
fi

RECENT_HISTORY=""
if [ -f "$PROJECT_ROOT/progress/history.md" ]; then
  RECENT_HISTORY=$(tail -30 "$PROJECT_ROOT/progress/history.md" 2>/dev/null || true)
fi

CURRENT_WORK=""
if [ -f "$PROJECT_ROOT/progress/current.md" ]; then
  CURRENT_WORK=$(cat "$PROJECT_ROOT/progress/current.md" 2>/dev/null || true)
fi

# Extract first 10 active features from in-progress.md and backlog.md
ACTIVE_FEATURES=""
for ffile in "$PROJECT_ROOT/features/in-progress.md" "$PROJECT_ROOT/features/backlog.md"; do
  if [ -f "$ffile" ]; then
    ACTIVE_FEATURES="${ACTIVE_FEATURES}$(awk '/^## FEAT-/{count++; if(count>10) exit} count>0{print}' "$ffile" 2>/dev/null || true)"
  fi
done

# Build the additionalContext string
CONTEXT="<EXTREMELY_IMPORTANT>
${SKILL_CONTENT}
</EXTREMELY_IMPORTANT>

## Recent history
${RECENT_HISTORY}

## In flight
${CURRENT_WORK}

## Active features
${ACTIVE_FEATURES}"

# Emit JSON for Claude Code's additionalContext
# Use python3 for reliable JSON encoding (always available on macOS)
CONTEXT_JSON=$(printf '%s' "$CONTEXT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
  || printf '"%s"' "$(printf '%s' "$CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')")

printf '{"additionalContext": %s}\n' "$CONTEXT_JSON" 2>/dev/null || exit 0
