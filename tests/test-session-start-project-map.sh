#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export CLAUDE_PROJECT_ROOT="$TMPDIR"

# session-start.sh exits early unless both progress/ and features/ exist.
mkdir -p "$TMPDIR/progress" "$TMPDIR/features"
: > "$TMPDIR/progress/current.md"
: > "$TMPDIR/progress/history.md"
: > "$TMPDIR/features/in-progress.md"
: > "$TMPDIR/features/backlog.md"

HOOK="$PLUGIN_ROOT/hooks/session-start.sh"

# Test 1: WITHOUT docs/project-map.md, output must NOT contain the project_map marker
OUT_NO_MAP=$(bash "$HOOK" 2>/dev/null || true)
if [ -z "$OUT_NO_MAP" ]; then
  echo "FAIL: hook produced no output even though progress/+features/ exist"
  exit 1
fi
if echo "$OUT_NO_MAP" | grep -q "project_map"; then
  echo "FAIL: 'project_map' present in output without docs/project-map.md"
  echo "--- output ---"
  echo "$OUT_NO_MAP"
  exit 1
fi
echo "PASS: project_map NOT injected when docs/project-map.md is absent"

# Test 2: WITH docs/project-map.md, output MUST contain the project_map marker
mkdir -p "$TMPDIR/docs"
cat > "$TMPDIR/docs/project-map.md" <<'EOF'
# Project Map

## Visión
Test fixture project that exists only to verify session-start injection.

## Fase actual
MVP

## Criterios de salida de la fase actual
- Ship feature X.
- Get 5 alpha users.
EOF

OUT_WITH_MAP=$(bash "$HOOK" 2>/dev/null || true)
if [ -z "$OUT_WITH_MAP" ]; then
  echo "FAIL: hook produced no output with project-map present"
  exit 1
fi
if ! echo "$OUT_WITH_MAP" | grep -q "project_map"; then
  echo "FAIL: 'project_map' marker missing from output despite docs/project-map.md existing"
  echo "--- output ---"
  echo "$OUT_WITH_MAP"
  exit 1
fi
if ! echo "$OUT_WITH_MAP" | grep -q "Test fixture project"; then
  echo "FAIL: project-map.md content not present in additionalContext"
  echo "--- output ---"
  echo "$OUT_WITH_MAP"
  exit 1
fi
echo "PASS: project_map injected with file content when docs/project-map.md exists"

# Test 3: output is still valid JSON with an additionalContext key
if command -v python3 >/dev/null 2>&1; then
  echo "$OUT_WITH_MAP" | python3 -c "import sys, json; data = json.loads(sys.stdin.read()); assert 'additionalContext' in data, 'missing additionalContext key'; assert 'project_map' in data['additionalContext'], 'project_map marker not in additionalContext'"
  echo "PASS: output is valid JSON containing project_map inside additionalContext"
else
  echo "SKIP: python3 missing — cannot validate JSON shape"
fi

rm -rf "$TMPDIR"
echo "All session-start project-map tests passed."
