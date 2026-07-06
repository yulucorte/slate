#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

check_command() {
  local name="$1"
  local file="$PLUGIN_ROOT/commands/$name.md"
  [ -f "$file" ] || { echo "FAIL: $file missing"; exit 1; }
  head -1 "$file" | grep -q '^---$' || { echo "FAIL: $file missing frontmatter opening"; exit 1; }
  grep -q "^description:" "$file" || { echo "FAIL: $file missing description"; exit 1; }
  echo "PASS: commands/$name.md valid"
}

check_command "idea"
check_command "ideas-triage"

echo ""
echo "All command tests passed."
