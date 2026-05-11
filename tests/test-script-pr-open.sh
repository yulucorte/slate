#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness" "$TMPDIR/features"
echo "# History" > "$TMPDIR/progress/history.md"

SCRIPT="$PLUGIN_ROOT/scripts/harness/pr-open.sh"

# Mock gh in a temp dir on PATH. Isolate PATH so the real gh on this system
# (e.g. /opt/homebrew/bin/gh) is not picked up.
MOCK_DIR=$(mktemp -d)
cat > "$MOCK_DIR/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo view") echo '{"viewerPermission":"ADMIN"}' ;;
  "pr list") echo '[]' ;;
  "pr create") echo "https://github.com/test/test/pull/42" ;;
  *) echo "unexpected gh call: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$MOCK_DIR/gh"
# Keep a minimal PATH that includes only the mock + standard utils, so that
# removing the mock guarantees `gh` is unavailable for the degradation test.
ISOLATED_PATH="$MOCK_DIR:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$ISOLATED_PATH"

cp "$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" "$TMPDIR/features/done.md"
echo 'HARNESS_GITHUB_BASE=main' > "$TMPDIR/.claude-harness/config.sh"

bash "$SCRIPT" FEAT-007

if ! grep -q "https://github.com/test/test/pull/42" "$TMPDIR/progress/history.md"; then
  echo "FAIL: PR URL not appended to history"
  cat "$TMPDIR/progress/history.md"
  exit 1
fi
echo "PASS: pr-open creates PR and appends to history"

# Test: idempotency
cat > "$MOCK_DIR/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "repo view") echo '{"viewerPermission":"ADMIN"}' ;;
  "pr list") echo '[{"number":42,"url":"https://github.com/test/test/pull/42"}]' ;;
  *) echo "should not reach" >&2; exit 1 ;;
esac
EOF
bash "$SCRIPT" FEAT-007
if ! grep -q "pr-already-exists" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: idempotency log not found"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: pr-open is idempotent"

# Test: missing gh -> log ERROR, exit 0
rm "$MOCK_DIR/gh"
set +e
bash "$SCRIPT" FEAT-007
rc=$?
set -e
if [ "$rc" -ne 0 ]; then echo "FAIL: missing gh should not propagate failure (rc=$rc)"; exit 1; fi
if ! grep -q "gh-not-installed\|gh-auth-failed" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected gh-missing log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: missing gh degrades gracefully"

rm -rf "$TMPDIR" "$MOCK_DIR"
echo "All pr-open tests passed."
