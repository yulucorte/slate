#!/usr/bin/env bash
set -u

FEAT_ID="${1:-}"
[ -z "$FEAT_ID" ] && { echo "Usage: pr-merge.sh <FEAT-NNN>" >&2; exit 0; }

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  "$LOG" pr-merge ERROR feature="$FEAT_ID" reason=gh-unavailable
  exit 0
fi

DONE="$PROJECT_ROOT/features/done.md"
parse=$(bash "$LIB_DIR/read-feature.sh" "$DONE" "$FEAT_ID" 2>/dev/null) || {
  "$LOG" pr-merge ERROR feature="$FEAT_ID" reason=feature-not-found
  exit 0
}
branch=$(echo "$parse" | grep '^branch=' | cut -d= -f2-)

pr_num=$(gh pr list --head "$branch" --json number 2>/dev/null | grep -oE '"number"[[:space:]]*:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+')
if [ -z "$pr_num" ]; then
  "$LOG" pr-merge ERROR feature="$FEAT_ID" reason=no-pr-for-branch branch="$branch"
  exit 0
fi

state_json=$(gh pr view "$pr_num" --json state,reviewDecision 2>/dev/null)
decision=$(echo "$state_json" | grep -oE '"reviewDecision"[[:space:]]*:[[:space:]]*"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/')
state=$(echo "$state_json" | grep -oE '"state"[[:space:]]*:[[:space:]]*"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/')

if [ "$state" != "OPEN" ] || [ "$decision" != "APPROVED" ]; then
  "$LOG" pr-merge ERROR feature="$FEAT_ID" reason=pr-not-approved state="$state" decision="$decision"
  exit 0
fi

if ! gh pr merge "$pr_num" --squash --delete-branch >/dev/null 2>&1; then
  "$LOG" pr-merge ERROR feature="$FEAT_ID" reason=merge-failed
  exit 0
fi

sha=$(gh pr view "$pr_num" --json mergeCommit 2>/dev/null | grep -oE '"oid"[[:space:]]*:[[:space:]]*"[a-f0-9]+"' | sed -E 's/.*"([a-f0-9]+)"$/\1/')
sha_short="${sha:0:7}"

echo "$(date '+%Y-%m-%d %H:%M:%S') $FEAT_ID merged in $sha_short" >> "$PROJECT_ROOT/progress/history.md"

# Insert "Merged: <sha>" line after the Branch: line for this feature
awk -v id="$FEAT_ID" -v sha="$sha_short" '
  $0 ~ "^## "id":" { print; in_feat=1; next }
  in_feat && /^- \*\*Branch\*\*:/ { print; print "- **Merged**: " sha; in_feat=0; next }
  /^## FEAT-/ && in_feat { in_feat=0 }
  { print }
' "$DONE" > "$DONE.tmp" && mv "$DONE.tmp" "$DONE"

"$LOG" pr-merge SUCCESS feature="$FEAT_ID" pr="$pr_num" sha="$sha_short"
exit 0
