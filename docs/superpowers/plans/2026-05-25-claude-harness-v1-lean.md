# claude-harness v1.0 lean — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce claude-harness from ~60 files (9 hooks, 12 skills, 7 lib scripts, 4 harness scripts) to ~15 files (3 hooks, 4 skills), keeping only what directly serves the three core functions: persistent state, controlled feature movement, and SessionStart context injection.

**Architecture:** Pure deletion + targeted rewrites in 10 incremental phases, one git commit per phase. Each phase leaves the repo in a functional state. Brief: `BRIEF-claude-harness-v1-lean.md` (gitignored, source of truth). All file paths relative to `/Users/felipevillacorte/Desktop/claude-harness`.

**Tech Stack:** bash, grep, awk, find, sed, python3 (for JSON encoding in `session-start.sh`). No new dependencies.

## File structure (post-refactor)

```
.claude-plugin/plugin.json        # version 1.0.0
hooks/
  hooks.json                      # 3 hooks registered
  session-start.sh                # ≤60 lines, loads only core context
  session-end.sh                  # kept as-is (preserved)
  pre-compact.sh                  # kept as-is (preserved)
skills/
  using-claude-harness/SKILL.md       # ≤50 lines, English
  managing-feature-list/SKILL.md      # ≤50 lines, English
  breaking-down-features/SKILL.md     # simplified
  tracking-progress/SKILL.md          # minor edit
scripts/
  install-into-project.sh         # ≤40 lines, copy templates only
  self-test.sh                    # kept as-is
templates/
  AGENTS.md                       # ~20 lines, new
  init.sh                         # ~60 lines, lean
  features/{backlog,in-progress,done,README}.md   # kept
  progress/{current,history}.md, progress/.gitignore   # kept
docs/
  feature-format.md               # kept, edited to remove parse-features ref
README.md                         # rewritten, ≤80 lines
CHANGELOG.md                      # new, v1.0.0 only
LICENSE                           # kept
.gitignore                        # kept
tests/                            # subset that exercises remaining surface
```

## Skills out of scope (also deleted)

The brief's verification mandates exactly 4 skill directories. Beyond the 6 it names explicitly, two more must go because they are not in the keep list:

- `skills/handing-off-session/` — its only invoker is `using-claude-harness`, which is being rewritten to drop the reference.
- `skills/scaffolding-environment/` — superseded by the lean `install-into-project.sh` + `init.sh`.

---

## Task 1: Phase 1 — Delete non-core hooks, skills, scripts, templates, tests, docs

**Files:**
- Delete: see lists below
- Verify: `find . -not -path './.git/*' -not -path './node_modules/*' -type f | wc -l` drops by ~50

- [ ] **Step 1.1: Delete hooks**

```bash
git rm hooks/post-edit-checkpoint.sh \
       hooks/post-edit-format.sh \
       hooks/post-edit-in-progress-watcher.sh \
       hooks/post-edit-done-watcher.sh \
       hooks/pre-tool-safety.sh \
       hooks/stop-notify.sh
git rm -r hooks/lib
```

- [ ] **Step 1.2: Delete skills**

```bash
git rm -r skills/consulting-project-map \
          skills/harness-create-branch \
          skills/harness-doctor \
          skills/harness-open-pr \
          skills/verify-harness-hooks \
          skills/verifying-features \
          skills/handing-off-session \
          skills/scaffolding-environment
```

- [ ] **Step 1.3: Delete scripts**

```bash
git rm -r scripts/harness
git rm scripts/lib/checkpoint.sh
```

- [ ] **Step 1.4: Delete templates**

```bash
git rm -r templates/.claude-harness \
          templates/docs
```

- [ ] **Step 1.5: Delete obsolete tests**

```bash
git rm tests/test-checkpoint.sh \
       tests/test-doctor.sh \
       tests/test-emit-status.sh \
       tests/test-hook-done-watcher.sh \
       tests/test-hook-format.sh \
       tests/test-hook-in-progress-watcher.sh \
       tests/test-hook-notify.sh \
       tests/test-hook-safety-adr.sh \
       tests/test-hook-safety.sh \
       tests/test-init-env-report.sh \
       tests/test-install-claude-md.sh \
       tests/test-install-v02.sh \
       tests/test-install-v04.sh \
       tests/test-lib-acquire-lock.sh \
       tests/test-lib-defaults.sh \
       tests/test-lib-hash-path.sh \
       tests/test-lib-load-config.sh \
       tests/test-lib-log-hook-event.sh \
       tests/test-lib-read-feature.sh \
       tests/test-script-pr-merge.sh \
       tests/test-script-pr-open.sh \
       tests/test-script-rollback.sh \
       tests/test-session-start-project-map.sh \
       tests/fixtures/config-syntax-error.sh \
       tests/fixtures/config-valid.sh \
       tests/fixtures/feature-with-branch.md
```

- [ ] **Step 1.6: Delete obsolete docs and root artifacts**

```bash
git rm -r docs/assets \
          docs/superpowers/plans/archive \
          docs/superpowers/specs
git rm docs/contributing.md \
       docs/interop-with-superpowers.md \
       docs/STATE-OF-HARNESS.md \
       docs/installation.md \
       docs/use-feedback.md \
       docs/workflow.md \
       docs/superpowers/plans/2026-05-03-claude-harness-plugin.md \
       docs/superpowers/plans/2026-05-04-branch-wip-limit.md \
       docs/superpowers/plans/2026-05-11-project-hooks-and-pr-automation.md \
       docs/superpowers/plans/2026-05-23-project-awareness-layer.md \
       BRIEF-claude-harness.md \
       BRIEF-claude-harness-v0.2.md \
       CHANGELOG.md \
       progress/hooks.log
```

- [ ] **Step 1.7: Verify deletions and commit**

Run:
```bash
git status --short | wc -l
```
Expected: ~60+ deleted entries staged.

Then commit:
```bash
git commit -m "refactor: remove non-core hooks, skills, scripts, and templates"
```

---

## Task 2: Phase 2 — Reduce `hooks/hooks.json` to 3 core hooks

**Files:**
- Modify: `hooks/hooks.json`

- [ ] **Step 2.1: Overwrite `hooks/hooks.json`**

Final content (exact):

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
    ]
  }
}
```

- [ ] **Step 2.2: Verify JSON parses**

Run:
```bash
python3 -c "import json; json.load(open('hooks/hooks.json'))" && echo OK
```
Expected: `OK`.

- [ ] **Step 2.3: Commit**

```bash
git add hooks/hooks.json
git commit -m "refactor: reduce hooks.json to 3 core hooks"
```

---

## Task 3: Phase 3 — Simplify `hooks/session-start.sh` (≤60 lines)

**Files:**
- Modify: `hooks/session-start.sh`

Removes: project-map loading, consulting-project-map skill embed, branch mismatch warning, codebase-map hint section. Keeps: init.sh runner, using-claude-harness skill load, last 30 lines of history.md, current.md, first 10 features from in-progress.md + backlog.md, JSON emission.

- [ ] **Step 3.1: Overwrite `hooks/session-start.sh`**

```bash
#!/usr/bin/env bash
# SessionStart hook: injects harness context into Claude's session if project is initialized.
# Emits JSON with additionalContext. Never exits non-zero.
set -uo pipefail

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

ACTIVE_FEATURES=""
for ffile in "$PROJECT_ROOT/features/in-progress.md" "$PROJECT_ROOT/features/backlog.md"; do
  if [ -f "$ffile" ]; then
    ACTIVE_FEATURES="${ACTIVE_FEATURES}$(awk '/^## FEAT-/{count++; if(count>10) exit} count>0{print}' "$ffile" 2>/dev/null || true)"
  fi
done

CONTEXT="<EXTREMELY_IMPORTANT>
${SKILL_CONTENT}
</EXTREMELY_IMPORTANT>

## Recent history
${RECENT_HISTORY}

## In flight
${CURRENT_WORK}

## Active features
${ACTIVE_FEATURES}"

CONTEXT_JSON=$(printf '%s' "$CONTEXT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
  || printf '"%s"' "$(printf '%s' "$CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')")

printf '{"additionalContext": %s}\n' "$CONTEXT_JSON" 2>/dev/null || exit 0
```

- [ ] **Step 3.2: Confirm executable bit and line count**

Run:
```bash
chmod +x hooks/session-start.sh
wc -l hooks/session-start.sh
```
Expected: line count ≤ 60.

- [ ] **Step 3.3: Smoke test the hook (no project context)**

Run:
```bash
cd /tmp && bash /Users/felipevillacorte/Desktop/claude-harness/hooks/session-start.sh; echo "exit=$?"
```
Expected: no output (no `progress/`+`features/` in /tmp), `exit=0`.

- [ ] **Step 3.4: Commit**

```bash
cd /Users/felipevillacorte/Desktop/claude-harness
git add hooks/session-start.sh
git commit -m "simplify: session-start.sh loads only core context"
```

---

## Task 4: Phase 4 — Rewrite the 4 surviving skills

**Files:**
- Modify: `skills/using-claude-harness/SKILL.md`
- Modify: `skills/managing-feature-list/SKILL.md`
- Modify: `skills/breaking-down-features/SKILL.md`
- Modify: `skills/tracking-progress/SKILL.md`

All content in English. Each ≤ 50 lines.

- [ ] **Step 4.1: Overwrite `skills/using-claude-harness/SKILL.md`**

```markdown
---
name: using-claude-harness
description: Use when starting any session in a project that contains progress/ or features/ directories. Establishes the protocol for reading current state, updating progress, and respecting the feature list as canonical scope.
---

# Using claude-harness

Loads at SessionStart in projects initialized with claude-harness.

## State files (canonical)

- `progress/current.md` — work in flight. Read at start, update during, drain at end.
- `progress/history.md` — append-only log. Never edit existing entries.
- `features/backlog.md` — desired but not started.
- `features/in-progress.md` — actively being built.
- `features/done.md` — completed. Editing entries here is FORBIDDEN.

## Protocol

1. **Session start**: the hook already injected recent history and active features. Do not re-read those files unless you need detail beyond what was injected.
2. **Before dispatching a subagent**: invoke `tracking-progress` to log the dispatch.
3. **Before marking work done**: invoke `managing-feature-list`. A feature only moves to `done.md` when ALL subtasks are `[x]` AND `Verified: <date>` is set.
4. **Session end**: append the contents of `progress/current.md` to `progress/history.md` under a `## YYYY-MM-DD — <summary>` heading, then clear `current.md`.

## Interop with Superpowers

claude-harness does NOT replace Superpowers.
- `superpowers:brainstorming` → spec in `docs/superpowers/specs/`.
- `superpowers:writing-plans` → plan in `docs/superpowers/plans/`.
- After the plan is approved, invoke `breaking-down-features` to derive entries in `features/backlog.md`.

## Anti-patterns

- DO NOT introduce JSON, YAML, or SQLite alternatives. Markdown is the contract.
- DO NOT edit entries in `done.md`. Create a successor with `Supersedes: FEAT-XXX`.
- DO NOT skip `tracking-progress`. Commit messages are too terse for cross-session recovery.
- DO NOT read all four `features/*.md` files preemptively. Use what the hook injected plus targeted reads.
```

- [ ] **Step 4.2: Overwrite `skills/managing-feature-list/SKILL.md`**

```markdown
---
name: managing-feature-list
description: Use when the user defines new scope, when about to mark anything complete, when the user asks "what's left", or when moving work between backlog/in-progress/done. Maintains features/backlog.md, features/in-progress.md, features/done.md.
---

# Managing the feature list

The three files in `features/` are the canonical scope. Plans (`docs/superpowers/plans/`) describe HOW; the feature list describes WHAT and WHETHER IT WORKS.

## Format of a feature entry

See `docs/feature-format.md` for the full reference. Minimum:

    ## FEAT-XXX: <Title>
    - **Status**: backlog | in_progress | done
    - **Created**: YYYY-MM-DD
    - **Updated**: YYYY-MM-DD
    - **Plan**: docs/superpowers/plans/<file>.md (or `none`)
    - **Branch**: feat/feat-NNN-<slug> (or `none`)
    - **Verified**: YYYY-MM-DD (only when Status: done)

    ### Subtasks
    - [ ] FEAT-XXX.1: <subtask>

## Movement rules

Every feature MUST pass through `in-progress.md` so SessionStart can recover context.

| From | To | Condition |
|---|---|---|
| backlog.md | in-progress.md | Work is starting now. Soft recommendation: only one feature in-progress at a time. |
| in-progress.md | done.md | ALL subtasks `[x]` AND `Verified: <date>` set. Verification before moving is recommended. |
| in-progress.md | backlog.md | User explicitly defers it. |
| backlog.md | done.md | FORBIDDEN. Route through `in-progress.md`. |
| any | edit done.md | FORBIDDEN. Create a successor with `Supersedes: FEAT-XXX`. |

## ID assignment

Read all three files, find the highest `FEAT-NNN`, assign `FEAT-NNN+1`. Subtasks: `FEAT-XXX.M` where `M` is the next integer within the feature. IDs are immutable.

## When subtasks complete

Mark `[x]` and update `Updated:`. Do not move the feature until ALL subtasks are checked AND `Verified:` is set.

## Anti-patterns

- DO NOT mark `Status: done` without a `Verified:` date.
- DO NOT delete or rewrite a feature in `done.md`. Append a successor.
- DO NOT use statuses like "almost done" or "WIP". Only `backlog | in_progress | done`.
- DO NOT skip `in-progress.md`. Even retroactive work routes through it.
```

- [ ] **Step 4.3: Overwrite `skills/breaking-down-features/SKILL.md`**

```markdown
---
name: breaking-down-features
description: Use when a Superpowers plan has just been approved, when the user describes new scope, or when an existing feature is too coarse and needs subtasks. Translates plans or natural-language scope into structured FEAT-XXX entries with subtasks.
---

# Breaking down features

## When to invoke

- Right after `superpowers:writing-plans` produces a plan and the user approves it.
- User describes new desired scope (e.g. "I want users to export to PDF").
- An existing feature in `in-progress.md` has subtasks that are themselves too large.

## Steps

1. Determine target file (default: `features/backlog.md`; if work starts now: `features/in-progress.md`).
2. Read existing feature IDs across all three files. Compute next FEAT-XXX.
3. For each new feature, write the entry following `docs/feature-format.md`.
4. If deriving from a Superpowers plan, the plan's tasks (`### Task N`) become subtasks `FEAT-XXX.N`. Preserve task numbering.
5. If the feature goes to `in-progress.md`, suggest a branch name with format `feat/feat-NNN-<slug>` (derive slug from title: lowercase, hyphens, strip accents and non-alphanumerics). Features in `backlog.md` get `Branch: none`.

## Sizing rules

- A feature: deliverable user value, typically 30 min – 2 days of agent work.
- A subtask: one Superpowers task, typically 2–30 min.
- If a subtask exceeds 30 min mental estimate, promote it to its own feature with `Parent: FEAT-XXX`.

## Anti-patterns

- DO NOT auto-create more than 3 features without showing the user the proposed entries first.
- DO NOT renumber existing FEAT-XXX. IDs are immutable.
- DO NOT collapse subtasks into one bullet. Each is a checkbox.
- DO NOT set a real branch name for features in `backlog.md`. Always use `none`.
```

- [ ] **Step 4.4: Edit `skills/tracking-progress/SKILL.md` — keep as-is**

This skill does not reference `parse-features.sh` or any deleted module. Verify with:

```bash
grep -E 'parse-features|verify-harness|consulting-project-map|harness-doctor|harness-create-branch|harness-open-pr' skills/tracking-progress/SKILL.md
```
Expected: no matches. If matches found, remove those lines; otherwise leave file untouched.

- [ ] **Step 4.5: Verify all four skills ≤ 50 lines**

Run:
```bash
wc -l skills/*/SKILL.md
```
Expected: each line count ≤ 50.

- [ ] **Step 4.6: Commit**

```bash
git add skills/
git commit -m "simplify: rewrite 4 remaining skills to essential content only"
```

---

## Task 5: Phase 5 — Rewrite `templates/AGENTS.md` and `templates/init.sh`

**Files:**
- Modify: `templates/AGENTS.md`
- Modify: `templates/init.sh`

- [ ] **Step 5.1: Overwrite `templates/AGENTS.md`**

```markdown
# Project protocol

This project uses **Superpowers** + **claude-harness**.

## State files

| File | Purpose |
|---|---|
| `progress/current.md` | In-flight work (updated during session, drained at end) |
| `progress/history.md` | Append-only session log |
| `features/backlog.md` | Not started |
| `features/in-progress.md` | Active work |
| `features/done.md` | Completed — NEVER edit |

## Rules

1. Features move: backlog → in-progress → done. Never skip in-progress.
2. A feature goes to done only when ALL subtasks are `[x]` AND `Verified: <date>` is set.
3. Never edit done.md. Create a new feature with `Supersedes: FEAT-XXX`.
4. Feature IDs (FEAT-XXX) are immutable.
5. After a Superpowers plan is written, derive feature entries via `breaking-down-features`.

## Project-specific

- TODO(user): describe the project's domain.
- TODO(user): list verification commands.
```

- [ ] **Step 5.2: Overwrite `templates/init.sh`**

```bash
#!/usr/bin/env bash
# Installed by claude-harness. Edit to add project-specific setup.
set -euo pipefail

echo "[init.sh] starting..."

mkdir -p progress/subagents features

_create_if_missing() {
  local file="$1" header="$2"
  if [ ! -s "$file" ]; then
    printf '%s\n' "$header" > "$file"
    echo "[init.sh] created $file"
  fi
}

_create_if_missing "progress/current.md" "# Current work

_(none in flight)_"

_create_if_missing "progress/history.md" "# Session history
"

_create_if_missing "features/backlog.md" "# Backlog
"

_create_if_missing "features/in-progress.md" "# In progress
"

_create_if_missing "features/done.md" "# Done

<!-- FORBIDDEN to edit existing entries. Create a successor with Supersedes: FEAT-XXX. -->
"

# Detect tooling and run lightweight setup (non-fatal)
[ -f package.json ] && command -v node >/dev/null 2>&1 && \
  { echo "[init.sh] node project; npm install..."; npm install --silent 2>/dev/null || true; }

[ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1 && \
  { echo "[init.sh] rust project; cargo check..."; cargo check --quiet 2>/dev/null || true; }

[ -f go.mod ] && command -v go >/dev/null 2>&1 && \
  { echo "[init.sh] go project; go mod download..."; go mod download 2>/dev/null || true; }

# Generate codebase map (always regenerated)
_codebase_map() {
  local out="progress/codebase-map.md"
  local now; now=$(date '+%Y-%m-%d %H:%M' 2>/dev/null || date)
  local tree_output
  if command -v tree >/dev/null 2>&1; then
    tree_output=$(tree -L 3 -a \
      -I 'node_modules|.git|__pycache__|.venv|venv|.next|dist|build|.claude' 2>/dev/null || true)
  else
    tree_output=$(find . -maxdepth 3 \
      \( -path '*/node_modules' -o -path '*/.git' -o -path '*/__pycache__' \
         -o -path '*/.venv' -o -path '*/venv' -o -path '*/.next' \
         -o -path '*/dist' -o -path '*/build' -o -path '*/.claude' \) -prune -o -print 2>/dev/null | sort)
  fi
  {
    echo "# Codebase Map"
    echo "> Auto-generated by init.sh — $now"
    echo ""
    echo '```'
    echo "$tree_output"
    echo '```'
  } > "$out"
  echo "[init.sh] codebase map -> $out"
}
_codebase_map

echo "[init.sh] OK"
```

- [ ] **Step 5.3: Verify line counts**

Run:
```bash
wc -l templates/AGENTS.md templates/init.sh
chmod +x templates/init.sh
```
Expected: `AGENTS.md` ~20 lines, `init.sh` ~60 lines.

- [ ] **Step 5.4: Smoke test `init.sh` in a sandbox**

Run:
```bash
TMP=$(mktemp -d) && cp templates/init.sh "$TMP/" && (cd "$TMP" && bash init.sh) && \
  ls "$TMP/progress" "$TMP/features" && rm -rf "$TMP"
```
Expected: `current.md`, `history.md`, `codebase-map.md` under `progress/`; `backlog.md`, `in-progress.md`, `done.md` under `features/`. No errors.

- [ ] **Step 5.5: Commit**

```bash
git add templates/AGENTS.md templates/init.sh
git commit -m "simplify: lean templates — AGENTS.md, init.sh"
```

---

## Task 6: Phase 6 — Rewrite `scripts/install-into-project.sh`

**Files:**
- Modify: `scripts/install-into-project.sh`

Drops: v0.2 config layer, v0.4 project-map, v0.5 CLAUDE.md injection, snapshot pre-population, formatter auto-detect, `.gitignore` manipulation. Keeps: template copy (idempotent, never overwrite), directory creation, next-steps echo.

- [ ] **Step 6.1: Overwrite `scripts/install-into-project.sh`**

```bash
#!/usr/bin/env bash
# Install claude-harness templates into the current project. Idempotent.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-$(pwd)}"

if [ ! -d "$TARGET" ]; then
  echo "Target directory does not exist: $TARGET" >&2
  exit 1
fi

cd "$TARGET"

# Required directories
mkdir -p progress/subagents features docs/superpowers/plans docs/superpowers/specs

# Copy templates without overwriting existing user content
_copy_if_missing() {
  local src="$1" dst="$2"
  if [ ! -e "$dst" ]; then
    cp "$src" "$dst"
    echo "  + $dst"
  else
    echo "  = $dst (kept)"
  fi
}

echo "Installing claude-harness templates into $TARGET..."

_copy_if_missing "$PLUGIN_ROOT/templates/AGENTS.md"             "AGENTS.md"
_copy_if_missing "$PLUGIN_ROOT/templates/init.sh"               "init.sh"
chmod +x init.sh 2>/dev/null || true

_copy_if_missing "$PLUGIN_ROOT/templates/progress/.gitignore"   "progress/.gitignore"
_copy_if_missing "$PLUGIN_ROOT/templates/progress/current.md"   "progress/current.md"
_copy_if_missing "$PLUGIN_ROOT/templates/progress/history.md"   "progress/history.md"

_copy_if_missing "$PLUGIN_ROOT/templates/features/README.md"    "features/README.md"
_copy_if_missing "$PLUGIN_ROOT/templates/features/backlog.md"   "features/backlog.md"
_copy_if_missing "$PLUGIN_ROOT/templates/features/in-progress.md" "features/in-progress.md"
_copy_if_missing "$PLUGIN_ROOT/templates/features/done.md"      "features/done.md"

echo ""
echo "Done. Next steps:"
echo "  1. Open AGENTS.md and fill in the project-specific TODOs."
echo "  2. Start a new Claude Code session; SessionStart will inject context."
```

- [ ] **Step 6.2: Verify line count**

Run:
```bash
wc -l scripts/install-into-project.sh
chmod +x scripts/install-into-project.sh
```
Expected: ≤ 45 lines.

- [ ] **Step 6.3: Smoke test in a sandbox**

Run:
```bash
TMP=$(mktemp -d) && bash scripts/install-into-project.sh "$TMP" && \
  ls "$TMP" "$TMP/progress" "$TMP/features" && \
  bash scripts/install-into-project.sh "$TMP" && \
  rm -rf "$TMP"
```
Expected: first run creates everything (lines prefixed `+`); second run is idempotent (lines prefixed `=`).

- [ ] **Step 6.4: Commit**

```bash
git add scripts/install-into-project.sh
git commit -m "simplify: install-into-project.sh does only template copy"
```

---

## Task 7: Phase 7 — Delete `scripts/lib/parse-features.sh` (orphaned)

**Files:**
- Delete: `scripts/lib/parse-features.sh`
- Delete: `tests/test-parse-features.sh`
- Delete: `tests/fixtures/sample-feature-list.md`
- Modify: `docs/feature-format.md` (drop the lone `next_feature_id` reference)

After Phase 1's deletions, the only consumer of `parse-features.sh` was `verifying-features` (already deleted). The agent can verify subtask completion with `grep` directly, so the helper is dead weight.

- [ ] **Step 7.1: Confirm no live consumers remain**

Run:
```bash
grep -rn "parse-features\|list_feature_ids\|next_feature_id\|feature_status\|count_subtasks\|check_complete" \
  --include='*.sh' --include='*.json' --include='*.md' \
  hooks/ skills/ scripts/ templates/ docs/feature-format.md 2>/dev/null \
  | grep -v -E '(parse-features\.sh|test-parse-features\.sh|sample-feature-list\.md)'
```
Expected: one line — the `next_feature_id` mention in `docs/feature-format.md`. Anything else is a real consumer; stop and investigate.

- [ ] **Step 7.2: Delete files and fixture**

```bash
git rm scripts/lib/parse-features.sh \
       tests/test-parse-features.sh \
       tests/fixtures/sample-feature-list.md
```

- [ ] **Step 7.3: Edit `docs/feature-format.md`**

Locate the line referencing `next_feature_id` (in the "ID assignment" section) and replace it with prose. Use the Edit tool with these exact strings.

Old:
```
- To find the next available ID: run `next_feature_id features/` from `scripts/lib/parse-features.sh`.
```

New:
```
- To find the next available ID: scan all three `features/*.md` files for `^## FEAT-NNN` and take `max(NNN) + 1`.
```

- [ ] **Step 7.4: Remove empty `scripts/lib` if it has no other files**

Run:
```bash
[ -d scripts/lib ] && [ -z "$(ls -A scripts/lib 2>/dev/null)" ] && rmdir scripts/lib && echo "removed empty scripts/lib"
```

- [ ] **Step 7.5: Commit**

```bash
git add -A scripts/lib tests/test-parse-features.sh tests/fixtures/sample-feature-list.md docs/feature-format.md
git commit -m "cleanup: remove parse-features.sh (orphaned after verifying-features deletion)"
```

---

## Task 8: Phase 8 — Bump `plugin.json` to v1.0.0

**Files:**
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 8.1: Overwrite `.claude-plugin/plugin.json`**

```json
{
  "name": "claude-harness",
  "description": "Persistent session state and feature tracking for Claude Code. Lightweight companion to Superpowers.",
  "version": "1.0.0",
  "author": {
    "name": "Felipe Villacorte",
    "email": "fvilla.emp@gmail.com"
  },
  "homepage": "https://github.com/yulucorte/claude-harness",
  "license": "MIT"
}
```

- [ ] **Step 8.2: Verify JSON parses**

Run:
```bash
python3 -c "import json; print(json.load(open('.claude-plugin/plugin.json'))['version'])"
```
Expected: `1.0.0`.

- [ ] **Step 8.3: Commit**

```bash
git add .claude-plugin/plugin.json
git commit -m "release: v1.0.0 lean"
```

---

## Task 9: Phase 9 — Rewrite `README.md` (≤80 lines)

**Files:**
- Modify: `README.md`

- [ ] **Step 9.1: Overwrite `README.md`**

```markdown
# claude-harness

Markdown-only persistent state and feature tracking for [Claude Code](https://claude.ai/code). Lightweight companion to [Superpowers](https://github.com/obra/superpowers).

## Why

Superpowers gives Claude great working habits within a session: brainstorming → spec → plan → TDD execution → review. But it does not solve:

- **Cross-session state** — what was the agent doing yesterday?
- **Canonical feature scope** — which work is actually committed to, and is it actually done?
- **Context at session start** — without re-reading the whole repo on each `/clear` or compact.

claude-harness fills exactly those three gaps. Nothing more.

## Install

```bash
# Once, per Claude Code install:
/plugin install yulucorte/claude-harness

# Once, per project:
bash ~/.claude/plugins/cache/.../claude-harness/scripts/install-into-project.sh
```

The install script copies templates into the current project. It is idempotent and never overwrites existing files.

## What it creates in your project

| Path | Purpose |
|---|---|
| `AGENTS.md` | Protocol the agent reads at session start |
| `init.sh` | Runs on every SessionStart to refresh `progress/codebase-map.md` |
| `progress/current.md` | In-flight work for the current session |
| `progress/history.md` | Append-only session log |
| `progress/subagents/` | One file per dispatched subagent |
| `features/backlog.md` | Not started |
| `features/in-progress.md` | Active work |
| `features/done.md` | Completed — never edit |

## Flow

1. **Brainstorm** with `superpowers:brainstorming`. Spec goes to `docs/superpowers/specs/`.
2. **Plan** with `superpowers:writing-plans`. Plan goes to `docs/superpowers/plans/`.
3. **Derive features** with `breaking-down-features`. Entries land in `features/backlog.md` or `features/in-progress.md`.
4. **Execute** with `superpowers:subagent-driven-development`. Each dispatch is logged by `tracking-progress`.
5. **Done** moves a feature to `done.md` only when ALL subtasks are `[x]` AND `Verified: <date>` is set.

## Philosophy

- **Markdown only.** No JSON, YAML, or SQLite state files. Anything the agent writes is anything you can `grep`.
- **Append-only `done.md`.** Edits there are forbidden. Successors carry a `Supersedes: FEAT-XXX` line.
- **Immutable FEAT IDs.** Once assigned, never renumber.
- **3 hooks, 4 skills.** If you cannot justify a new one in one sentence, it does not belong here.

## License

MIT — see [LICENSE](LICENSE).
```

- [ ] **Step 9.2: Verify line count**

Run:
```bash
wc -l README.md
```
Expected: ≤ 80 lines.

- [ ] **Step 9.3: Recreate a minimal `CHANGELOG.md`**

```markdown
# Changelog

## 1.0.0 — 2026-05-25

Lean rewrite. The harness now does exactly three things: persistent session state, controlled feature movement, and SessionStart context injection.

### Removed (vs 0.5.0)
- All `PostToolUse`, `PreToolUse`, and `Stop` hooks (formatter, safety, checkpoint, watchers, notify).
- Skills: `consulting-project-map`, `harness-create-branch`, `harness-doctor`, `harness-open-pr`, `verify-harness-hooks`, `verifying-features`, `handing-off-session`, `scaffolding-environment`.
- `scripts/harness/` (doctor, pr-open, pr-merge, rollback).
- `scripts/lib/parse-features.sh`, `scripts/lib/checkpoint.sh`, all `hooks/lib/`.
- Config layer (`templates/.claude-harness/`).
- Project map and ADR templates.
- v0.2/v0.4/v0.5 install-time migrations.

### Kept and simplified
- 3 hooks: `SessionStart`, `SessionEnd`, `PreCompact`.
- 4 skills: `using-claude-harness`, `managing-feature-list`, `breaking-down-features`, `tracking-progress`.
- 1 install script that copies templates and exits.
```

- [ ] **Step 9.4: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: rewrite README for v1.0"
```

---

## Task 10: Phase 10 — Verify remaining tests pass and prune broken ones

**Files:**
- Possibly modify: `tests/test-install.sh`, `tests/test-init-codebase-map.sh`

- [ ] **Step 10.1: List remaining tests**

Run:
```bash
ls tests/test-*.sh
```
Expected (after Phase 1 + Phase 7 deletions): only `test-install.sh` and `test-init-codebase-map.sh` remain.

- [ ] **Step 10.2: Run the self-test suite and capture output**

Run:
```bash
bash scripts/self-test.sh
```
Expected: `Results: 2 pass, 0 fail`. If a test fails because it referenced a deleted file or v0.2/v0.4 behavior, edit or delete it.

- [ ] **Step 10.3: Repair `tests/test-install.sh` if it fails**

Common likely failure modes for this test against the lean install script:

- It asserts the existence of `.claude-harness/config.sh` → remove that assertion.
- It asserts the presence of `docs/project-map.md` → remove that assertion.
- It asserts CLAUDE.md injection content → remove that assertion.
- It runs against a snapshot of the old install script → re-record expected output.

Apply the minimum edits to make the test reflect the new contract: install script copies templates idempotently and prints `+`/`=` lines.

- [ ] **Step 10.4: Repair `tests/test-init-codebase-map.sh` if it fails**

Likely failure modes:

- It asserts `_env_report` output (removed) → drop those assertions.
- It asserts smoke-test output (removed) → drop those assertions.
- The codebase-map generation itself is preserved, so its core checks should still pass.

- [ ] **Step 10.5: Re-run and confirm green**

Run:
```bash
bash scripts/self-test.sh
```
Expected: all remaining tests pass.

- [ ] **Step 10.6: Commit**

```bash
git add tests/
git commit -m "test: update remaining tests for v1.0"
```

---

## Task 11: Final verification

**Files:** (read-only checks)

- [ ] **Step 11.1: File count**

Run:
```bash
find . -not -path './.git/*' -not -path './node_modules/*' -type f | wc -l
```
Expected: roughly 20–25 files. Significantly more means dead files were missed; significantly less means something critical was deleted.

- [ ] **Step 11.2: Exactly 3 hooks in `hooks.json`**

Run:
```bash
python3 -c "import json; h=json.load(open('hooks/hooks.json'))['hooks']; print(sorted(h.keys()))"
```
Expected: `['PreCompact', 'SessionEnd', 'SessionStart']`.

- [ ] **Step 11.3: Exactly 4 skill directories**

Run:
```bash
ls -d skills/*/ | wc -l
ls -d skills/*/
```
Expected: count is `4`; entries are `breaking-down-features`, `managing-feature-list`, `tracking-progress`, `using-claude-harness`.

- [ ] **Step 11.4: Each skill ≤ 50 lines**

Run:
```bash
wc -l skills/*/SKILL.md
```
Expected: every line count ≤ 50.

- [ ] **Step 11.5: `session-start.sh` ≤ 60 lines**

Run:
```bash
wc -l hooks/session-start.sh
```
Expected: ≤ 60.

- [ ] **Step 11.6: Full test suite green**

Run:
```bash
bash scripts/self-test.sh
```
Expected: all pass.

- [ ] **Step 11.7: Tag the release**

Only after every check above is green.

```bash
git tag v1.0.0
git log --oneline -15
```
Expected: a clean sequence of 10 phase commits ending at the v1.0.0 tag.

---

## Global rules

- **Incremental commits**: exactly one per phase.
- **Never break what remains**: each phase ends with a functional repo.
- **If a file is not in a keep list, it is deleted.** No "just in case".
- **No new dependencies**: bash, grep, awk, find, sed, python3.
- **Language of skills and templates**: English (open-source plugin).
