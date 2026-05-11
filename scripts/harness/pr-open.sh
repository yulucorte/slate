#!/usr/bin/env bash
# Open a GitHub PR for the given feature ID.
# Reads Branch:, title, plan, verification from features/done.md.
# Idempotent: checks for existing PR first.
# Always exits 0; failures logged.

set -u

FEAT_ID="${1:-}"
if [ -z "$FEAT_ID" ]; then
  echo "Usage: pr-open.sh <FEAT-NNN>" >&2
  exit 0
fi

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

# shellcheck source=../../hooks/lib/load-config.sh
source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

if ! command -v gh >/dev/null 2>&1; then
  "$LOG" pr-open ERROR feature="$FEAT_ID" reason=gh-not-installed remediation="install gh from https://cli.github.com"
  exit 0
fi

if ! gh auth status >/dev/null 2>&1; then
  "$LOG" pr-open ERROR feature="$FEAT_ID" reason=gh-auth-failed remediation="run: gh auth login"
  exit 0
fi

DONE="$PROJECT_ROOT/features/done.md"
parse=$(bash "$LIB_DIR/read-feature.sh" "$DONE" "$FEAT_ID" 2>/dev/null) || {
  "$LOG" pr-open ERROR feature="$FEAT_ID" reason=feature-not-found-in-done
  exit 0
}

title=$(echo "$parse" | grep '^title=' | cut -d= -f2-)
branch=$(echo "$parse" | grep '^branch=' | cut -d= -f2-)
verification=$(echo "$parse" | grep '^verification=' | cut -d= -f2-)

if [ -z "$branch" ] || [ "$branch" = "none" ]; then
  "$LOG" pr-open ERROR feature="$FEAT_ID" reason=branch-missing-or-none
  exit 0
fi

# Fork / permission check
perm=$(gh repo view --json viewerPermission 2>/dev/null | grep -oE '"viewerPermission"[[:space:]]*:[[:space:]]*"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/')
case "${perm:-}" in
  ADMIN|MAINTAIN|WRITE) ;;
  *)
    "$LOG" pr-open ERROR feature="$FEAT_ID" reason=no-write-permission perm="${perm:-unknown}" remediation="fork workflow: push to your fork and open PR from there"
    exit 0 ;;
esac

# Idempotency check
existing=$(gh pr list --head "$branch" --json number,url 2>/dev/null || echo "[]")
if echo "$existing" | grep -q '"number"'; then
  url=$(echo "$existing" | grep -oE '"url"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/')
  "$LOG" pr-open INFO feature="$FEAT_ID" reason=pr-already-exists url="$url"
  exit 0
fi

pr_title="feat($FEAT_ID): $title"
pr_body="Automated PR for $FEAT_ID.

Verification: \`$verification\`

---

_Opened by claude-harness post-edit-done-watcher._"

url=$(gh pr create --title "$pr_title" --body "$pr_body" --base "$HARNESS_GITHUB_BASE" --head "$branch" 2>/dev/null) || {
  "$LOG" pr-open ERROR feature="$FEAT_ID" reason=gh-pr-create-failed
  exit 0
}

echo "" >> "$PROJECT_ROOT/progress/history.md"
echo "$(date '+%Y-%m-%d %H:%M:%S') $FEAT_ID PR opened: $url" >> "$PROJECT_ROOT/progress/history.md"
"$LOG" pr-open SUCCESS feature="$FEAT_ID" url="$url"
exit 0
