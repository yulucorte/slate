# Project Awareness Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the 4 improvements from `BRIEF-claude-harness-v0.2.md` (codebase map, env detection, CLAUDE.md injection, verifier subagent) on top of the current v0.4.0 codebase.

**Architecture:**
- Two improvements (codebase map + env detection) extend `templates/init.sh` so target projects auto-generate spatial context on every run.
- One improvement (CLAUDE.md injection) extends `scripts/install-into-project.sh` to drop a protocol block into the target's existing `CLAUDE.md`.
- One improvement (verifier subagent) adds a new skill `verifying-features/` and a `check-complete` helper in `scripts/lib/parse-features.sh`, gating moves to `done.md`.

**Tech Stack:** bash, awk, grep, find. No new runtime dependencies. Tests use the repo's existing convention (`set -e`, manual `if [ ]`/exit pattern), not the `assert_*` helpers the brief mocked.

**Divergences from brief (conservative, documented in commits):**
- Version bump goes to **0.5.0** (repo is already v0.4.0, brief assumed v0.1.0).
- `RESUMEN-claude-harness.md` does not exist; update is skipped.
- Tests follow existing repo style.
- CLAUDE.md injection uses `yulucorte` for the GitHub URL (repo origin).
- Order: Mejora 1 → 4 → 3 → 2 (per brief §"Orden de ejecución").

---

## Task 1: Codebase map generator (Mejora 1, part A)

**Files:**
- Modify: `templates/init.sh` (append a section after smoke test, before final `echo "[init.sh] OK..."`)
- Create: `tests/test-init-codebase-map.sh`

### Step 1.1 — Write failing test `tests/test-init-codebase-map.sh`

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"; rm -rf "$TMPDIR_PROJECT" 2>/dev/null || true' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Test 1: init.sh generates progress/codebase-map.md ---
TMPDIR_PROJECT=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT/src" "$TMPDIR_PROJECT/tests" "$TMPDIR_PROJECT/progress"
touch "$TMPDIR_PROJECT/src/main.py" "$TMPDIR_PROJECT/src/utils.py"
touch "$TMPDIR_PROJECT/tests/test_main.py"
touch "$TMPDIR_PROJECT/README.md"
cp "$PLUGIN_ROOT/templates/init.sh" "$TMPDIR_PROJECT/init.sh"

( cd "$TMPDIR_PROJECT" && bash init.sh >/dev/null 2>&1 )

MAP="$TMPDIR_PROJECT/progress/codebase-map.md"
[ -f "$MAP" ] || { echo "FAIL: codebase-map.md not generated"; exit 1; }
grep -q "## Project Structure" "$MAP" || { echo "FAIL: missing Project Structure section"; exit 1; }
grep -q "Python" "$MAP" || { echo "FAIL: Python not detected"; exit 1; }
grep -q "node_modules" "$MAP" && { echo "FAIL: node_modules leaked into map"; exit 1; }
echo "PASS: codebase-map.md generated with structure + language detection"
rm -rf "$TMPDIR_PROJECT"

# --- Test 2: codebase-map.md is regenerated (not idempotent) ---
TMPDIR_PROJECT=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT/progress" "$TMPDIR_PROJECT/src"
echo "old content" > "$TMPDIR_PROJECT/progress/codebase-map.md"
touch "$TMPDIR_PROJECT/src/app.ts"
cp "$PLUGIN_ROOT/templates/init.sh" "$TMPDIR_PROJECT/init.sh"

( cd "$TMPDIR_PROJECT" && bash init.sh >/dev/null 2>&1 )

grep -q "old content" "$TMPDIR_PROJECT/progress/codebase-map.md" && { echo "FAIL: old content not replaced"; exit 1; }
grep -q "TypeScript" "$TMPDIR_PROJECT/progress/codebase-map.md" || { echo "FAIL: TypeScript not detected"; exit 1; }
echo "PASS: codebase-map.md is regenerated each run"
rm -rf "$TMPDIR_PROJECT"

echo ""
echo "All codebase-map tests passed."
```

### Step 1.2 — Run test to confirm failure

```bash
bash tests/test-init-codebase-map.sh
```
Expected: FAIL ("codebase-map.md not generated").

### Step 1.3 — Implement codebase map section in `templates/init.sh`

Append before the final `echo "[init.sh] OK..."` line:

```bash
# 5. Generate codebase map (always regenerated; provides spatial context to the agent)
_generate_codebase_map() {
  local out="progress/codebase-map.md"
  local now
  now=$(date '+%Y-%m-%d %H:%M' 2>/dev/null || date)
  mkdir -p progress

  # Build a tree of depth 3, excluding common noise dirs
  local tree_output
  if command -v tree >/dev/null 2>&1; then
    tree_output=$(tree -L 3 -a \
      -I 'node_modules|.git|__pycache__|.venv|venv|.next|dist|build|.claude|transcripts' \
      2>/dev/null || true)
  else
    tree_output=$(find . -maxdepth 3 \
      \( -path '*/node_modules' -o -path '*/.git' -o -path '*/__pycache__' \
         -o -path '*/.venv' -o -path '*/venv' -o -path '*/.next' \
         -o -path '*/dist' -o -path '*/build' -o -path '*/.claude' \
         -o -path '*/progress/transcripts' \) -prune -o -print 2>/dev/null \
      | sort)
  fi

  # Detect languages by extension
  local langs=""
  _count_ext() {
    local ext="$1" label="$2"
    local n
    n=$(find . -type f -name "*.$ext" \
      -not -path '*/node_modules/*' -not -path '*/.git/*' \
      -not -path '*/__pycache__/*' -not -path '*/.venv/*' \
      -not -path '*/venv/*' -not -path '*/.next/*' \
      -not -path '*/dist/*' -not -path '*/build/*' \
      -not -path '*/.claude/*' 2>/dev/null | wc -l | tr -d ' ')
    if [ "${n:-0}" -gt 0 ]; then
      langs="${langs}- ${label}: ${n} files
"
    fi
  }
  _count_ext py    "Python"
  _count_ext ts    "TypeScript"
  _count_ext tsx   "TypeScript (TSX)"
  _count_ext js    "JavaScript"
  _count_ext jsx   "JavaScript (JSX)"
  _count_ext go    "Go"
  _count_ext rs    "Rust"
  _count_ext java  "Java"
  _count_ext cpp   "C++"
  _count_ext c     "C"
  _count_ext rb    "Ruby"
  _count_ext php   "PHP"
  _count_ext swift "Swift"
  _count_ext kt    "Kotlin"
  _count_ext sh    "Shell"

  # Top-level directories with description if README present
  local key_dirs=""
  for d in */; do
    [ -d "$d" ] || continue
    local clean="${d%/}"
    case "$clean" in
      node_modules|.git|.venv|venv|__pycache__|.next|dist|build|.claude) continue ;;
    esac
    if [ -f "${clean}/README.md" ]; then
      local first
      first=$(grep -m1 -E '^[A-Za-z]' "${clean}/README.md" 2>/dev/null | head -c 120)
      key_dirs="${key_dirs}- \`${clean}/\` — ${first}
"
    else
      key_dirs="${key_dirs}- \`${clean}/\`
"
    fi
  done

  {
    echo "# Codebase Map"
    echo "> Auto-generated by init.sh — last updated: ${now}"
    echo ""
    echo "## Project Structure"
    echo '```'
    echo "$tree_output"
    echo '```'
    echo ""
    echo "## Languages Detected"
    if [ -n "$langs" ]; then
      printf '%s' "$langs"
    else
      echo "_(no source files detected at depth 3)_"
    fi
    echo ""
    echo "## Key Directories"
    if [ -n "$key_dirs" ]; then
      printf '%s' "$key_dirs"
    else
      echo "_(no top-level directories)_"
    fi
  } > "$out"
  echo "[init.sh] codebase map -> $out"
}
_generate_codebase_map
```

### Step 1.4 — Run test, confirm pass

```bash
bash tests/test-init-codebase-map.sh
```
Expected: both PASS.

### Step 1.5 — Confirm full suite still passes

```bash
bash scripts/self-test.sh
```
Expected: 24/24 pass (23 prior + 1 new file).

### Step 1.6 — Commit

```bash
git add templates/init.sh tests/test-init-codebase-map.sh
git commit -m "feat(init): auto-generate progress/codebase-map.md on each run (Mejora 1)"
```

---

## Task 2: Skill + hook references to codebase map (Mejora 1, part B)

**Files:**
- Modify: `skills/using-claude-harness/SKILL.md` (state files list)
- Modify: `skills/scaffolding-environment/SKILL.md` (what init.sh does)
- Modify: `hooks/session-start.sh` (mention the map in injected context)

### Step 2.1 — Update `skills/using-claude-harness/SKILL.md`

In the "State files" list, after the `progress/current.md` line, insert:

```markdown
- `progress/codebase-map.md` — auto-generated structural map. Consult before running `find`/`ls -R`. Regenerates each `init.sh` run; do not edit manually.
```

### Step 2.2 — Update `skills/scaffolding-environment/SKILL.md`

In the "What `init.sh` does" list, after "Runs project-specific tests…", add:

```markdown
- Generates `progress/codebase-map.md` (structure + language detection). Overwritten each run.
```

### Step 2.3 — Update `hooks/session-start.sh`

After the `RECENT_HISTORY=…` block and before `CURRENT_WORK=…`, add a line that surfaces whether the codebase map exists, then append it to the injected context. Minimal change:

```bash
CODEBASE_MAP_HINT=""
if [ -f "$PROJECT_ROOT/progress/codebase-map.md" ]; then
  CODEBASE_MAP_HINT="A spatial overview lives at \`progress/codebase-map.md\` — consult it before running \`find\` or \`ls -R\`."
fi
```

And in the CONTEXT build, append (before the branch warning block):

```bash
if [ -n "$CODEBASE_MAP_HINT" ]; then
  CONTEXT="${CONTEXT}

## Codebase map
${CODEBASE_MAP_HINT}"
fi
```

### Step 2.4 — Run full suite (no new tests; existing session-start tests must still pass)

```bash
bash scripts/self-test.sh
```

### Step 2.5 — Commit

```bash
git add skills/using-claude-harness/SKILL.md skills/scaffolding-environment/SKILL.md hooks/session-start.sh
git commit -m "feat(skills,hooks): surface progress/codebase-map.md in session-start context"
```

---

## Task 3: Environment detection in init.sh (Mejora 4)

**Files:**
- Modify: `templates/init.sh` (add env report section after codebase map)
- Create: `tests/test-init-env-report.sh`

### Step 3.1 — Write failing test `tests/test-init-env-report.sh`

```bash
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
```

### Step 3.2 — Run test, confirm fail

```bash
bash tests/test-init-env-report.sh
```
Expected: FAIL ("no env report header").

### Step 3.3 — Implement env report in `templates/init.sh`

Append after the `_generate_codebase_map` call:

```bash
# 6. Environment report (informational, non-blocking)
_env_report() {
  echo "[init.sh] Environment report"
  echo "  --------------------------------"

  # Detected languages (re-uses the same heuristic as codebase map, lightweight)
  local has_py has_ts has_js has_rs has_go has_node
  has_py=$(find . -maxdepth 4 -type f -name '*.py'  -not -path '*/.venv/*' -not -path '*/venv/*' 2>/dev/null | head -1)
  has_ts=$(find . -maxdepth 4 -type f \( -name '*.ts' -o -name '*.tsx' \) -not -path '*/node_modules/*' 2>/dev/null | head -1)
  has_js=$(find . -maxdepth 4 -type f \( -name '*.js' -o -name '*.jsx' \) -not -path '*/node_modules/*' 2>/dev/null | head -1)
  has_rs=$(find . -maxdepth 4 -type f -name '*.rs' -not -path '*/target/*' 2>/dev/null | head -1)
  has_go=$(find . -maxdepth 4 -type f -name '*.go' 2>/dev/null | head -1)
  has_node=""
  [ -f package.json ] && has_node="yes"

  # Test runners
  local runners=""
  if [ -f package.json ] && grep -q '"test"' package.json 2>/dev/null; then
    runners="${runners}npm test "
  fi
  if [ -f pytest.ini ] || { [ -f pyproject.toml ] && grep -q 'pytest' pyproject.toml 2>/dev/null; } || [ -f setup.cfg ]; then
    runners="${runners}pytest "
  fi
  if [ -f Makefile ] && grep -qE '^test:' Makefile 2>/dev/null; then
    runners="${runners}make-test "
  fi
  if [ -f Cargo.toml ]; then
    runners="${runners}cargo-test "
  fi
  if [ -f go.mod ]; then
    runners="${runners}go-test "
  fi
  echo "  test runners: ${runners:-none detected}"

  # LSP / linter configs
  local lsp=""
  [ -f .vscode/settings.json ]   && lsp="${lsp}vscode "
  [ -f pyrightconfig.json ]      && lsp="${lsp}pyright "
  [ -f tsconfig.json ]           && lsp="${lsp}tsconfig "
  ls .eslintrc* 2>/dev/null | head -1 >/dev/null && lsp="${lsp}eslint "
  [ -f compile_commands.json ]   && lsp="${lsp}clangd "
  echo "  lsp/lint configs: ${lsp:-none detected}"

  # CI
  local ci=""
  [ -d .github/workflows ]       && ci="${ci}github-actions "
  [ -f .gitlab-ci.yml ]          && ci="${ci}gitlab "
  [ -f Jenkinsfile ]             && ci="${ci}jenkins "
  echo "  ci/cd: ${ci:-none detected}"

  # Warnings (non-blocking)
  if [ -n "$has_py" ]; then
    if [ ! -f pyrightconfig.json ] && [ ! -f .vscode/settings.json ] && [ ! -f pyproject.toml ]; then
      echo "  ⚠ Python detected but no pyrightconfig.json / .vscode / pyproject.toml — LSP may not work"
    fi
    if ! echo "$runners" | grep -q 'pytest'; then
      echo "  ⚠ Python detected but no pytest config found"
    fi
  fi
  if [ -n "$has_ts" ]; then
    if [ ! -f tsconfig.json ]; then
      echo "  ⚠ TypeScript detected but no tsconfig.json — LSP may not work"
    fi
    if [ -n "$has_node" ] && ! grep -q '"test"' package.json 2>/dev/null; then
      echo "  ⚠ TypeScript detected but no test script found in package.json"
    fi
  fi
  if [ -n "$has_js" ] && [ -n "$has_node" ]; then
    if ! grep -q '"test"' package.json 2>/dev/null; then
      echo "  ⚠ JavaScript detected but no test script in package.json"
    fi
  fi
  if [ -n "$has_rs" ] && [ ! -f Cargo.toml ]; then
    echo "  ⚠ Rust source detected but no Cargo.toml"
  fi
  if [ -n "$has_go" ] && [ ! -f go.mod ]; then
    echo "  ⚠ Go source detected but no go.mod"
  fi

  echo "  --------------------------------"
}
_env_report
```

### Step 3.4 — Run test, confirm pass

```bash
bash tests/test-init-env-report.sh
```

### Step 3.5 — Full suite

```bash
bash scripts/self-test.sh
```

### Step 3.6 — Commit

```bash
git add templates/init.sh tests/test-init-env-report.sh
git commit -m "feat(init): emit non-blocking environment report (Mejora 4)"
```

---

## Task 4: CLAUDE.md injection in installer (Mejora 3)

**Files:**
- Modify: `scripts/install-into-project.sh` (add injection logic before final `echo "Done."`)
- Modify: `skills/scaffolding-environment/SKILL.md` (mention CLAUDE.md side-effect)
- Create: `tests/test-install-claude-md.sh`

### Step 4.1 — Write failing test `tests/test-install-claude-md.sh`

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"; rm -rf "$TMPDIR_PROJECT" 2>/dev/null || true' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$PLUGIN_ROOT/scripts/install-into-project.sh"

# --- Test 1: creates CLAUDE.md when none exists ---
TMPDIR_PROJECT=$(mktemp -d)
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" >/dev/null
[ -f "$TMPDIR_PROJECT/CLAUDE.md" ] || { echo "FAIL: CLAUDE.md not created"; exit 1; }
grep -q "<!-- claude-harness -->" "$TMPDIR_PROJECT/CLAUDE.md" || { echo "FAIL: marker missing"; exit 1; }
grep -q "init.sh" "$TMPDIR_PROJECT/CLAUDE.md" || { echo "FAIL: protocol text missing"; exit 1; }
echo "PASS: creates CLAUDE.md when absent"
rm -rf "$TMPDIR_PROJECT"

# --- Test 2: appends to existing CLAUDE.md without altering content ---
TMPDIR_PROJECT=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT"
printf "# My Project\n\nExisting instructions here.\n" > "$TMPDIR_PROJECT/CLAUDE.md"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" >/dev/null
grep -q "# My Project" "$TMPDIR_PROJECT/CLAUDE.md" || { echo "FAIL: original heading lost"; exit 1; }
grep -q "Existing instructions here." "$TMPDIR_PROJECT/CLAUDE.md" || { echo "FAIL: original body lost"; exit 1; }
grep -q "<!-- claude-harness -->" "$TMPDIR_PROJECT/CLAUDE.md" || { echo "FAIL: marker missing after append"; exit 1; }
echo "PASS: appends to existing CLAUDE.md"
rm -rf "$TMPDIR_PROJECT"

# --- Test 3: idempotent — running installer twice does not duplicate block ---
TMPDIR_PROJECT=$(mktemp -d)
echo "# x" > "$TMPDIR_PROJECT/CLAUDE.md"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" >/dev/null
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" >/dev/null
count=$(grep -c "<!-- claude-harness -->" "$TMPDIR_PROJECT/CLAUDE.md" || true)
[ "$count" = "1" ] || { echo "FAIL: marker count $count (expected 1)"; exit 1; }
echo "PASS: installer is idempotent on CLAUDE.md"
rm -rf "$TMPDIR_PROJECT"

# --- Test 4: prefers existing lowercase claude.md over creating CLAUDE.md ---
TMPDIR_PROJECT=$(mktemp -d)
echo "# my project" > "$TMPDIR_PROJECT/claude.md"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" >/dev/null
grep -q "<!-- claude-harness -->" "$TMPDIR_PROJECT/claude.md" || { echo "FAIL: lowercase claude.md not updated"; exit 1; }
[ ! -f "$TMPDIR_PROJECT/CLAUDE.md" ] || { echo "FAIL: should not create uppercase when lowercase exists"; exit 1; }
echo "PASS: respects existing lowercase claude.md"
rm -rf "$TMPDIR_PROJECT"

echo ""
echo "All CLAUDE.md injection tests passed."
```

### Step 4.2 — Run test, confirm fail

```bash
bash tests/test-install-claude-md.sh
```

### Step 4.3 — Add injection logic in `scripts/install-into-project.sh`

Insert just before `echo "Done. Next steps:"`:

```bash
# --- v0.5.0: inject claude-harness protocol block into CLAUDE.md ---
_inject_claude_md() {
  local target="$PROJECT_ROOT/CLAUDE.md"
  if [ -f "$PROJECT_ROOT/claude.md" ] && [ ! -f "$PROJECT_ROOT/CLAUDE.md" ]; then
    target="$PROJECT_ROOT/claude.md"
  fi

  local block
  block=$(cat <<'BLOCK'
<!-- claude-harness -->
## Claude Harness Protocol

This project uses [claude-harness](https://github.com/yulucorte/claude-harness) for persistent state and feature tracking.

**At session start:**
1. Run `init.sh` and verify it passes.
2. Read `progress/current.md` for in-flight work from previous sessions.
3. Read `progress/codebase-map.md` for project structure overview.
4. Read `features/in-progress.md` for active features.
5. Check `features/backlog.md` for pending work if no active features.

**During work:**
- Update `progress/current.md` with what you're doing.
- Never move a feature to `done.md` without spawning the verifier subagent first.
- Feature IDs (`FEAT-XXX`) are immutable — never renumber or reuse.

**At session end:**
- The session-end hook drains `current.md` → `history.md` automatically.

**Files you must NOT edit:**
- `features/done.md` — append-only, managed by the harness.
- `progress/history.md` — append-only.
<!-- /claude-harness -->
BLOCK
)

  if [ -f "$target" ]; then
    if grep -q '<!-- claude-harness -->' "$target"; then
      echo "[install-into-project] CLAUDE.md already contains harness block (skip)"
    else
      printf '\n%s\n' "$block" >> "$target"
      echo "[install-into-project] Appended claude-harness block to $(basename "$target")"
    fi
  else
    printf '%s\n' "$block" > "$target"
    echo "[install-into-project] Created CLAUDE.md with claude-harness block"
  fi
}
_inject_claude_md
```

### Step 4.4 — Update `skills/scaffolding-environment/SKILL.md`

In the "What `install-into-project.sh` does" implicit list (or add one if absent), add:

```markdown
- Injects a `## Claude Harness Protocol` block into `CLAUDE.md` (or `claude.md`), creating the file if absent. Idempotent via the `<!-- claude-harness -->` marker.
```

### Step 4.5 — Run new + full suite

```bash
bash tests/test-install-claude-md.sh
bash scripts/self-test.sh
```

### Step 4.6 — Commit

```bash
git add scripts/install-into-project.sh skills/scaffolding-environment/SKILL.md tests/test-install-claude-md.sh
git commit -m "feat(install): inject claude-harness protocol into target CLAUDE.md (Mejora 3)"
```

---

## Task 5: `check-complete` helper in parse-features (Mejora 2, part A)

**Files:**
- Modify: `scripts/lib/parse-features.sh` (add `check_complete` function)
- Modify: `tests/test-parse-features.sh` (extend with check_complete coverage)

### Step 5.1 — Extend `tests/test-parse-features.sh` with new failing assertions

Append before the final `echo "All parse-features tests passed."`:

```bash
# --- Test: check_complete returns INCOMPLETE when any subtask is [ ] ---
result=$(check_complete "$FIXTURE" "FEAT-001")
if [ "$result" != "INCOMPLETE" ]; then
  echo "FAIL check_complete FEAT-001: expected INCOMPLETE, got '$result'"
  exit 1
fi
echo "PASS: check_complete FEAT-001 = INCOMPLETE (subtask 3 unchecked)"

# --- Test: check_complete returns COMPLETE when all subtasks are [x] ---
result=$(check_complete "$FIXTURE" "FEAT-003")
if [ "$result" != "COMPLETE" ]; then
  echo "FAIL check_complete FEAT-003: expected COMPLETE, got '$result'"
  exit 1
fi
echo "PASS: check_complete FEAT-003 = COMPLETE"

# --- Test: check_complete returns UNKNOWN when feature ID not present ---
result=$(check_complete "$FIXTURE" "FEAT-999")
if [ "$result" != "UNKNOWN" ]; then
  echo "FAIL check_complete FEAT-999: expected UNKNOWN, got '$result'"
  exit 1
fi
echo "PASS: check_complete FEAT-999 = UNKNOWN"
```

### Step 5.2 — Run, confirm fail

```bash
bash tests/test-parse-features.sh
```
Expected: FAIL ("check_complete: command not found" or similar).

### Step 5.3 — Add `check_complete` to `scripts/lib/parse-features.sh`

Insert before the final `if [ "${BASH_SOURCE[0]}" = "$0" ]; then` block:

```bash
# Usage: check_complete <file> <FEAT-XXX>
# Prints COMPLETE, INCOMPLETE, or UNKNOWN.
#  - UNKNOWN: feature ID not found in file
#  - INCOMPLETE: feature has at least one "[ ]" subtask, OR has zero subtasks
#  - COMPLETE: feature has ≥1 "[x]" subtask AND zero "[ ]" subtasks
check_complete() {
  local file="$1" id="$2"
  grep -qE "^## ${id}:" "$file" 2>/dev/null || { echo "UNKNOWN"; return; }
  local checked unchecked
  checked=$(count_subtasks "$file" "$id" "[x]")
  unchecked=$(count_subtasks "$file" "$id" "[ ]")
  if [ "${unchecked:-0}" -gt 0 ] || [ "${checked:-0}" -eq 0 ]; then
    echo "INCOMPLETE"
  else
    echo "COMPLETE"
  fi
}
```

### Step 5.4 — Run, confirm pass

```bash
bash tests/test-parse-features.sh
bash scripts/self-test.sh
```

### Step 5.5 — Commit

```bash
git add scripts/lib/parse-features.sh tests/test-parse-features.sh
git commit -m "feat(parse-features): add check_complete helper for verifier subagent (Mejora 2)"
```

---

## Task 6: Verifier subagent skill (Mejora 2, part B)

**Files:**
- Create: `skills/verifying-features/SKILL.md`
- Modify: `skills/managing-feature-list/SKILL.md` (require verifier before done)

### Step 6.1 — Create `skills/verifying-features/SKILL.md`

```markdown
---
name: verifying-features
description: Use when a feature in features/in-progress.md is about to move to done.md. Runs as an isolated subagent that validates completion criteria and writes a report to progress/subagents/verify-FEAT-XXX.md without modifying any feature file.
---

# Verifying Features

## Purpose
Subagent that validates a feature meets all completion criteria before it moves to `done.md`. Runs in an isolated context to avoid attention dilution in the main agent.

## When to invoke
- BEFORE any feature moves from `in-progress.md` to `done.md`.
- The main agent MUST spawn this as a subagent (e.g. via the `Agent` tool), not run it inline.

## Files this skill reads (read-only)
1. `features/in-progress.md` — the feature being verified.
2. `features/done.md` — to check for ID conflicts.
3. `progress/current.md` — to cross-reference what was actually done.

The skill MUST NOT write to any of these files. The only file it writes is its own report at `progress/subagents/verify-FEAT-XXX.md`.

## Checks performed

1. **Subtask completion**: `bash scripts/lib/parse-features.sh` is sourced and `check_complete features/in-progress.md FEAT-XXX` returns `COMPLETE`.
2. **Verification field**: `Verified: <YYYY-MM-DD>` is present under the feature.
3. **ID integrity**: `FEAT-XXX` does NOT already appear in `done.md`.
4. **No orphaned subtasks**: every `FEAT-XXX.N` referenced in the body is checked `[x]`.
5. **Consistency**: the feature's title/description in `in-progress.md` is reflected in at least one entry of `progress/current.md`.

## Output format

Write to `progress/subagents/verify-FEAT-XXX.md`:

    # Verification: FEAT-XXX
    Date: YYYY-MM-DD HH:MM
    Result: PASS | FAIL

    ## Checks
    - [x] All subtasks completed
    - [x] Verified field present (method: unit-test)
    - [x] ID unique in done.md
    - [x] No orphaned subtasks
    - [x] Consistent with progress/current.md

    ## Recommendation
    APPROVE — safe to move to done.md
    — or —
    BLOCK — <one-line reason>

## Rules

- If ANY check fails, the recommendation MUST be `BLOCK` and the feature MUST NOT move to done.md.
- The verifier NEVER modifies feature files — only reads and writes its own report.
- The main agent reads the verification report and acts on it.
- If the verifier itself cannot run (e.g. missing files), it writes a report with `Result: FAIL` and a `BLOCK` recommendation explaining what was missing.
```

### Step 6.2 — Update `skills/managing-feature-list/SKILL.md`

In the "Movement rules" table, change the `in-progress.md → done.md` row's condition to:

```
ALL subtasks `[x]` AND `Verified` field set with a real date AND user confirms branch merged AND the verifying-features subagent reports APPROVE in `progress/subagents/verify-FEAT-XXX.md`
```

Add a new section after "Branch cleanup on done":

```markdown
## Verifier subagent (mandatory)

Before moving any feature to `done.md`, the agent MUST spawn the `verifying-features` skill as a subagent and wait for its report at `progress/subagents/verify-FEAT-XXX.md`. If the report says `BLOCK`, the feature stays in `in-progress.md`. The agent must NOT skip this step even if it believes all criteria are met — the verifier exists precisely to catch the cases where the main agent's attention has drifted.
```

And in the Anti-patterns list, append:

```markdown
- DO NOT move a feature to done.md without spawning the `verifying-features` subagent and confirming its report says APPROVE.
```

### Step 6.3 — Full suite still passes (no new tests; this is a skill content change)

```bash
bash scripts/self-test.sh
```

### Step 6.4 — Commit

```bash
git add skills/verifying-features/ skills/managing-feature-list/SKILL.md
git commit -m "feat(skills): add verifying-features subagent + gate done.md transitions (Mejora 2)"
```

---

## Task 7: Version bump + release commit

### Step 7.1 — Bump version

Edit `.claude-plugin/plugin.json`: change `"version": "0.4.0"` → `"version": "0.5.0"`.

### Step 7.2 — Final full suite

```bash
bash scripts/self-test.sh
```
Expected: all tests pass (23 prior + 1 codebase-map + 1 env-report + 1 CLAUDE.md injection + 3 new parse-features assertions = same suite count, just more checks per file).

### Step 7.3 — Final commit

```bash
git add .claude-plugin/plugin.json
git commit -m "chore(release): bump to 0.5.0 — project awareness layer (codebase map, env report, CLAUDE.md injection, verifier subagent)"
```

---

## Self-Review

**Spec coverage (against `BRIEF-claude-harness-v0.2.md`):**
- Mejora 1 (codebase map) → Task 1 + Task 2.
- Mejora 2 (verifier subagent) → Task 5 + Task 6.
- Mejora 3 (CLAUDE.md injection) → Task 4.
- Mejora 4 (env detection) → Task 3.
- Version bump → Task 7 (bumped to 0.5.0 instead of 0.2.0 — documented).
- RESUMEN update → SKIPPED (file does not exist; brief's "(si existe, sino usa este brief)" clause invoked).
- "Sin dependencias nuevas" → respected (bash/awk/grep/find only; tree optional with find fallback).

**Placeholder scan:** every code/test block contains the literal content to write. No TBDs. ✓

**Type/name consistency:** `check_complete` is the function name in both Task 5 step 5.3 and the verifier skill (Task 6). The marker `<!-- claude-harness -->` is used identically in installer and tests. ✓
