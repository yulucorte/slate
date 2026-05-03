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

echo ""
echo "Done. Next steps:"
echo "  cd $TARGET"
echo "  bash init.sh"
echo "  git add progress/ features/ AGENTS.md init.sh"
echo "  git commit -m 'chore: add claude-harness scaffolding'"
