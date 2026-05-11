#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md"
SCRIPT="$PLUGIN_ROOT/hooks/lib/read-feature.sh"

# Test 1: extract fields for existing feature
result=$("$SCRIPT" "$FIXTURE" FEAT-007)
echo "$result" | grep -q '^title=JWT Authentication$' || { echo "FAIL title: $result"; exit 1; }
echo "$result" | grep -q '^branch=feat/feat-007-jwt-authentication$' || { echo "FAIL branch: $result"; exit 1; }
echo "$result" | grep -q '^plan=docs/superpowers/plans/2026-05-04-jwt-auth.md$' || { echo "FAIL plan: $result"; exit 1; }
echo "PASS: extracts title, branch, plan for FEAT-007"

# Test 2: returns non-zero for missing feature
set +e
"$SCRIPT" "$FIXTURE" FEAT-999 >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  echo "FAIL missing: should return non-zero for missing feature"
  exit 1
fi
echo "PASS: returns non-zero for missing feature"

# Test 3: feature with Branch=none returns branch=none
result=$("$SCRIPT" "$FIXTURE" FEAT-008)
echo "$result" | grep -q '^branch=none$' || { echo "FAIL branch=none: $result"; exit 1; }
echo "PASS: extracts branch=none for backlog feature"

# Test 3b: notes field is emitted when ### Notes section is present
result=$("$SCRIPT" "$FIXTURE" FEAT-007)
echo "$result" | grep -q '^notes=' || { echo "FAIL notes: expected notes= line for FEAT-007"; echo "$result"; exit 1; }
echo "$result" | grep -q 'Initial design notes here' || { echo "FAIL notes content: $result"; exit 1; }
echo "PASS: emits notes field for FEAT-007"

# Test 4: malformed file (missing Branch field) returns non-zero
TMP=$(mktemp)
cat > "$TMP" <<'EOF'
## FEAT-100: Missing branch field

- **Status**: in_progress
- **Plan**: x.md
- **Verification**: x

### Subtasks
- [ ] x
EOF
set +e
"$SCRIPT" "$TMP" FEAT-100 >/dev/null 2>&1
rc=$?
set -e
rm -f "$TMP"
if [ "$rc" -eq 0 ]; then
  echo "FAIL malformed: should return non-zero when Branch field absent"
  exit 1
fi
echo "PASS: returns non-zero when Branch field absent"

echo "All read-feature tests passed."
