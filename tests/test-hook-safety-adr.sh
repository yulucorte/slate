#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness" "$TMPDIR/docs/architecture-decisions"

HOOK="$PLUGIN_ROOT/hooks/pre-tool-safety.sh"

ADR_ACCEPTED="$TMPDIR/docs/architecture-decisions/ADR-001-use-postgres.md"
ADR_PROPOSED="$TMPDIR/docs/architecture-decisions/ADR-002-skip-orm.md"
ADR_NEW="$TMPDIR/docs/architecture-decisions/ADR-003-future-decision.md"

cat > "$ADR_ACCEPTED" <<'EOF'
# ADR-001: Use PostgreSQL

Status: Accepted
Date: 2026-05-01

## Context
We need a relational database.

## Decision
Use PostgreSQL.

## Consequences
Strong consistency, mature tooling.
EOF

cat > "$ADR_PROPOSED" <<'EOF'
# ADR-002: Skip ORM

Status: Proposed
Date: 2026-05-13

## Context
ORMs add complexity.

## Decision
Use raw SQL via a thin query helper.
EOF

# Test 1: Block edit on Accepted ADR (arbitrary change)
set +e
echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$ADR_ACCEPTED\",\"old_string\":\"Use PostgreSQL.\",\"new_string\":\"Use MySQL.\"}}" \
  | bash "$HOOK" 2>/tmp/adr-safety-err
rc=$?
set -e
if [ "$rc" -ne 2 ]; then
  echo "FAIL block Accepted ADR: expected exit 2, got $rc"
  cat /tmp/adr-safety-err
  exit 1
fi
if ! grep -q "ADR_EDIT" /tmp/adr-safety-err; then
  echo "FAIL block Accepted ADR: stderr missing ADR_EDIT marker"
  cat /tmp/adr-safety-err
  exit 1
fi
echo "PASS: blocks edits to Accepted ADR with rule ADR_EDIT"

# Test 2: Allow edit on Proposed ADR
set +e
echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$ADR_PROPOSED\",\"old_string\":\"raw SQL\",\"new_string\":\"sqlc-generated code\"}}" \
  | bash "$HOOK" 2>/tmp/adr-safety-err
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "FAIL allow Proposed ADR: expected exit 0, got $rc"
  cat /tmp/adr-safety-err
  exit 1
fi
echo "PASS: permits edits to Proposed ADR"

# Test 3: Allow creating a new ADR (file does not exist yet)
set +e
echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$ADR_NEW\",\"content\":\"# ADR-003\\n\\nStatus: Proposed\\n\"}}" \
  | bash "$HOOK" 2>/tmp/adr-safety-err
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "FAIL allow new ADR: expected exit 0, got $rc"
  cat /tmp/adr-safety-err
  exit 1
fi
echo "PASS: permits writing a new (non-existent) ADR"

# Test 4: Allow the exact Accepted → Superseded transition (Edit, single line)
set +e
echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$ADR_ACCEPTED\",\"old_string\":\"Status: Accepted\",\"new_string\":\"Status: Superseded\"}}" \
  | bash "$HOOK" 2>/tmp/adr-safety-err
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "FAIL allow Accepted→Superseded transition: expected exit 0, got $rc"
  cat /tmp/adr-safety-err
  exit 1
fi
echo "PASS: permits exact Status Accepted→Superseded transition on Accepted ADR"

# Test 5: HARNESS_ALLOW_ADR_EDIT=true bypasses block
echo 'HARNESS_ALLOW_ADR_EDIT=true' > "$TMPDIR/.claude-harness/config.sh"
set +e
echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$ADR_ACCEPTED\",\"old_string\":\"Use PostgreSQL.\",\"new_string\":\"Use MySQL.\"}}" \
  | bash "$HOOK" 2>/dev/null
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "FAIL allow override: expected exit 0, got $rc"
  exit 1
fi
echo "PASS: HARNESS_ALLOW_ADR_EDIT=true bypasses block"

rm -rf "$TMPDIR"
echo "All pre-tool-safety ADR tests passed."
