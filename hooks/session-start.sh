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

# Project map (v0.4.0): only loaded if docs/project-map.md exists in the project.
PROJECT_MAP_CONTENT=""
CONSULTING_SKILL_CONTENT=""
if [ -f "$PROJECT_ROOT/docs/project-map.md" ]; then
  PROJECT_MAP_CONTENT=$(head -200 "$PROJECT_ROOT/docs/project-map.md" 2>/dev/null || true)
  if [ -f "$PLUGIN_ROOT/skills/consulting-project-map/SKILL.md" ]; then
    CONSULTING_SKILL_CONTENT=$(cat "$PLUGIN_ROOT/skills/consulting-project-map/SKILL.md" 2>/dev/null || true)
  fi
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

# Branch mismatch check: warn if current git branch differs from active feature's Branch field
BRANCH_WARNING=""
CURRENT_BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || true)
if [ -n "$CURRENT_BRANCH" ] && [ -f "$PROJECT_ROOT/features/in-progress.md" ]; then
  ACTIVE_BRANCH=$(grep -m1 '\*\*Branch\*\*:' "$PROJECT_ROOT/features/in-progress.md" \
    | sed 's/.*\*\*Branch\*\*: *//' | tr -d '[:space:]' || true)
  if [ -n "$ACTIVE_BRANCH" ] && [ "$ACTIVE_BRANCH" != "none" ] \
     && [ "$CURRENT_BRANCH" != "$ACTIVE_BRANCH" ]; then
    BRANCH_WARNING="⚠️ Estás en branch \`$CURRENT_BRANCH\` pero la feature activa usa \`$ACTIVE_BRANCH\`. Para cambiarte: \`git checkout $ACTIVE_BRANCH\`"
  fi
fi

# Build the additionalContext string
CONTEXT="<EXTREMELY_IMPORTANT>
${SKILL_CONTENT}
</EXTREMELY_IMPORTANT>"

if [ -n "$PROJECT_MAP_CONTENT" ]; then
  CONTEXT="${CONTEXT}

<!-- key: project_map -->
## Project map (project_map — read-only)
${CONSULTING_SKILL_CONTENT}

### docs/project-map.md
${PROJECT_MAP_CONTENT}"
fi

CONTEXT="${CONTEXT}

## Recent history
${RECENT_HISTORY}

## In flight
${CURRENT_WORK}

## Active features
${ACTIVE_FEATURES}"

if [ -n "$BRANCH_WARNING" ]; then
  CONTEXT="${CONTEXT}

## Branch warning
${BRANCH_WARNING}"
fi

# Emit JSON for Claude Code's additionalContext
# Use python3 for reliable JSON encoding (always available on macOS)
CONTEXT_JSON=$(printf '%s' "$CONTEXT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
  || printf '"%s"' "$(printf '%s' "$CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')")

printf '{"additionalContext": %s}\n' "$CONTEXT_JSON" 2>/dev/null || exit 0
