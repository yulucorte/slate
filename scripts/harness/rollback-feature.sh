#!/usr/bin/env bash
set -u

FEAT_ID="${1:-}"
[ -z "$FEAT_ID" ] && { echo "Usage: rollback-feature.sh <FEAT-NNN>" >&2; exit 0; }

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

DONE="$PROJECT_ROOT/features/done.md"
IP="$PROJECT_ROOT/features/in-progress.md"

if ! grep -q "^## $FEAT_ID:" "$DONE"; then
  "$LOG" rollback-feature ERROR feature="$FEAT_ID" reason=not-in-done
  exit 0
fi

# Extract entry (from ## FEAT-ID: line up to but not including the next ## FEAT- or EOF)
ENTRY=$(awk -v id="$FEAT_ID" '
  $0 ~ "^## "id":" { capture=1 }
  /^## FEAT-/ && $0 !~ "^## "id":" && capture { exit }
  capture { print }
' "$DONE")

# Try to get PR comments
parse=$(bash "$LIB_DIR/read-feature.sh" "$DONE" "$FEAT_ID" 2>/dev/null || true)
branch=$(echo "$parse" | grep '^branch=' | cut -d= -f2-)
comments=""
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && [ -n "$branch" ]; then
  pr_num=$(gh pr list --head "$branch" --state all --json number 2>/dev/null | grep -oE '"number"[[:space:]]*:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+')
  if [ -n "$pr_num" ]; then
    if ! command -v python3 >/dev/null 2>&1; then
      "$LOG" rollback-feature WARNING feature="$FEAT_ID" reason=python3-missing remediation="install python3 to capture PR comments in Notes"
    else
      raw=$(gh pr view "$pr_num" --json comments 2>/dev/null || echo "")
      comments=$(echo "$raw" | python3 -c '
import json, sys
try:
  data = json.load(sys.stdin)
  for c in data.get("comments", []):
    author = c.get("author", {}).get("login", "?")
    print("- @" + author + ": " + c.get("body", "").replace("\n", " "))
except Exception:
  pass
' 2>/dev/null || true)
    fi
  fi
fi

# Append Notes block to entry
if [ -n "$comments" ]; then
  ENTRY="$ENTRY

### Notes
Reviewer feedback (rolled back $(date '+%Y-%m-%d')):
$comments"
fi

# Remove from done.md
awk -v id="$FEAT_ID" '
  $0 ~ "^## "id":" { skipping=1; next }
  /^## FEAT-/ && skipping && $0 !~ "^## "id":" { skipping=0 }
  !skipping { print }
' "$DONE" > "$DONE.tmp" && mv "$DONE.tmp" "$DONE"

# Append to in-progress.md
echo "" >> "$IP"
echo "$ENTRY" >> "$IP"

echo "$(date '+%Y-%m-%d %H:%M:%S') $FEAT_ID rolled back from done" >> "$PROJECT_ROOT/progress/history.md"
"$LOG" rollback-feature SUCCESS feature="$FEAT_ID"
exit 0
