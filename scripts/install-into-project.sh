#!/usr/bin/env bash
# Installs claude-harness templates into the current working directory (the user's project).
# Idempotent: never overwrites existing files.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
TARGET="${1:-$(pwd)}"

# Function: copy a template file only if target doesn't exist
safe_copy() {
  local src="$1"
  local dst="$2"
  if [ -e "$dst" ]; then
    echo "[skip] $dst already exists"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "[ok]   $dst"
  fi
}

echo "Installing claude-harness templates into: $TARGET"

safe_copy "$PLUGIN_ROOT/templates/init.sh" "$TARGET/init.sh"
chmod +x "$TARGET/init.sh" 2>/dev/null || true

safe_copy "$PLUGIN_ROOT/templates/AGENTS.md" "$TARGET/AGENTS.md"

safe_copy "$PLUGIN_ROOT/templates/progress/current.md" "$TARGET/progress/current.md"
safe_copy "$PLUGIN_ROOT/templates/progress/history.md" "$TARGET/progress/history.md"
mkdir -p "$TARGET/progress/subagents" "$TARGET/progress/transcripts"

safe_copy "$PLUGIN_ROOT/templates/features/README.md" "$TARGET/features/README.md"
safe_copy "$PLUGIN_ROOT/templates/features/backlog.md" "$TARGET/features/backlog.md"
safe_copy "$PLUGIN_ROOT/templates/features/in-progress.md" "$TARGET/features/in-progress.md"
safe_copy "$PLUGIN_ROOT/templates/features/done.md" "$TARGET/features/done.md"

# --- v0.2.0: project hooks layer ---

# Alias for clarity — the v0.2.0 block uses PROJECT_ROOT and CLAUDE_PLUGIN_ROOT.
PROJECT_ROOT="$TARGET"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Copy config template if absent (do not overwrite user customizations)
if [ ! -f "$PROJECT_ROOT/.claude-harness/config.sh" ]; then
  mkdir -p "$PROJECT_ROOT/.claude-harness"
  cp "$CLAUDE_PLUGIN_ROOT/templates/.claude-harness/config.sh" "$PROJECT_ROOT/.claude-harness/config.sh"

  # Detect environment and suggest formatter / gate AUTO_PR
  if [ -f "$PROJECT_ROOT/package.json" ] && grep -q '"prettier"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
    sed -i.bak 's/^HARNESS_FORMATTER=.*/HARNESS_FORMATTER=prettier/' "$PROJECT_ROOT/.claude-harness/config.sh" && rm -f "$PROJECT_ROOT/.claude-harness/config.sh.bak"
  elif [ -f "$PROJECT_ROOT/go.mod" ]; then
    sed -i.bak 's/^HARNESS_FORMATTER=.*/HARNESS_FORMATTER=gofmt/' "$PROJECT_ROOT/.claude-harness/config.sh" && rm -f "$PROJECT_ROOT/.claude-harness/config.sh.bak"
  elif [ -f "$PROJECT_ROOT/pyproject.toml" ] && grep -q 'ruff' "$PROJECT_ROOT/pyproject.toml" 2>/dev/null; then
    sed -i.bak 's/^HARNESS_FORMATTER=.*/HARNESS_FORMATTER=ruff/' "$PROJECT_ROOT/.claude-harness/config.sh" && rm -f "$PROJECT_ROOT/.claude-harness/config.sh.bak"
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo "[install-into-project] gh CLI not detected — HARNESS_AUTO_PR will stay disabled."
  fi
fi

# Initialize hooks log
mkdir -p "$PROJECT_ROOT/progress"
[ -f "$PROJECT_ROOT/progress/hooks.log" ] || echo "# claude-harness hooks log — see docs/workflow.md" > "$PROJECT_ROOT/progress/hooks.log"

# Ensure all new hook scripts are executable in the plugin
chmod +x "$CLAUDE_PLUGIN_ROOT/hooks/post-edit-format.sh" \
         "$CLAUDE_PLUGIN_ROOT/hooks/post-edit-in-progress-watcher.sh" \
         "$CLAUDE_PLUGIN_ROOT/hooks/post-edit-done-watcher.sh" \
         "$CLAUDE_PLUGIN_ROOT/hooks/pre-tool-safety.sh" \
         "$CLAUDE_PLUGIN_ROOT/hooks/stop-notify.sh" \
         "$CLAUDE_PLUGIN_ROOT/hooks/lib/"*.sh \
         "$CLAUDE_PLUGIN_ROOT/scripts/harness/"*.sh 2>/dev/null || true

# Pre-populate snapshots so the watchers don't treat pre-existing features as "new"
for f in in-progress done; do
  src="$PROJECT_ROOT/features/$f.md"
  snap="$PROJECT_ROOT/progress/.$f.snapshot"
  if [ -f "$src" ] && [ ! -f "$snap" ]; then
    { grep -E '^## FEAT-[0-9]+:' "$src" 2>/dev/null || true; } | sed -E 's/^## (FEAT-[0-9]+):.*/\1/' > "$snap"
  fi
done

# Append .gitignore entries (idempotent)
GI="$PROJECT_ROOT/.gitignore"
touch "$GI"
for entry in 'progress/hooks.log' 'progress/hooks.log.*' 'progress/.in-progress.snapshot' 'progress/.done.snapshot' '.claude-harness/config.local.sh'; do
  grep -qxF "$entry" "$GI" || echo "$entry" >> "$GI"
done

echo "[install-into-project] v0.2.0 hooks installed. Edit .claude-harness/config.sh to opt in to AUTO_BRANCH / AUTO_PR."

# --- v0.4.0: project context layer (project-map + ADRs) ---
safe_copy "$CLAUDE_PLUGIN_ROOT/templates/docs/project-map.md" "$PROJECT_ROOT/docs/project-map.md"
safe_copy "$CLAUDE_PLUGIN_ROOT/templates/docs/architecture-decisions/README.md" "$PROJECT_ROOT/docs/architecture-decisions/README.md"
echo "[install-into-project] v0.4.0 templates installed: docs/project-map.md, docs/architecture-decisions/README.md."

echo ""
echo "Done. Next steps:"
echo "  cd $TARGET"
echo "  bash init.sh"
echo "  git add progress/ features/ AGENTS.md init.sh"
echo "  git commit -m 'chore: add claude-harness scaffolding'"
