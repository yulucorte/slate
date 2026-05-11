#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness"

LIB_DIR="$PLUGIN_ROOT/hooks/lib"
export LIB_DIR

# Test 1: missing config → defaults loaded
unset HARNESS_FORMATTER HARNESS_AUTO_PR
source "$LIB_DIR/load-config.sh"
if [ "$HARNESS_FORMATTER" != "none" ]; then
  echo "FAIL missing config: HARNESS_FORMATTER expected 'none', got '$HARNESS_FORMATTER'"
  exit 1
fi
echo "PASS: missing config falls back to defaults"

# Test 2: valid config overrides defaults
cp "$PLUGIN_ROOT/tests/fixtures/config-valid.sh" "$TMPDIR/.claude-harness/config.sh"
unset HARNESS_FORMATTER HARNESS_AUTO_PR
source "$LIB_DIR/load-config.sh"
if [ "$HARNESS_FORMATTER" != "prettier" ]; then
  echo "FAIL valid config: HARNESS_FORMATTER expected 'prettier', got '$HARNESS_FORMATTER'"
  exit 1
fi
if [ "$HARNESS_AUTO_PR" != "true" ]; then
  echo "FAIL valid config: HARNESS_AUTO_PR expected 'true', got '$HARNESS_AUTO_PR'"
  exit 1
fi
echo "PASS: valid config overrides defaults"

# Test 3: invalid syntax → falls back to defaults, logs ERROR
cp "$PLUGIN_ROOT/tests/fixtures/config-syntax-error.sh" "$TMPDIR/.claude-harness/config.sh"
unset HARNESS_FORMATTER HARNESS_AUTO_PR
source "$LIB_DIR/load-config.sh" 2>/dev/null
if [ "$HARNESS_FORMATTER" != "none" ]; then
  echo "FAIL invalid config: should fall back to defaults"
  exit 1
fi
if ! grep -q "syntax-invalid" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL invalid config: expected 'syntax-invalid' in hooks.log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: invalid config falls back + logs ERROR"

# Test 4: config.local.sh overrides config.sh
cp "$PLUGIN_ROOT/tests/fixtures/config-valid.sh" "$TMPDIR/.claude-harness/config.sh"
echo "HARNESS_FORMATTER=gofmt" > "$TMPDIR/.claude-harness/config.local.sh"
unset HARNESS_FORMATTER
source "$LIB_DIR/load-config.sh"
if [ "$HARNESS_FORMATTER" != "gofmt" ]; then
  echo "FAIL local override: HARNESS_FORMATTER expected 'gofmt', got '$HARNESS_FORMATTER'"
  exit 1
fi
echo "PASS: config.local.sh overrides config.sh"

rm -rf "$TMPDIR"
echo "All load-config tests passed."
