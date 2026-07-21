#!/usr/bin/env bash
# SessionEnd hook: drains current.md into history.md and auto-commits.
# SessionEnd does not support additionalContext output.

set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"

CURRENT="$PROJECT_ROOT/docs/slate/progress/current.md"
HISTORY="$PROJECT_ROOT/docs/slate/progress/history.md"

if [ ! -f "$CURRENT" ]; then
  exit 0
fi

# Check if current.md has actual work (more than just the header + "none in flight")
if ! grep -qv '^#\|^_\|^<!--\|^$\|^-->' "$CURRENT" 2>/dev/null; then
  exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)

{
  echo ""
  echo "## $TIMESTAMP — Session end"
  cat "$CURRENT"
} >> "$HISTORY" 2>/dev/null || true

# Reset current.md to empty state
cat > "$CURRENT" << 'EOF'
# Current work

_(none in flight)_

<!-- This file is auto-managed by slate:tracking-progress.
     Entries here represent IN-FLIGHT work for the current session.
     At session end, completed entries are moved to history.md;
     orphaned entries become CARRY-OVER. -->
EOF

# Auto-commit (silent, non-blocking)
cd "$PROJECT_ROOT" 2>/dev/null || exit 0
git add docs/slate/ 2>/dev/null || true
git commit -m "auto: session-end checkpoint" --allow-empty --no-verify --quiet 2>/dev/null || true
