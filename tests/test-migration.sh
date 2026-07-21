#!/usr/bin/env bash
# Tests the 1.6.0 auto-migrator in session-start.sh: projects using the old
# repo-root layout (progress/ features/ bugs/ ideas/) get moved to docs/slate/.
set -e
trap 'echo "FAIL at line $LINENO"; rm -rf "$TMPDIR_PROJECT" "$TMPDIR_NOGIT" 2>/dev/null || true' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-start.sh"

# --- Test 1: git repo with old layout is migrated to docs/slate/ ---
TMPDIR_PROJECT=$(mktemp -d)
( cd "$TMPDIR_PROJECT" && git init -q && git config user.email t@t.t && git config user.name t )
mkdir -p "$TMPDIR_PROJECT/progress/subagents" "$TMPDIR_PROJECT/features" \
         "$TMPDIR_PROJECT/bugs" "$TMPDIR_PROJECT/ideas"
echo "flight work" > "$TMPDIR_PROJECT/progress/current.md"
echo "# history"   > "$TMPDIR_PROJECT/progress/history.md"
echo "# backlog"   > "$TMPDIR_PROJECT/features/backlog.md"
echo "# in-prog"   > "$TMPDIR_PROJECT/features/in-progress.md"
echo "## BUG-001"  > "$TMPDIR_PROJECT/bugs/open.md"
echo "- an idea"   > "$TMPDIR_PROJECT/ideas/inbox.md"
( cd "$TMPDIR_PROJECT" && git add -A && git commit -qm init )

echo '{"source":"startup"}' | CLAUDE_PROJECT_ROOT="$TMPDIR_PROJECT" bash "$HOOK" >/dev/null

for f in progress/current.md progress/history.md features/backlog.md \
         features/in-progress.md bugs/open.md ideas/inbox.md; do
  [ -f "$TMPDIR_PROJECT/docs/slate/$f" ] || { echo "FAIL: docs/slate/$f missing after migration"; exit 1; }
done
for d in progress features bugs ideas; do
  [ -e "$TMPDIR_PROJECT/$d" ] && { echo "FAIL: old root $d/ still present after migration"; exit 1; }
done
grep -q "flight work" "$TMPDIR_PROJECT/docs/slate/progress/current.md" || { echo "FAIL: content lost in migration"; exit 1; }
echo "PASS: git repo old layout migrated to docs/slate/ (content + git-tracking preserved)"

# --- Test 2: idempotent — second run does not error or duplicate ---
echo '{"source":"startup"}' | CLAUDE_PROJECT_ROOT="$TMPDIR_PROJECT" bash "$HOOK" >/dev/null
[ -e "$TMPDIR_PROJECT/progress" ] && { echo "FAIL: migration re-created old root dir"; exit 1; }
grep -q "flight work" "$TMPDIR_PROJECT/docs/slate/progress/current.md" || { echo "FAIL: content changed on 2nd run"; exit 1; }
echo "PASS: migration is idempotent"
rm -rf "$TMPDIR_PROJECT"

# --- Test 3: non-git dir migrates via plain mv ---
TMPDIR_NOGIT=$(mktemp -d)
mkdir -p "$TMPDIR_NOGIT/progress" "$TMPDIR_NOGIT/features"
echo "x" > "$TMPDIR_NOGIT/progress/current.md"
echo "y" > "$TMPDIR_NOGIT/progress/history.md"
echo "z" > "$TMPDIR_NOGIT/features/in-progress.md"

echo '{"source":"startup"}' | CLAUDE_PROJECT_ROOT="$TMPDIR_NOGIT" bash "$HOOK" >/dev/null
[ -f "$TMPDIR_NOGIT/docs/slate/progress/current.md" ] || { echo "FAIL: non-git migration did not move progress/"; exit 1; }
[ -e "$TMPDIR_NOGIT/progress" ] && { echo "FAIL: non-git old root progress/ still present"; exit 1; }
echo "PASS: non-git dir migrated via mv"
rm -rf "$TMPDIR_NOGIT"

echo ""
echo "All migration tests passed."
