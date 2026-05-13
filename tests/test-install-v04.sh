#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init -q -b main

CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$PLUGIN_ROOT/scripts/install-into-project.sh" >/dev/null

# Test 1: project-map.md template was copied
if [ ! -f "$TMPDIR/docs/project-map.md" ]; then
  echo "FAIL: docs/project-map.md not copied"
  exit 1
fi
if ! grep -q '^# Project Map' "$TMPDIR/docs/project-map.md"; then
  echo "FAIL: docs/project-map.md missing expected '# Project Map' header"
  exit 1
fi
if ! grep -q 'Fase actual' "$TMPDIR/docs/project-map.md"; then
  echo "FAIL: docs/project-map.md missing 'Fase actual' section"
  exit 1
fi
echo "PASS: docs/project-map.md created from template"

# Test 2: architecture-decisions/README.md was copied
if [ ! -f "$TMPDIR/docs/architecture-decisions/README.md" ]; then
  echo "FAIL: docs/architecture-decisions/README.md not copied"
  exit 1
fi
if ! grep -q '^# Architecture Decision Records' "$TMPDIR/docs/architecture-decisions/README.md"; then
  echo "FAIL: ADR README missing expected header"
  exit 1
fi
if ! grep -q 'Status:' "$TMPDIR/docs/architecture-decisions/README.md"; then
  echo "FAIL: ADR README missing Status documentation"
  exit 1
fi
echo "PASS: docs/architecture-decisions/README.md created from template"

# Test 3: idempotency — re-running install does not overwrite user edits
echo "USER-EDIT-MARKER" >> "$TMPDIR/docs/project-map.md"
echo "USER-ADR-MARKER" >> "$TMPDIR/docs/architecture-decisions/README.md"

CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$PLUGIN_ROOT/scripts/install-into-project.sh" >/dev/null

if ! grep -q "USER-EDIT-MARKER" "$TMPDIR/docs/project-map.md"; then
  echo "FAIL: install overwrote user-edited project-map.md"
  exit 1
fi
if ! grep -q "USER-ADR-MARKER" "$TMPDIR/docs/architecture-decisions/README.md"; then
  echo "FAIL: install overwrote user-edited ADR README"
  exit 1
fi
echo "PASS: install is idempotent — user edits preserved on re-run"

cd /
rm -rf "$TMPDIR"
echo "All install-v04 tests passed."
