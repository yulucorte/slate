#!/usr/bin/env bash
# Install slate templates into the current project. Idempotent.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-$(pwd)}"

if [ ! -d "$TARGET" ]; then
  echo "Target directory does not exist: $TARGET" >&2
  exit 1
fi

cd "$TARGET"

# Required directories
mkdir -p progress/subagents features bugs ideas docs/superpowers/plans docs/superpowers/specs

# Copy templates without overwriting existing user content
_copy_if_missing() {
  local src="$1" dst="$2"
  if [ ! -e "$dst" ]; then
    cp "$src" "$dst"
    echo "  + $dst"
  else
    echo "  = $dst (kept)"
  fi
}

echo "Installing slate templates into $TARGET..."

_copy_if_missing "$PLUGIN_ROOT/templates/AGENTS.md"             "AGENTS.md"
_copy_if_missing "$PLUGIN_ROOT/templates/init.sh"               "init.sh"
chmod +x init.sh 2>/dev/null || true

_copy_if_missing "$PLUGIN_ROOT/templates/progress/.gitignore"   "progress/.gitignore"
_copy_if_missing "$PLUGIN_ROOT/templates/progress/current.md"   "progress/current.md"
_copy_if_missing "$PLUGIN_ROOT/templates/progress/history.md"   "progress/history.md"

_copy_if_missing "$PLUGIN_ROOT/templates/features/README.md"    "features/README.md"
_copy_if_missing "$PLUGIN_ROOT/templates/features/backlog.md"   "features/backlog.md"
_copy_if_missing "$PLUGIN_ROOT/templates/features/in-progress.md" "features/in-progress.md"
_copy_if_missing "$PLUGIN_ROOT/templates/features/done.md"      "features/done.md"

_copy_if_missing "$PLUGIN_ROOT/templates/bugs/open.md"        "bugs/open.md"
_copy_if_missing "$PLUGIN_ROOT/templates/bugs/fixed.md"       "bugs/fixed.md"

_copy_if_missing "$PLUGIN_ROOT/templates/ideas/inbox.md"      "ideas/inbox.md"
_copy_if_missing "$PLUGIN_ROOT/templates/ideas/triaged.md"    "ideas/triaged.md"

echo ""
echo "Done. Next steps:"
echo "  1. Open AGENTS.md and fill in the project-specific TODOs."
echo "  2. Start a new Claude Code session; SessionStart will inject context."
