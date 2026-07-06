#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

check_skill() {
  local name="$1"
  local file="$PLUGIN_ROOT/skills/$name/SKILL.md"
  [ -f "$file" ] || { echo "FAIL: $file missing"; exit 1; }
  head -1 "$file" | grep -q '^---$' || { echo "FAIL: $file missing frontmatter opening"; exit 1; }
  grep -q "^name: $name$" "$file" || { echo "FAIL: $file frontmatter name mismatch"; exit 1; }
  grep -q "^description:" "$file" || { echo "FAIL: $file missing description"; exit 1; }
  echo "PASS: $name frontmatter valid"
}

check_skill "tracking-bugs"
check_skill "managing-ideas"

echo ""
echo "All skill frontmatter tests passed."
