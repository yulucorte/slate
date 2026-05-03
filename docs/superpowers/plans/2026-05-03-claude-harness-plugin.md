# claude-harness Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `claude-harness` Claude Code plugin — a Markdown-only state, progress, and feature-tracking layer that complements Superpowers.

**Architecture:** All state lives in Markdown files (`progress/`, `features/`) in the user's project. The plugin provides 6 skills, 4 bash hooks, template files (copied to projects via `install-into-project.sh`), POSIX library scripts, and tests. No JSON schemas, no SQLite, no external dependencies beyond bash + git + POSIX tools.

**Tech Stack:** Bash (POSIX), git, grep/awk/sed/date, Markdown.

---

## File Map

### Created by this plan

```
claude-harness/                          (the working directory — already exists)
├── .claude-plugin/plugin.json
├── .gitignore
├── LICENSE
├── README.md
├── CHANGELOG.md
├── hooks/
│   ├── hooks.json
│   ├── session-start.sh
│   ├── session-end.sh
│   ├── pre-compact.sh
│   └── post-edit-checkpoint.sh
├── skills/
│   ├── using-claude-harness/SKILL.md
│   ├── tracking-progress/SKILL.md
│   ├── managing-feature-list/SKILL.md
│   ├── scaffolding-environment/SKILL.md
│   ├── handing-off-session/SKILL.md
│   └── breaking-down-features/SKILL.md
├── templates/
│   ├── init.sh
│   ├── AGENTS.md
│   ├── progress/current.md
│   ├── progress/history.md
│   └── features/{README,backlog,in-progress,done}.md
├── scripts/
│   ├── install-into-project.sh
│   ├── self-test.sh
│   └── lib/
│       ├── parse-features.sh
│       └── checkpoint.sh
├── tests/
│   ├── test-install.sh
│   ├── test-parse-features.sh
│   ├── test-checkpoint.sh
│   └── fixtures/sample-feature-list.md
└── docs/
    ├── installation.md
    ├── feature-format.md
    ├── workflow.md
    └── interop-with-superpowers.md
```

---

### Task 1: Git init + directory scaffolding + root config files

**Files:**
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `.claude-plugin/plugin.json`
- Create: `CHANGELOG.md`

- [ ] **Step 1.1: Initialize git repo**

```bash
cd /Users/felipevillacorte/Desktop/claude-harness
git init
```

Expected: `Initialized empty Git repository in .../claude-harness/.git/`

- [ ] **Step 1.2: Create all required directories**

```bash
mkdir -p .claude-plugin \
  hooks \
  skills/using-claude-harness \
  skills/tracking-progress \
  skills/managing-feature-list \
  skills/scaffolding-environment \
  skills/handing-off-session \
  skills/breaking-down-features \
  templates/progress \
  templates/features \
  scripts/lib \
  tests/fixtures \
  docs
```

Expected: no output, all dirs created.

- [ ] **Step 1.3: Write `.gitignore`**

```
.DS_Store
node_modules/
*.log
*.swp
.idea/
.vscode/
```

- [ ] **Step 1.4: Write `LICENSE` (MIT)**

```
MIT License

Copyright (c) 2026 TODO(brief-clarify): tu nombre

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 1.5: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "claude-harness",
  "description": "Markdown-only state, progress and feature tracking layer for Claude Code. Companion to Superpowers.",
  "version": "0.1.0",
  "author": {
    "name": "TODO(brief-clarify): tu nombre",
    "email": "TODO(brief-clarify): tu email"
  },
  "homepage": "TODO(brief-clarify): https://github.com/<usuario>/claude-harness",
  "license": "MIT"
}
```

- [ ] **Step 1.6: Write `CHANGELOG.md`**

```markdown
# Changelog

## v0.1.0 (unreleased)

Initial release.
```

- [ ] **Step 1.7: Commit initial scaffolding**

```bash
git add .gitignore LICENSE .claude-plugin/plugin.json CHANGELOG.md
git commit -m "chore: initial scaffolding from BRIEF.md"
```

Expected: commit created with 4 files.

---

### Task 2: Test fixtures

**Files:**
- Create: `tests/fixtures/sample-feature-list.md`

- [ ] **Step 2.1: Write `tests/fixtures/sample-feature-list.md`**

```markdown
# Sample features (test fixture)

## FEAT-001: First feature
- **Status**: in_progress
- **Created**: 2025-11-01
- **Updated**: 2025-11-02

### Subtasks
- [x] FEAT-001.1: Done thing
- [x] FEAT-001.2: Other done thing
- [ ] FEAT-001.3: Pending thing

## FEAT-002: Second feature
- **Status**: backlog
- **Created**: 2025-11-01

### Subtasks
- [ ] FEAT-002.1: Not started

## FEAT-003: Third feature
- **Status**: done
- **Created**: 2025-10-15
- **Verified**: 2025-10-20

### Subtasks
- [x] FEAT-003.1: Done
```

- [ ] **Step 2.2: Commit fixture**

```bash
git add tests/fixtures/sample-feature-list.md
git commit -m "test: add sample-feature-list fixture"
```

---

### Task 3: TDD — write failing test for parse-features.sh

**Files:**
- Create: `tests/test-parse-features.sh`

- [ ] **Step 3.1: Write `tests/test-parse-features.sh`**

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$PLUGIN_ROOT/tests/fixtures/sample-feature-list.md"

# Source the library under test
# shellcheck source=../scripts/lib/parse-features.sh
source "$PLUGIN_ROOT/scripts/lib/parse-features.sh"

# --- Test: list_feature_ids ---
result=$(list_feature_ids "$FIXTURE")
expected="FEAT-001
FEAT-002
FEAT-003"
if [ "$result" != "$expected" ]; then
  echo "FAIL list_feature_ids: expected '$expected', got '$result'"
  exit 1
fi
echo "PASS: list_feature_ids returns FEAT-001, FEAT-002, FEAT-003"

# --- Test: next_feature_id ---
# Create a temp dir with the fixture as the only .md file
TMPDIR_NF=$(mktemp -d)
cp "$FIXTURE" "$TMPDIR_NF/sample-feature-list.md"
result=$(next_feature_id "$TMPDIR_NF")
if [ "$result" != "FEAT-004" ]; then
  echo "FAIL next_feature_id: expected FEAT-004, got '$result'"
  rm -rf "$TMPDIR_NF"
  exit 1
fi
rm -rf "$TMPDIR_NF"
echo "PASS: next_feature_id returns FEAT-004"

# --- Test: next_feature_id on empty dir ---
TMPDIR_EMPTY=$(mktemp -d)
result=$(next_feature_id "$TMPDIR_EMPTY")
if [ "$result" != "FEAT-001" ]; then
  echo "FAIL next_feature_id (empty): expected FEAT-001, got '$result'"
  rm -rf "$TMPDIR_EMPTY"
  exit 1
fi
rm -rf "$TMPDIR_EMPTY"
echo "PASS: next_feature_id returns FEAT-001 for empty dir"

# --- Test: feature_status ---
result=$(feature_status "$FIXTURE" "FEAT-001")
if [ "$result" != "in_progress" ]; then
  echo "FAIL feature_status FEAT-001: expected 'in_progress', got '$result'"
  exit 1
fi
echo "PASS: feature_status FEAT-001 = in_progress"

result=$(feature_status "$FIXTURE" "FEAT-002")
if [ "$result" != "backlog" ]; then
  echo "FAIL feature_status FEAT-002: expected 'backlog', got '$result'"
  exit 1
fi
echo "PASS: feature_status FEAT-002 = backlog"

result=$(feature_status "$FIXTURE" "FEAT-003")
if [ "$result" != "done" ]; then
  echo "FAIL feature_status FEAT-003: expected 'done', got '$result'"
  exit 1
fi
echo "PASS: feature_status FEAT-003 = done"

# --- Test: count_subtasks ---
# FEAT-001 has 2 checked [x] and 1 unchecked [ ]
checked=$(count_subtasks "$FIXTURE" "FEAT-001" "\[x\]")
if [ "$checked" != "2" ]; then
  echo "FAIL count_subtasks checked: expected 2, got '$checked'"
  exit 1
fi
echo "PASS: count_subtasks FEAT-001 checked = 2"

unchecked=$(count_subtasks "$FIXTURE" "FEAT-001" "\[ \]")
if [ "$unchecked" != "1" ]; then
  echo "FAIL count_subtasks unchecked: expected 1, got '$unchecked'"
  exit 1
fi
echo "PASS: count_subtasks FEAT-001 unchecked = 1"

echo ""
echo "All parse-features tests passed."
```

- [ ] **Step 3.2: Make test executable**

```bash
chmod +x tests/test-parse-features.sh
```

- [ ] **Step 3.3: Run test — verify it FAILS (parse-features.sh doesn't exist yet)**

```bash
bash tests/test-parse-features.sh 2>&1 || true
```

Expected: error like `scripts/lib/parse-features.sh: No such file or directory` — confirming the test is properly wired.

- [ ] **Step 3.4: Commit failing test**

```bash
git add tests/test-parse-features.sh
git commit -m "test: add failing test for parse-features.sh (TDD)"
```

---

### Task 4: Implement parse-features.sh — make test pass

**Files:**
- Create: `scripts/lib/parse-features.sh`

- [ ] **Step 4.1: Write `scripts/lib/parse-features.sh`**

```bash
#!/usr/bin/env bash
# Helpers to extract feature data from features/*.md (Markdown only, no JSON).

# Usage: list_feature_ids <file>
# Prints all FEAT-XXX IDs found in the file, one per line.
list_feature_ids() {
  grep -E '^## FEAT-[0-9]+:' "$1" 2>/dev/null | sed -E 's/^## (FEAT-[0-9]+):.*/\1/'
}

# Usage: next_feature_id <dir>
# Reads all *.md in dir, finds max FEAT-NNN, prints next.
next_feature_id() {
  local dir="${1:-features}"
  local max
  max=$(grep -hE '^## FEAT-[0-9]+:' "$dir"/*.md 2>/dev/null \
        | sed -E 's/^## FEAT-([0-9]+):.*/\1/' \
        | sort -n | tail -1)
  if [ -z "$max" ]; then
    echo "FEAT-001"
  else
    printf "FEAT-%03d\n" $((10#$max + 1))
  fi
}

# Usage: feature_status <file> <FEAT-XXX>
# Prints the Status: value for the given feature.
feature_status() {
  awk -v id="$2" '
    $0 ~ "^## "id":" {found=1}
    found && /^- \*\*Status\*\*:/ {
      sub(/^- \*\*Status\*\*: */, "")
      print
      exit
    }
    /^## FEAT-/ && found && $0 !~ "^## "id":" {exit}
  ' "$1"
}

# Usage: count_subtasks <file> <FEAT-XXX> <pattern>
# Counts subtasks matching pattern (e.g. "\[ \]" for unchecked, "\[x\]" for checked).
count_subtasks() {
  awk -v id="$2" -v pat="$3" '
    $0 ~ "^## "id":" {found=1; next}
    /^## FEAT-/ && found {exit}
    found && $0 ~ pat {count++}
    END {print count+0}
  ' "$1"
}

# If sourced, expose functions; if executed, print usage hint.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "This is a library. Source it: source $(basename "$0")"
fi
```

- [ ] **Step 4.2: Run test — verify it PASSES**

```bash
bash tests/test-parse-features.sh
```

Expected output:
```
PASS: list_feature_ids returns FEAT-001, FEAT-002, FEAT-003
PASS: next_feature_id returns FEAT-004
PASS: next_feature_id returns FEAT-001 for empty dir
PASS: feature_status FEAT-001 = in_progress
PASS: feature_status FEAT-002 = backlog
PASS: feature_status FEAT-003 = done
PASS: count_subtasks FEAT-001 checked = 2
PASS: count_subtasks FEAT-001 unchecked = 1

All parse-features tests passed.
```

- [ ] **Step 4.3: Commit implementation**

```bash
git add scripts/lib/parse-features.sh
git commit -m "feat: implement parse-features.sh library (TDD green)"
```

---

### Task 5: TDD — write failing test for checkpoint.sh

**Files:**
- Create: `tests/test-checkpoint.sh`

- [ ] **Step 5.1: Write `tests/test-checkpoint.sh`**

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"; rm -rf "$TMPDIR_REPO" 2>/dev/null || true' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKPOINT="$PLUGIN_ROOT/scripts/lib/checkpoint.sh"

# --- Setup: create a temp git repo ---
TMPDIR_REPO=$(mktemp -d)
cd "$TMPDIR_REPO"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

# Create initial commit so HEAD exists
echo "init" > init.txt
git add init.txt
git commit -q -m "init"

mkdir -p progress features

# --- Test 1: checkpoint creates a commit when there are changes ---
echo "# Current work" > progress/current.md
echo "in flight task" >> progress/current.md

commit_before=$(git rev-parse HEAD)
bash "$CHECKPOINT" "$TMPDIR_REPO" "test: checkpoint commit"
commit_after=$(git rev-parse HEAD)

if [ "$commit_before" = "$commit_after" ]; then
  echo "FAIL: expected a new commit to be created"
  rm -rf "$TMPDIR_REPO"
  exit 1
fi

msg=$(git log -1 --pretty=%s)
if [ "$msg" != "test: checkpoint commit" ]; then
  echo "FAIL: commit message wrong. Got: '$msg'"
  rm -rf "$TMPDIR_REPO"
  exit 1
fi
echo "PASS: checkpoint creates commit with correct message"

# --- Test 2: No new commit when nothing changed ---
commit_before=$(git rev-parse HEAD)
bash "$CHECKPOINT" "$TMPDIR_REPO" "test: should not commit"
commit_after=$(git rev-parse HEAD)

if [ "$commit_before" != "$commit_after" ]; then
  echo "FAIL: expected no new commit when nothing changed"
  rm -rf "$TMPDIR_REPO"
  exit 1
fi
echo "PASS: checkpoint does not create commit when no changes"

# --- Test 3: checkpoint is silent (exit 0) in a non-git directory ---
TMPDIR_NOGIT=$(mktemp -d)
bash "$CHECKPOINT" "$TMPDIR_NOGIT" "should be silent"
rm -rf "$TMPDIR_NOGIT"
echo "PASS: checkpoint exits 0 in non-git directory"

# Cleanup
rm -rf "$TMPDIR_REPO"

echo ""
echo "All checkpoint tests passed."
```

- [ ] **Step 5.2: Make test executable**

```bash
chmod +x tests/test-checkpoint.sh
```

- [ ] **Step 5.3: Run test — verify it FAILS**

```bash
bash tests/test-checkpoint.sh 2>&1 || true
```

Expected: error because `scripts/lib/checkpoint.sh` doesn't exist yet.

- [ ] **Step 5.4: Commit failing test**

```bash
git add tests/test-checkpoint.sh
git commit -m "test: add failing test for checkpoint.sh (TDD)"
```

---

### Task 6: Implement checkpoint.sh — make test pass

**Files:**
- Create: `scripts/lib/checkpoint.sh`

- [ ] **Step 6.1: Write `scripts/lib/checkpoint.sh`**

```bash
#!/usr/bin/env bash
# Commit progress/ and features/ if they have changes. Silent on failure.

cd "${1:-$(pwd)}" || exit 0

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

git add progress/ features/ 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "${2:-auto: harness checkpoint}" --no-verify --quiet 2>/dev/null || true
fi
```

- [ ] **Step 6.2: Run test — verify it PASSES**

```bash
bash tests/test-checkpoint.sh
```

Expected output:
```
PASS: checkpoint creates commit with correct message
PASS: checkpoint does not create commit when no changes
PASS: checkpoint exits 0 in non-git directory

All checkpoint tests passed.
```

- [ ] **Step 6.3: Commit implementation**

```bash
git add scripts/lib/checkpoint.sh
git commit -m "feat: implement checkpoint.sh library (TDD green)"
```

---

### Task 7: Templates

**Files:**
- Create: `templates/init.sh`
- Create: `templates/AGENTS.md`
- Create: `templates/progress/current.md`
- Create: `templates/progress/history.md`
- Create: `templates/features/README.md`
- Create: `templates/features/backlog.md`
- Create: `templates/features/in-progress.md`
- Create: `templates/features/done.md`

- [ ] **Step 7.1: Write `templates/init.sh`**

```bash
#!/usr/bin/env bash
# This file was installed by claude-harness. Edit it to add project-specific setup.
set -euo pipefail

echo "[init.sh] Starting environment check..."

# 1. Create required directories (idempotent)
mkdir -p progress/subagents progress/transcripts features

# 2. Create missing state files without overwriting existing ones
_create_if_missing() {
  local file="$1"
  local header="$2"
  if [ ! -s "$file" ]; then
    echo "$header" > "$file"
    echo "[init.sh] created $file"
  else
    echo "[init.sh] exists  $file"
  fi
}

_create_if_missing "progress/current.md" "# Current work

_(none in flight)_

<!-- This file is auto-managed by claude-harness:tracking-progress.
     Entries here represent IN-FLIGHT work for the current session.
     At session end, completed entries are moved to history.md;
     orphaned entries become CARRY-OVER. -->"

_create_if_missing "progress/history.md" "# Session history

<!-- Append-only changelog. Never edit existing entries.
     Format: ## YYYY-MM-DD — <session summary>
     Each session adds entries under its heading. -->"

_create_if_missing "features/backlog.md" "# Backlog

<!-- Features wanted but not started. Status: backlog.
     Add via claude-harness:breaking-down-features.
     Move to in-progress.md when work begins. -->"

_create_if_missing "features/in-progress.md" "# In progress

<!-- Features being actively built. Status: in_progress.
     A feature stays here until ALL subtasks are [x] AND Verified is set,
     at which point claude-harness:managing-feature-list moves it to done.md. -->"

_create_if_missing "features/done.md" "# Done

<!-- Completed and verified features. Status: done.
     FORBIDDEN to edit existing entries.
     For changes, create a new feature with \`Supersedes: FEAT-XXX\`. -->"

# 3. Detect project tooling and run setup
if [ -f package.json ] && command -v node >/dev/null 2>&1; then
  echo "[init.sh] node project detected, running npm install..."
  npm install --silent 2>/dev/null || echo "[init.sh] npm install failed (non-fatal)"
fi

if [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  echo "[init.sh] python project detected, set up venv manually"
fi

if [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1; then
  echo "[init.sh] rust project detected, running cargo check..."
  cargo check --quiet 2>/dev/null || echo "[init.sh] cargo check failed (non-fatal)"
fi

if [ -f go.mod ] && command -v go >/dev/null 2>&1; then
  echo "[init.sh] go project detected, running go mod download..."
  go mod download 2>/dev/null || echo "[init.sh] go mod download failed (non-fatal)"
fi

# 4. Smoke test (non-blocking)
if [ -f package.json ] && command -v npm >/dev/null 2>&1; then
  echo "[init.sh] running npm test (60s timeout)..."
  timeout 60 npm test --silent 2>/dev/null || echo "[init.sh] smoke test failed or timed out (non-fatal)"
elif command -v pytest >/dev/null 2>&1 && [ -f pyproject.toml -o -f setup.py ]; then
  echo "[init.sh] running pytest (60s timeout)..."
  timeout 60 pytest -q 2>/dev/null || echo "[init.sh] smoke test failed or timed out (non-fatal)"
elif [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1; then
  echo "[init.sh] running cargo test (60s timeout)..."
  timeout 60 cargo test --quiet 2>/dev/null || echo "[init.sh] smoke test failed or timed out (non-fatal)"
fi

echo "[init.sh] OK at $(date -Iseconds 2>/dev/null || date)"
```

- [ ] **Step 7.2: Make `templates/init.sh` executable**

```bash
chmod +x templates/init.sh
```

- [ ] **Step 7.3: Write `templates/AGENTS.md`**

```markdown
# Project protocol

This project uses **Superpowers** + **claude-harness**. Both are loaded at session start.

## State locations

| File | Purpose |
|---|---|
| `progress/current.md` | Live state of in-flight work |
| `progress/history.md` | Append-only changelog (do not edit past entries) |
| `progress/subagents/*.md` | Full reports from each subagent |
| `features/backlog.md` | Desired features, not started |
| `features/in-progress.md` | Active features |
| `features/done.md` | Completed features (FORBIDDEN to edit) |
| `docs/superpowers/specs/` | Design specs (Superpowers default) |
| `docs/superpowers/plans/` | Implementation plans (Superpowers default) |
| `init.sh` | Environment scaffolding and smoke test |

## Mandatory rules (override skills where conflicting)

1. Before any response, the agent must invoke `tracking-progress` (in claude-harness) and `managing-feature-list` if the request implies scope work.
2. After `superpowers:writing-plans` produces a plan, immediately invoke `breaking-down-features` to derive feature entries.
3. After `superpowers:subagent-driven-development` marks a task complete, also invoke `tracking-progress` to persist the report.
4. A feature only moves to `done.md` when ALL subtasks are `[x]` AND `Verified: <date>` is set.
5. Never edit entries in `done.md`. Add a successor with `Supersedes:`.

## How to verify a feature

1. Run the verification method declared in the feature (`playwright`, `manual`, `unit-test`, etc.).
2. Paste the relevant output into the feature's `### Notes` section.
3. Set `Verified: <today>`.
4. Move the feature to `done.md` via `managing-feature-list`.

## Project-specific (fill in)

- TODO(user): describe the project's domain in 2 lines.
- TODO(user): list any project-specific verification commands here.
```

- [ ] **Step 7.4: Write `templates/progress/current.md`**

```markdown
# Current work

_(none in flight)_

<!-- This file is auto-managed by claude-harness:tracking-progress.
     Entries here represent IN-FLIGHT work for the current session.
     At session end, completed entries are moved to history.md;
     orphaned entries become CARRY-OVER. -->
```

- [ ] **Step 7.5: Write `templates/progress/history.md`**

```markdown
# Session history

<!-- Append-only changelog. Never edit existing entries.
     Format: ## YYYY-MM-DD — <session summary>
     Each session adds entries under its heading. -->
```

- [ ] **Step 7.6: Write `templates/features/README.md`**

```markdown
# Features

This directory is the canonical scope of the project.

- **`backlog.md`** — features we want to build, not yet started.
- **`in-progress.md`** — features being actively worked on.
- **`done.md`** — completed and verified features. **FORBIDDEN to edit.**

See `docs/feature-format.md` (in the claude-harness plugin) for the full format reference.

## Quick example

    ## FEAT-001: User login with email/password
    - **Status**: in_progress
    - **Created**: 2025-11-01
    - **Updated**: 2025-11-02
    - **Spec**: docs/superpowers/specs/2025-11-01-auth-design.md
    - **Plan**: docs/superpowers/plans/2025-11-01-auth.md
    - **Verification**: playwright

    ### Subtasks
    - [x] FEAT-001.1: Login form UI
    - [x] FEAT-001.2: POST /auth/login endpoint
    - [ ] FEAT-001.3: Session cookie + refresh
    - [ ] FEAT-001.4: Playwright e2e green

    ### Notes
    Auth uses JWT in httpOnly cookies. See spec for token rotation policy.
```

- [ ] **Step 7.7: Write `templates/features/backlog.md`**

```markdown
# Backlog

<!-- Features wanted but not started. Status: backlog.
     Add via claude-harness:breaking-down-features.
     Move to in-progress.md when work begins. -->
```

- [ ] **Step 7.8: Write `templates/features/in-progress.md`**

```markdown
# In progress

<!-- Features being actively built. Status: in_progress.
     A feature stays here until ALL subtasks are [x] AND Verified is set,
     at which point claude-harness:managing-feature-list moves it to done.md. -->
```

- [ ] **Step 7.9: Write `templates/features/done.md`**

```markdown
# Done

<!-- Completed and verified features. Status: done.
     FORBIDDEN to edit existing entries.
     For changes, create a new feature with `Supersedes: FEAT-XXX`. -->
```

- [ ] **Step 7.10: Commit templates**

```bash
git add templates/
git commit -m "feat: add templates (init.sh, AGENTS.md, progress/, features/)"
```

---

### Task 8: TDD — write failing test for install-into-project.sh

**Files:**
- Create: `tests/test-install.sh`

- [ ] **Step 8.1: Write `tests/test-install.sh`**

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"; rm -rf "$TMPDIR_PROJECT" 2>/dev/null || true' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$PLUGIN_ROOT/scripts/install-into-project.sh"

# --- Test 1: installs all expected files into empty dir ---
TMPDIR_PROJECT=$(mktemp -d)

CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" > /dev/null

expected_files=(
  "init.sh"
  "AGENTS.md"
  "progress/current.md"
  "progress/history.md"
  "features/README.md"
  "features/backlog.md"
  "features/in-progress.md"
  "features/done.md"
)

for f in "${expected_files[@]}"; do
  if [ ! -f "$TMPDIR_PROJECT/$f" ]; then
    echo "FAIL: expected file '$f' not found in target dir"
    rm -rf "$TMPDIR_PROJECT"
    exit 1
  fi
done
echo "PASS: all expected files installed"

# --- Test 2: init.sh is executable ---
if [ ! -x "$TMPDIR_PROJECT/init.sh" ]; then
  echo "FAIL: init.sh is not executable"
  rm -rf "$TMPDIR_PROJECT"
  exit 1
fi
echo "PASS: init.sh is executable"

# --- Test 3: idempotency — existing files are NOT overwritten ---
echo "CUSTOM CONTENT" > "$TMPDIR_PROJECT/progress/current.md"
original_content=$(cat "$TMPDIR_PROJECT/progress/current.md")

CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$INSTALLER" "$TMPDIR_PROJECT" > /dev/null

content_after=$(cat "$TMPDIR_PROJECT/progress/current.md")
if [ "$original_content" != "$content_after" ]; then
  echo "FAIL: install overwrote existing progress/current.md"
  rm -rf "$TMPDIR_PROJECT"
  exit 1
fi
echo "PASS: idempotency — existing files not overwritten"

# --- Test 4: progress/subagents and progress/transcripts dirs exist ---
if [ ! -d "$TMPDIR_PROJECT/progress/subagents" ]; then
  echo "FAIL: progress/subagents/ not created"
  rm -rf "$TMPDIR_PROJECT"
  exit 1
fi
if [ ! -d "$TMPDIR_PROJECT/progress/transcripts" ]; then
  echo "FAIL: progress/transcripts/ not created"
  rm -rf "$TMPDIR_PROJECT"
  exit 1
fi
echo "PASS: progress/subagents/ and progress/transcripts/ exist"

rm -rf "$TMPDIR_PROJECT"

echo ""
echo "All install tests passed."
```

- [ ] **Step 8.2: Make test executable**

```bash
chmod +x tests/test-install.sh
```

- [ ] **Step 8.3: Run test — verify it FAILS**

```bash
bash tests/test-install.sh 2>&1 || true
```

Expected: error because `scripts/install-into-project.sh` doesn't exist yet.

- [ ] **Step 8.4: Commit failing test**

```bash
git add tests/test-install.sh
git commit -m "test: add failing test for install-into-project.sh (TDD)"
```

---

### Task 9: Implement install-into-project.sh + self-test.sh — make install test pass

**Files:**
- Create: `scripts/install-into-project.sh`
- Create: `scripts/self-test.sh`

- [ ] **Step 9.1: Write `scripts/install-into-project.sh`**

```bash
#!/usr/bin/env bash
# Installs claude-harness templates into the current working directory (the user's project).
# Idempotent: never overwrites existing files.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
TARGET="${1:-$(pwd)}"

# Function: copy a template file only if target doesn't exist
safe_copy() {
  local src="$1"
  local dst="$2"
  if [ -e "$dst" ]; then
    echo "[skip] $dst already exists"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "[ok]   $dst"
  fi
}

echo "Installing claude-harness templates into: $TARGET"

safe_copy "$PLUGIN_ROOT/templates/init.sh" "$TARGET/init.sh"
chmod +x "$TARGET/init.sh" 2>/dev/null || true

safe_copy "$PLUGIN_ROOT/templates/AGENTS.md" "$TARGET/AGENTS.md"

safe_copy "$PLUGIN_ROOT/templates/progress/current.md" "$TARGET/progress/current.md"
safe_copy "$PLUGIN_ROOT/templates/progress/history.md" "$TARGET/progress/history.md"
mkdir -p "$TARGET/progress/subagents" "$TARGET/progress/transcripts"

safe_copy "$PLUGIN_ROOT/templates/features/README.md" "$TARGET/features/README.md"
safe_copy "$PLUGIN_ROOT/templates/features/backlog.md" "$TARGET/features/backlog.md"
safe_copy "$PLUGIN_ROOT/templates/features/in-progress.md" "$TARGET/features/in-progress.md"
safe_copy "$PLUGIN_ROOT/templates/features/done.md" "$TARGET/features/done.md"

echo ""
echo "Done. Next steps:"
echo "  cd $TARGET"
echo "  bash init.sh"
echo "  git add progress/ features/ AGENTS.md init.sh"
echo "  git commit -m 'chore: add claude-harness scaffolding'"
```

- [ ] **Step 9.2: Make install script executable**

```bash
chmod +x scripts/install-into-project.sh
```

- [ ] **Step 9.3: Run install test — verify it PASSES**

```bash
bash tests/test-install.sh
```

Expected output:
```
PASS: all expected files installed
PASS: init.sh is executable
PASS: idempotency — existing files not overwritten
PASS: progress/subagents/ and progress/transcripts/ exist

All install tests passed.
```

- [ ] **Step 9.4: Write `scripts/self-test.sh`**

```bash
#!/usr/bin/env bash
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PLUGIN_ROOT"

PASS=0
FAIL=0

for test in tests/test-*.sh; do
  echo "Running $test..."
  if bash "$test"; then
    echo "  PASS"
    PASS=$((PASS + 1))
  else
    echo "  FAIL"
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "Results: $PASS pass, $FAIL fail"
[ $FAIL -eq 0 ]
```

- [ ] **Step 9.5: Make self-test.sh executable**

```bash
chmod +x scripts/self-test.sh
```

- [ ] **Step 9.6: Run full self-test — all 3 tests should pass**

```bash
bash scripts/self-test.sh
```

Expected output:
```
Running tests/test-checkpoint.sh...
  PASS
Running tests/test-install.sh...
  PASS
Running tests/test-parse-features.sh...
  PASS

Results: 3 pass, 0 fail
```

- [ ] **Step 9.7: Commit scripts**

```bash
git add scripts/install-into-project.sh scripts/self-test.sh
git commit -m "feat: implement install-into-project.sh and self-test.sh"
```

---

### Task 10: Hooks

**Files:**
- Create: `hooks/hooks.json`
- Create: `hooks/session-start.sh`
- Create: `hooks/session-end.sh`
- Create: `hooks/pre-compact.sh`
- Create: `hooks/post-edit-checkpoint.sh`

- [ ] **Step 10.1: Write `hooks/hooks.json`**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh" }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-end.sh" }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "auto|manual",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-compact.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/post-edit-checkpoint.sh" }
        ]
      }
    ]
  }
}
```

- [ ] **Step 10.2: Write `hooks/session-start.sh`**

```bash
#!/usr/bin/env bash
# SessionStart hook: injects harness context into Claude's session if project is initialized.
# Emits JSON with additionalContext. Never exits non-zero.

set -uo pipefail

# Detect plugin root (Claude Code, Cursor, fallback)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-${CURSOR_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}}"
PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"

# Only operate if this project has been initialized with claude-harness
if [ ! -d "$PROJECT_ROOT/progress" ] || [ ! -d "$PROJECT_ROOT/features" ]; then
  exit 0
fi

# Run init.sh if present, append output to history
if [ -f "$PROJECT_ROOT/init.sh" ]; then
  {
    echo ""
    echo "## $(date '+%Y-%m-%d %H:%M:%S') — SessionStart init.sh"
    bash "$PROJECT_ROOT/init.sh" 2>&1 || true
  } >> "$PROJECT_ROOT/progress/history.md" 2>/dev/null || true
fi

# Gather context pieces
SKILL_CONTENT=""
if [ -f "$PLUGIN_ROOT/skills/using-claude-harness/SKILL.md" ]; then
  SKILL_CONTENT=$(cat "$PLUGIN_ROOT/skills/using-claude-harness/SKILL.md" 2>/dev/null || true)
fi

RECENT_HISTORY=""
if [ -f "$PROJECT_ROOT/progress/history.md" ]; then
  RECENT_HISTORY=$(tail -30 "$PROJECT_ROOT/progress/history.md" 2>/dev/null || true)
fi

CURRENT_WORK=""
if [ -f "$PROJECT_ROOT/progress/current.md" ]; then
  CURRENT_WORK=$(cat "$PROJECT_ROOT/progress/current.md" 2>/dev/null || true)
fi

# Extract first 10 active features from in-progress.md and backlog.md
ACTIVE_FEATURES=""
for ffile in "$PROJECT_ROOT/features/in-progress.md" "$PROJECT_ROOT/features/backlog.md"; do
  if [ -f "$ffile" ]; then
    # Extract feature blocks (## FEAT-XXX sections), take up to 10 total
    ACTIVE_FEATURES="${ACTIVE_FEATURES}$(awk '/^## FEAT-/{count++; if(count>10) exit} count>0{print}' "$ffile" 2>/dev/null || true)"
  fi
done

# Build the additionalContext string
CONTEXT="<EXTREMELY_IMPORTANT>
${SKILL_CONTENT}
</EXTREMELY_IMPORTANT>

## Recent history
${RECENT_HISTORY}

## In flight
${CURRENT_WORK}

## Active features
${ACTIVE_FEATURES}"

# Emit JSON for Claude Code's additionalContext
# Escape newlines and special chars for JSON
CONTEXT_JSON=$(printf '%s' "$CONTEXT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
  || printf '%s' "$CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

printf '{"additionalContext": %s}\n' "$CONTEXT_JSON" 2>/dev/null || exit 0
```

- [ ] **Step 10.3: Write `hooks/session-end.sh`**

```bash
#!/usr/bin/env bash
# SessionEnd hook: drains current.md into history.md and auto-commits.
# SessionEnd does not support additionalContext output.

set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"

CURRENT="$PROJECT_ROOT/progress/current.md"
HISTORY="$PROJECT_ROOT/progress/history.md"

if [ ! -f "$CURRENT" ]; then
  exit 0
fi

# Check if current.md has actual work (more than just the header + "none in flight")
if ! grep -qv '^#\|^_\|^<!--\|^$\|^-->' "$CURRENT" 2>/dev/null; then
  exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)

{
  echo ""
  echo "## $TIMESTAMP — Session end"
  cat "$CURRENT"
} >> "$HISTORY" 2>/dev/null || true

# Reset current.md to empty state
cat > "$CURRENT" << 'EOF'
# Current work

_(none in flight)_

<!-- This file is auto-managed by claude-harness:tracking-progress.
     Entries here represent IN-FLIGHT work for the current session.
     At session end, completed entries are moved to history.md;
     orphaned entries become CARRY-OVER. -->
EOF

# Auto-commit (silent, non-blocking)
cd "$PROJECT_ROOT" 2>/dev/null || exit 0
git add progress/ features/ 2>/dev/null || true
git commit -m "auto: session-end checkpoint" --allow-empty --no-verify --quiet 2>/dev/null || true
```

- [ ] **Step 10.4: Write `hooks/pre-compact.sh`**

```bash
#!/usr/bin/env bash
# PreCompact hook: snapshots transcript and logs compaction event.

set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"
HISTORY="$PROJECT_ROOT/progress/history.md"
MATCHER="${1:-manual}"

if [ ! -d "$PROJECT_ROOT/progress" ]; then
  exit 0
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)

# Create transcripts dir
mkdir -p "$PROJECT_ROOT/progress/transcripts" 2>/dev/null || true

# Snapshot transcript if available
if [ -n "${CLAUDE_TRANSCRIPT_PATH:-}" ] && [ -f "$CLAUDE_TRANSCRIPT_PATH" ]; then
  SNAP_FILE="$PROJECT_ROOT/progress/transcripts/$(date +%s 2>/dev/null || echo 'snap').snap"
  cp "$CLAUDE_TRANSCRIPT_PATH" "$SNAP_FILE" 2>/dev/null || true
  echo "" >> "$HISTORY" 2>/dev/null || true
  echo "## $TIMESTAMP — PreCompact triggered (matcher: $MATCHER) — snapshot: $SNAP_FILE" >> "$HISTORY" 2>/dev/null || true
else
  {
    echo ""
    echo "## $TIMESTAMP — PreCompact triggered (matcher: $MATCHER) — no transcript available"
  } >> "$HISTORY" 2>/dev/null || true
fi
```

- [ ] **Step 10.5: Write `hooks/post-edit-checkpoint.sh`**

```bash
#!/usr/bin/env bash
# PostToolUse hook: auto-commits edits to progress/ or features/ files.

set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"

# The edited file path is passed as the first argument by Claude Code
EDITED_FILE="${1:-}"

if [ -z "$EDITED_FILE" ]; then
  exit 0
fi

# Only operate on progress/ or features/ files
case "$EDITED_FILE" in
  *progress/*|*features/*)
    ;;
  *)
    exit 0
    ;;
esac

# Resolve to relative path for commit message
REL_FILE="${EDITED_FILE#$PROJECT_ROOT/}"

cd "$PROJECT_ROOT" 2>/dev/null || exit 0

git add "$EDITED_FILE" 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "chore(harness): autosave $REL_FILE" --no-verify --quiet 2>/dev/null || true
fi
```

- [ ] **Step 10.6: Make all hooks executable**

```bash
chmod +x hooks/session-start.sh hooks/session-end.sh hooks/pre-compact.sh hooks/post-edit-checkpoint.sh
```

- [ ] **Step 10.7: Verify hooks start with correct shebang**

```bash
head -1 hooks/session-start.sh hooks/session-end.sh hooks/pre-compact.sh hooks/post-edit-checkpoint.sh
```

Expected: each starts with `#!/usr/bin/env bash`

- [ ] **Step 10.8: Commit hooks**

```bash
git add hooks/
git commit -m "feat: add all four lifecycle hooks"
```

---

### Task 11: Skills

**Files:**
- Create: `skills/using-claude-harness/SKILL.md`
- Create: `skills/tracking-progress/SKILL.md`
- Create: `skills/managing-feature-list/SKILL.md`
- Create: `skills/scaffolding-environment/SKILL.md`
- Create: `skills/handing-off-session/SKILL.md`
- Create: `skills/breaking-down-features/SKILL.md`

- [ ] **Step 11.1: Write `skills/using-claude-harness/SKILL.md`**

```markdown
---
name: using-claude-harness
description: Use when starting any session in a project that contains progress/ or features/ directories. Establishes the protocol for reading current state, updating progress, and respecting the feature list as canonical scope.
---

# Using claude-harness

This skill loads at SessionStart in projects that have been initialized with claude-harness.

## State files (canonical, do not duplicate elsewhere)

- `progress/current.md` — work in flight. Read at session start, update during session, drain at session end.
- `progress/history.md` — append-only log. Never edit existing entries.
- `features/backlog.md` — desired but not started.
- `features/in-progress.md` — actively being built.
- `features/done.md` — completed and verified. Editing entries here is FORBIDDEN.

## Protocol (mandatory, no exceptions)

1. **At session start**: read the SessionStart hook output. It already injected recent history and active features. Do not re-read those files unless you need details beyond what was injected.
2. **Before dispatching a Superpowers subagent**: invoke `tracking-progress` to log the dispatch.
3. **Before marking any task as done**: invoke `managing-feature-list` to update the feature's subtask state. A feature only moves to done.md when ALL subtasks are checked AND a verification entry exists.
4. **At session end**: invoke `handing-off-session` to drain current.md into history.md.

## Interop with Superpowers

claude-harness does NOT replace Superpowers. The flow is:
- `superpowers:brainstorming` produces a spec → still goes to `docs/superpowers/specs/`.
- `superpowers:writing-plans` produces a plan → still goes to `docs/superpowers/plans/`.
- AFTER the plan is written, invoke `breaking-down-features` to derive feature entries in `features/backlog.md` (or `in-progress.md` if work starts immediately).
- During `superpowers:subagent-driven-development`, after each subagent returns, invoke `tracking-progress` to persist the report.

## Anti-patterns

- DO NOT read all four `features/*.md` files preemptively. Use only what the SessionStart hook injected, plus targeted reads.
- DO NOT introduce JSON, YAML, or SQLite alternatives. Markdown is the contract.
- DO NOT skip `tracking-progress` because "the commit message has it". Commits are too terse for cross-session recovery.
- DO NOT edit entries in `done.md`. Create a new feature with `Supersedes: FEAT-XXX` instead.
```

- [ ] **Step 11.2: Write `skills/tracking-progress/SKILL.md`**

```markdown
---
name: tracking-progress
description: Use when dispatching a subagent, when receiving a subagent report, when starting or finishing a task, or when the user asks "where are we". Maintains progress/current.md (live state), progress/history.md (append-only), and progress/subagents/*.md (per-subagent reports).
---

# Tracking progress

## When to invoke (triggers)

- Before any `Task` tool call that dispatches a subagent.
- After any subagent returns (regardless of status).
- When marking a TodoWrite item complete.
- When the user asks for status, recap, or "what's been done".

## What to write

### Before dispatching subagent

Append to `progress/current.md`:

    ### <timestamp ISO-8601> — Dispatched <subagent-type>
    - **Task**: <one-line task summary>
    - **Feature ref**: FEAT-XXX (if applicable)
    - **Plan ref**: docs/superpowers/plans/<file>.md#task-N
    - **Status**: dispatched

### After subagent returns

1. Write the FULL subagent report to `progress/subagents/<task-slug>-<status>.md`. Filename example: `progress/subagents/feat-001-2-jwt-DONE.md`.
2. Update the corresponding entry in `current.md`:

    ### <timestamp> — <subagent-type> returned
    - **Status**: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
    - **Report**: progress/subagents/<task-slug>-<status>.md
    - **Concerns** (if any): <brief>

### At task complete

Move the entry block from `current.md` to `progress/history.md` under a heading `## YYYY-MM-DD — <session-summary>` (create the heading once per session, append entries to it).

## Format rules

- Timestamps: ISO-8601 with timezone (`date -Iseconds`).
- Filenames in `progress/subagents/`: lowercase, hyphenated, end with status in caps.
- Never delete from `history.md`. If something is wrong, append a correction with `## CORRECTION` heading.

## Anti-patterns

- DO NOT summarize old history.md entries to keep the file short. Use git log for that.
- DO NOT skip writing the subagent report file because "I already updated current.md". Both are required.
- DO NOT use relative timestamps ("yesterday", "earlier"). Always absolute.
```

- [ ] **Step 11.3: Write `skills/managing-feature-list/SKILL.md`**

```markdown
---
name: managing-feature-list
description: Use when the user defines new scope, when about to mark anything complete, when the user asks "what's left", or when moving work between backlog/in-progress/done. Maintains features/backlog.md, features/in-progress.md, features/done.md.
---

# Managing the feature list

The three files in `features/` are the canonical scope of the project. Plans (`docs/superpowers/plans/`) describe HOW; feature list describes WHAT and WHETHER IT WORKS.

## Format of a feature entry

See `docs/feature-format.md` for the full reference. Minimum required fields:

    ## FEAT-XXX: <Title>
    - **Status**: backlog | in_progress | done
    - **Created**: YYYY-MM-DD
    - **Updated**: YYYY-MM-DD
    - **Spec**: docs/superpowers/specs/<file>.md (or `none` if no spec)
    - **Plan**: docs/superpowers/plans/<file>.md (or `none`)
    - **Verification**: playwright | manual | unit-test | integration-test | none
    - **Verified**: YYYY-MM-DD (only present when Status: done)

    ### Subtasks
    - [ ] FEAT-XXX.1: <subtask>
    - [ ] FEAT-XXX.2: <subtask>

    ### Notes
    <free-form>

## Movement rules (FORBIDDEN to violate)

| From | To | Required condition |
|---|---|---|
| backlog.md | in-progress.md | User confirms work starts, or a plan is written |
| in-progress.md | done.md | ALL subtasks `[x]` AND `Verified` field set with a real date |
| in-progress.md | backlog.md | User explicitly defers it (rare) |
| anything | edit done.md | NEVER. Create new feature with `Supersedes: FEAT-XXX` |

## ID assignment

- Read all three files, find the highest existing FEAT-NNN, assign FEAT-NNN+1.
- Subtasks: FEAT-XXX.M where M is the next integer within that feature.

## When subtasks complete

Mark `[x]` and update the `Updated` field. Do NOT move the feature yet — wait until ALL subtasks complete AND verification is done.

## When verification runs

Append to the feature's `### Notes` section: `Verified <date>: <command run>, output: <last 10 lines>`. Then update the `Verified:` field and move to done.md.

## Anti-patterns

- DO NOT create FEAT-XXX entries inline in plans. Always write to `features/backlog.md` first.
- DO NOT mark `Status: done` without a `Verified:` date. The hook `pre-compact.sh` will flag this.
- DO NOT delete or rewrite a feature in `done.md`. Append a successor.
- DO NOT use ambiguous statuses like "almost done" or "WIP". Only `backlog | in_progress | done`.
```

- [ ] **Step 11.4: Write `skills/scaffolding-environment/SKILL.md`**

```markdown
---
name: scaffolding-environment
description: Use when the user opens a session in a project that lacks progress/ or features/, or when the user asks to set up claude-harness in this project, or when the SessionStart hook reports the project is uninitialized.
---

# Scaffolding the environment

## When to invoke

- Project has no `progress/` or `features/` directories.
- User says "set up harness here", "init this project", or similar.
- User asks how to use claude-harness in a fresh project.

## What to do

1. Run: `bash $(claude-harness-plugin-root)/scripts/install-into-project.sh`
   - This copies templates into the current project: `progress/`, `features/`, `init.sh`, `AGENTS.md`.
   - It is idempotent: existing files are NEVER overwritten.
2. Run `bash init.sh` to validate the environment.
3. Read the just-created `AGENTS.md` and confirm to the user that the protocol is active.
4. If the project already has a `CLAUDE.md` or `AGENTS.md`, do NOT overwrite. Append a section `## claude-harness protocol` referencing `templates/AGENTS.md`.

## What `init.sh` does (in the user's project)

- Creates required directories if missing.
- Verifies tooling (git, bash, jq optional).
- Runs project-specific tests if present (npm test, pytest, cargo test — auto-detected).
- Exits 0 if env is healthy, non-zero if blocked.

## Anti-patterns

- DO NOT overwrite existing files in the user's project under any circumstance.
- DO NOT run `init.sh` if it doesn't exist (means user hasn't installed yet).
```

- [ ] **Step 11.5: Write `skills/handing-off-session/SKILL.md`**

```markdown
---
name: handing-off-session
description: Use at the end of a session, before the user runs /clear or /compact, or when the user says "we're done for today" or similar. Drains progress/current.md into history.md, ensures features/ is consistent, and writes a session summary.
---

# Handing off a session

## When to invoke

- User signals end of session.
- Before manual /compact.
- When SessionEnd hook fires (it calls this implicitly).

## Steps

1. Read `progress/current.md`.
2. For each entry, decide:
   - If task complete: move to `progress/history.md` under today's heading.
   - If task in flight (e.g. dispatched subagent never returned): rewrite the entry as `## CARRY-OVER` and leave it in current.md. Note the reason.
3. Append a final block to today's section in history.md:

    ### Session summary
    - **Tasks completed**: <count>
    - **Subagents dispatched**: <count>
    - **Features moved**: FEAT-XXX (backlog→in_progress), FEAT-YYY (in_progress→done)
    - **Open questions for next session**: <bullet list, or none>

4. Verify `features/in-progress.md` has no entries with all subtasks `[x]` but missing `Verified:` (those are stale).
5. Commit: `git add progress/ features/ && git commit -m "session: <date> handoff"`.

## Anti-patterns

- DO NOT leave dispatched subagents in current.md without marking them as CARRY-OVER. Future sessions will not know they're orphaned.
- DO NOT auto-verify a feature just because all subtasks are checked. Verification is an explicit human/test action.
```

- [ ] **Step 11.6: Write `skills/breaking-down-features/SKILL.md`**

```markdown
---
name: breaking-down-features
description: Use when a Superpowers plan has just been approved, when the user describes new scope, or when an existing feature is too coarse and needs subtasks. Translates plans or natural-language scope into structured FEAT-XXX entries with subtasks.
---

# Breaking down features

## When to invoke

- Right after `superpowers:writing-plans` produces a plan and the user approves it.
- User describes new desired scope (e.g. "I want users to be able to export to PDF").
- An existing feature in `in-progress.md` has subtasks that are themselves too large.

## Steps

1. Determine target file (default: `features/backlog.md`; if user wants to start now: `features/in-progress.md`).
2. Read existing feature IDs across all three files. Compute next FEAT-XXX.
3. For each new feature, write the entry following `docs/feature-format.md`.
4. If deriving from a Superpowers plan, the plan's tasks (`### Task N`) become subtasks `FEAT-XXX.N`. Preserve task numbering.
5. If a parent feature splits into more, KEEP the parent and add subtasks. Do NOT delete it.

## Sizing rules

- A feature: deliverable user value, typically 30 min – 2 days of agent work.
- A subtask: one Superpowers task, typically 2–30 min.
- If a subtask exceeds 30 min mental estimate, promote it to its own feature with `Parent: FEAT-XXX`.

## Anti-patterns

- DO NOT auto-create features without showing the user the proposed entries first if there are more than 3.
- DO NOT renumber existing FEAT-XXX. IDs are immutable.
- DO NOT collapse subtasks into a single bullet. Each one is a checkbox.
```

- [ ] **Step 11.7: Commit skills**

```bash
git add skills/
git commit -m "feat: add all six SKILL.md files"
```

---

### Task 12: Documentation

**Files:**
- Create: `docs/installation.md`
- Create: `docs/feature-format.md`
- Create: `docs/workflow.md`
- Create: `docs/interop-with-superpowers.md`

- [ ] **Step 12.1: Write `docs/installation.md`**

```markdown
# Installation

## As a Claude Code plugin (recommended)

```bash
# Using Claude Code marketplace
/plugin marketplace add <usuario>/claude-harness
/plugin install claude-harness@claude-harness
```

Or manually:

```bash
git clone https://github.com/<usuario>/claude-harness ~/.claude/plugins/claude-harness
```

## Initializing a project

```bash
cd ~/my-project
bash ~/.claude/plugins/claude-harness/scripts/install-into-project.sh
bash init.sh
```

Expected output from `init.sh`:
```
[init.sh] OK at 2026-05-03T10:00:00+00:00
```

## Verification

After running `init.sh`, verify:

```bash
ls progress/    # current.md  history.md  subagents/  transcripts/
ls features/    # README.md  backlog.md  in-progress.md  done.md
```

Open Claude Code in the project directory. The SessionStart hook will inject `using-claude-harness` context automatically.

## Uninstallation

claude-harness only touches `progress/`, `features/`, `init.sh`, and `AGENTS.md`. To remove:

```bash
rm -rf progress/ features/ init.sh AGENTS.md
```

The plugin itself can be removed from `~/.claude/plugins/`.
```

- [ ] **Step 12.2: Write `docs/feature-format.md`**

```markdown
# Feature Format Reference

## Full schema

    ## FEAT-XXX: <Title>
    - **Status**: backlog | in_progress | done
    - **Created**: YYYY-MM-DD
    - **Updated**: YYYY-MM-DD
    - **Spec**: docs/superpowers/specs/<file>.md | none
    - **Plan**: docs/superpowers/plans/<file>.md | none
    - **Verification**: playwright | manual | unit-test | integration-test | none
    - **Verified**: YYYY-MM-DD                 ← only when Status: done
    - **Parent**: FEAT-XXX                     ← optional, if this is a sub-feature
    - **Supersedes**: FEAT-XXX                 ← optional, if this replaces a done feature
    - **Blocks**: FEAT-XXX, FEAT-YYY           ← optional
    - **Blocked by**: FEAT-XXX                 ← optional
    - **Owner**: @handle                       ← optional
    - **Tags**: tag1, tag2                     ← optional

    ### Subtasks
    - [ ] FEAT-XXX.1: <subtask description>
    - [ ] FEAT-XXX.2: <subtask description>

    ### Notes
    <free-form Markdown>

## ID rules

- IDs are zero-padded to 3 digits: `FEAT-001`, `FEAT-042`, `FEAT-100`.
- IDs are IMMUTABLE once assigned. Never renumber.
- Subtask IDs: `FEAT-XXX.N` where N starts at 1 within the feature.
- To find the next available ID: run `next_feature_id features/` from `scripts/lib/parse-features.sh`.

## Movement rules

| From | To | Required |
|---|---|---|
| `backlog.md` | `in-progress.md` | User confirms work starts OR plan written |
| `in-progress.md` | `done.md` | ALL subtasks `[x]` AND `Verified:` date set |
| `in-progress.md` | `backlog.md` | User explicitly defers (rare) |
| Any | Edit `done.md` | **FORBIDDEN** — create `Supersedes:` successor instead |

## Examples

### Simple backlog feature

    ## FEAT-042: Add dark mode toggle
    - **Status**: backlog
    - **Created**: 2026-05-03
    - **Updated**: 2026-05-03
    - **Spec**: none
    - **Plan**: none
    - **Verification**: manual

    ### Subtasks
    - [ ] FEAT-042.1: Add CSS variables for dark theme
    - [ ] FEAT-042.2: Toggle button in settings UI
    - [ ] FEAT-042.3: Persist preference in localStorage

    ### Notes
    User requested this in session 2026-05-02.

### Completed feature

    ## FEAT-007: JWT authentication
    - **Status**: done
    - **Created**: 2025-11-01
    - **Updated**: 2025-11-15
    - **Spec**: docs/superpowers/specs/2025-11-01-auth.md
    - **Plan**: docs/superpowers/plans/2025-11-01-auth.md
    - **Verification**: playwright
    - **Verified**: 2025-11-15

    ### Subtasks
    - [x] FEAT-007.1: Login form UI
    - [x] FEAT-007.2: POST /auth/login endpoint
    - [x] FEAT-007.3: Session cookie + refresh
    - [x] FEAT-007.4: Playwright e2e green

    ### Notes
    Verified 2025-11-15: npx playwright test auth.spec.ts, output: 4 passed.

### Feature replacing a done one

    ## FEAT-043: JWT authentication v2 (OAuth support)
    - **Status**: in_progress
    - **Created**: 2026-05-03
    - **Updated**: 2026-05-03
    - **Supersedes**: FEAT-007
    - **Verification**: playwright

    ### Subtasks
    - [ ] FEAT-043.1: OAuth provider config
    - [ ] FEAT-043.2: Callback endpoint
    - [ ] FEAT-043.3: Playwright e2e for OAuth flow

### Blocked feature

    ## FEAT-044: PDF export
    - **Status**: backlog
    - **Blocked by**: FEAT-043
    - **Verification**: manual

    ### Subtasks
    - [ ] FEAT-044.1: Install PDF library
    - [ ] FEAT-044.2: Export button
```

- [ ] **Step 12.3: Write `docs/workflow.md`**

```markdown
# Day-to-day workflow

## Starting a new project

1. Install the plugin: `git clone ... ~/.claude/plugins/claude-harness`
2. In your new project: `bash ~/.claude/plugins/claude-harness/scripts/install-into-project.sh`
3. Run `bash init.sh` — verify it prints `[init.sh] OK`.
4. Commit: `git add progress/ features/ AGENTS.md init.sh && git commit -m "chore: add claude-harness scaffolding"`
5. Open Claude Code. The `using-claude-harness` protocol is now active.

## Starting a session

The SessionStart hook automatically:
- Runs `init.sh` and appends output to `progress/history.md`.
- Injects the last 30 lines of `history.md` under `## Recent history`.
- Injects all of `progress/current.md` under `## In flight`.
- Injects the first 10 active features under `## Active features`.

You don't need to manually read these files — they're already in context.

## Receiving a new requirement

1. Invoke `superpowers:brainstorming` → produces spec in `docs/superpowers/specs/`.
2. Invoke `superpowers:writing-plans` → produces plan in `docs/superpowers/plans/`.
3. Invoke `breaking-down-features` → creates FEAT-XXX entries in `features/backlog.md`.
4. Review the proposed features with the user before writing them if there are more than 3.

## Working on a feature

1. Invoke `managing-feature-list` to move the feature from `backlog.md` to `in-progress.md`.
2. Invoke `superpowers:subagent-driven-development` to dispatch subagents per task.
3. Before each subagent dispatch, invoke `tracking-progress` to log it in `progress/current.md`.
4. After each subagent returns, invoke `tracking-progress` to write the full report to `progress/subagents/<task>-<STATUS>.md`.
5. As subtasks complete, update `[x]` in the feature entry and update `Updated:`.
6. When ALL subtasks are `[x]`:
   - Run the declared verification method.
   - Paste the output into the feature's `### Notes` section.
   - Set `Verified: <today>`.
   - Invoke `managing-feature-list` to move to `done.md`.

## Ending a session

1. Invoke `handing-off-session` (or just close the session — the SessionEnd hook handles it automatically).
2. The hook drains `current.md` into `history.md` and commits everything.

## Recovering context in a new session

The SessionStart hook injects everything you need. But if you need more:
- `progress/history.md` — full changelog. Read the last N lines.
- `features/in-progress.md` — what's actively being worked on.
- `progress/subagents/` — full reports from previous subagents.
```

- [ ] **Step 12.4: Write `docs/interop-with-superpowers.md`**

```markdown
# Interop with Superpowers

## Flow diagram

```
User request
    │
    ▼
superpowers:brainstorming ────► docs/superpowers/specs/<file>.md
    │
    ▼
superpowers:writing-plans ─────► docs/superpowers/plans/<file>.md
    │
    ▼
claude-harness:breaking-down-features ──► features/backlog.md
    │
    ▼ (user starts work)
claude-harness:managing-feature-list ───► features/in-progress.md
    │
    ▼
superpowers:subagent-driven-development
    │  ├── implementer subagent
    │  │     │
    │  │     ▼
    │  │  claude-harness:tracking-progress ──► progress/current.md
    │  │                                       progress/subagents/<task>.md
    │  ├── spec-reviewer subagent
    │  └── code-quality-reviewer subagent
    │
    ▼ (all subtasks [x] + verification)
claude-harness:managing-feature-list ───► features/done.md
    │
    ▼
superpowers:finishing-a-development-branch
    │
    ▼
claude-harness:handing-off-session ──────► progress/history.md (drained)
```

## Responsibility table

| Question | Superpowers | claude-harness |
|---|---|---|
| How does design start? | brainstorming | — |
| How is work planned? | writing-plans | — |
| How is work executed? | subagent-driven-development | — |
| What will be built in this project? | — | features/backlog.md |
| What is being built now? | — | features/in-progress.md |
| What has been built? | — | features/done.md |
| What happened last session? | — | progress/history.md |
| What is happening right now? | — | progress/current.md |
| How is context isolated between subagents? | subagent-driven-development | — |
| How is a subagent report persisted? | — | tracking-progress |

## Key principle

Superpowers is the **process engine** (how to think, plan, and execute).  
claude-harness is the **memory system** (what exists, what's done, what happened).

They compose without conflict because they write to different locations and handle different lifecycle events.
```

- [ ] **Step 12.5: Commit documentation**

```bash
git add docs/
git commit -m "docs: add installation, feature-format, workflow, interop docs"
```

---

### Task 13: README + final root files

**Files:**
- Create: `README.md`

- [ ] **Step 13.1: Write `README.md`**

```markdown
# claude-harness

Markdown-only project memory for Claude Code agents. Use alongside Superpowers.

## Why

Superpowers gives Claude Code powerful brainstorming, planning, and subagent execution skills. But three gaps remain between sessions:

1. No persistent state: there's no `progress/current.md` tracking what's in-flight or `progress/history.md` logging what happened.
2. No canonical feature list: no structured backlog, in-progress, or done tracking with verification requirements.
3. No session scaffolding: no equivalent of `init.sh` to validate the environment at startup.

claude-harness fills those gaps without replacing Superpowers.

## Install

```bash
# As a Claude Code plugin (recommended)
/plugin marketplace add <usuario>/claude-harness
/plugin install claude-harness@claude-harness

# In a specific project (installs templates)
bash ~/.claude/plugins/claude-harness/scripts/install-into-project.sh
```

See [docs/installation.md](docs/installation.md) for full details.

## What it adds

### Skills

| Skill | Purpose |
|---|---|
| `using-claude-harness` | Meta-skill: loads at SessionStart, establishes the protocol |
| `tracking-progress` | Logs subagent dispatches and reports to `progress/` |
| `managing-feature-list` | Moves features between backlog/in-progress/done |
| `scaffolding-environment` | Initializes a project that hasn't been set up yet |
| `handing-off-session` | Drains `current.md` into `history.md` at session end |
| `breaking-down-features` | Translates plans into FEAT-XXX entries |

### Hooks

| Hook | Trigger | Effect |
|---|---|---|
| `session-start.sh` | SessionStart | Injects history, current work, active features into context |
| `session-end.sh` | SessionEnd | Drains current.md → history.md, auto-commits |
| `pre-compact.sh` | PreCompact | Snapshots transcript, logs compaction event |
| `post-edit-checkpoint.sh` | PostToolUse (Edit/Write) | Auto-commits edits to progress/ or features/ |

## Coexistence with Superpowers

Superpowers handles **brainstorming → planning → subagent execution**. claude-harness handles **persistent state → feature tracking → session scaffolding**. They compose without conflict: Superpowers writes to `docs/superpowers/`, claude-harness writes to `progress/` and `features/`. See [docs/interop-with-superpowers.md](docs/interop-with-superpowers.md).

## License

MIT
```

- [ ] **Step 13.2: Commit README**

```bash
git add README.md
git commit -m "docs: add README with install, skills table, and coexistence section"
```

---

### Task 14: Final validation

- [ ] **Step 14.1: Run complete self-test**

```bash
bash scripts/self-test.sh
```

Expected:
```
Running tests/test-checkpoint.sh...
  PASS
Running tests/test-install.sh...
  PASS
Running tests/test-parse-features.sh...
  PASS

Results: 3 pass, 0 fail
```

- [ ] **Step 14.2: Verify repo structure matches §2 of BRIEF**

```bash
find . -not -path './.git/*' -not -path './docs/superpowers/*' | sort
```

Confirm presence of all directories and files from the BRIEF §2 structure.

- [ ] **Step 14.3: Verify all SKILL.md files have valid frontmatter**

```bash
for f in skills/*/SKILL.md; do
  name=$(grep '^name:' "$f" | head -1)
  desc=$(grep '^description:' "$f" | head -1)
  if [ -z "$name" ] || [ -z "$desc" ]; then
    echo "FAIL: $f missing frontmatter"
  else
    echo "OK: $f"
  fi
done
```

Expected: all 6 files print `OK`.

- [ ] **Step 14.4: Verify hook scripts are executable**

```bash
ls -la hooks/*.sh
```

Expected: all 4 scripts show `-rwxr-xr-x` permissions.

- [ ] **Step 14.5: Verify no forbidden strings**

```bash
grep -rli "sqlite\|json schema\|database" --include="*.md" --include="*.sh" --include="*.json" . || echo "CLEAN: no forbidden strings found"
```

Expected: `CLEAN: no forbidden strings found`

- [ ] **Step 14.6: Verify git log shows incremental commits**

```bash
git log --oneline
```

Expected: multiple commits, first being `chore: initial scaffolding from BRIEF.md`.

- [ ] **Step 14.7: Invoke superpowers:finishing-a-development-branch**

This is handled by the user after reviewing the self-test results. See execution handoff below.

---

## Self-Review Against Spec

### Spec coverage check

| BRIEF section | Covered by task |
|---|---|
| §2 Repo structure | Tasks 1–13 (all files created) |
| §3 State model | Tasks 11–12 (skills + docs describe the model) |
| §4.1 plugin.json | Task 1 |
| §4.2 .gitignore | Task 1 |
| §4.3 README.md | Task 13 |
| §5.1 hooks.json | Task 10 |
| §5.2 session-start.sh | Task 10 |
| §5.3 session-end.sh | Task 10 |
| §5.4 pre-compact.sh | Task 10 |
| §5.5 post-edit-checkpoint.sh | Task 10 |
| §6.1–6.6 Skills | Task 11 |
| §7.1–7.8 Templates | Task 7 |
| §8.1 install-into-project.sh | Task 9 |
| §8.2 self-test.sh | Task 9 |
| §8.3 parse-features.sh | Task 4 (TDD: Task 3) |
| §8.4 checkpoint.sh | Task 6 (TDD: Task 5) |
| §9.1–9.4 Tests + fixtures | Tasks 2, 3, 5, 8 |
| §10.1–10.4 Docs | Task 12 |

### Placeholder scan

- No "TBD", "TODO" without `(brief-clarify):` or `(user):` prefix
- All `TODO(brief-clarify):` entries are present in plugin.json and LICENSE as specified by BRIEF
- All code steps contain actual code

### Type consistency

All bash function names match across test files and library files:
- `list_feature_ids` — defined in parse-features.sh, used in test-parse-features.sh ✓
- `next_feature_id` — defined in parse-features.sh, used in test-parse-features.sh ✓
- `feature_status` — defined in parse-features.sh, used in test-parse-features.sh ✓
- `count_subtasks` — defined in parse-features.sh, used in test-parse-features.sh ✓
- `safe_copy` — defined and used only within install-into-project.sh ✓
