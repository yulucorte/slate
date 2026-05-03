#!/usr/bin/env bash
# PostToolUse hook: auto-commits edits to progress/ or features/ files.

set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"

# The edited file path is passed as the first argument by Claude Code
EDITED_FILE="${1:-}"

if [ -z "$EDITED_FILE" ]; then
  exit 0
fi

# Only operate on progress/ or features/ files
case "$EDITED_FILE" in
  *progress/*|*features/*)
    ;;
  *)
    exit 0
    ;;
esac

# Resolve to relative path for commit message
REL_FILE="${EDITED_FILE#$PROJECT_ROOT/}"

cd "$PROJECT_ROOT" 2>/dev/null || exit 0

git add "$EDITED_FILE" 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "chore(harness): autosave $REL_FILE" --no-verify --quiet 2>/dev/null || true
fi
