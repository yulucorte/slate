#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"; rm -rf "$TMPDIR_PROJECT" 2>/dev/null || true' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Test 1: detects Python + pytest config ---
TMPDIR_PROJECT=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT/src"
touch "$TMPDIR_PROJECT/src/main.py"
cat > "$TMPDIR_PROJECT/pyproject.toml" <<'EOF'
[tool.pytest.ini_options]
testpaths = ["tests"]
EOF
cp "$PLUGIN_ROOT/templates/init.sh" "$TMPDIR_PROJECT/init.sh"

output=$(cd "$TMPDIR_PROJECT" && bash init.sh 2>&1)
echo "$output" | grep -q "Environment report" || { echo "FAIL: no env report header"; exit 1; }
echo "$output" | grep -q "pytest" || { echo "FAIL: pytest not detected"; exit 1; }
echo "PASS: detects python+pytest"
rm -rf "$TMPDIR_PROJECT"

# --- Test 2: warns when Python source exists but no LSP config ---
TMPDIR_PROJECT=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT/src"
touch "$TMPDIR_PROJECT/src/main.py"
cp "$PLUGIN_ROOT/templates/init.sh" "$TMPDIR_PROJECT/init.sh"

output=$(cd "$TMPDIR_PROJECT" && bash init.sh 2>&1)
echo "$output" | grep -q "⚠" || { echo "FAIL: no warning emitted"; exit 1; }
echo "$output" | grep -qi "LSP" || { echo "FAIL: LSP warning missing"; exit 1; }
echo "PASS: warns when no LSP config for detected language"
rm -rf "$TMPDIR_PROJECT"

# --- Test 3: TS with tsconfig.json suppresses LSP warning ---
TMPDIR_PROJECT=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT/src"
touch "$TMPDIR_PROJECT/src/app.ts"
echo '{"compilerOptions":{}}' > "$TMPDIR_PROJECT/tsconfig.json"
cp "$PLUGIN_ROOT/templates/init.sh" "$TMPDIR_PROJECT/init.sh"

output=$(cd "$TMPDIR_PROJECT" && bash init.sh 2>&1)
echo "$output" | grep -q "TypeScript" || { echo "FAIL: TS not detected"; exit 1; }
echo "$output" | grep -q "TypeScript detected but no" && { echo "FAIL: spurious TS LSP warning"; exit 1; }
echo "PASS: tsconfig suppresses TS LSP warning"
rm -rf "$TMPDIR_PROJECT"

# --- Test 4: env report is non-blocking (init.sh still exits 0 with warnings) ---
TMPDIR_PROJECT=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT/src"
touch "$TMPDIR_PROJECT/src/foo.py"
cp "$PLUGIN_ROOT/templates/init.sh" "$TMPDIR_PROJECT/init.sh"

( cd "$TMPDIR_PROJECT" && bash init.sh >/dev/null 2>&1 ) || { echo "FAIL: init.sh exited non-zero with warnings"; exit 1; }
echo "PASS: env report warnings are non-blocking"
rm -rf "$TMPDIR_PROJECT"

echo ""
echo "All env-report tests passed."
