# Project hooks + PR automation — Design spec

**Date:** 2026-05-11
**Status:** approved
**Supersedes:** none
**Builds on:** `2026-05-04-branch-wip-limit-design.md`

---

## Problem

claude-harness v0.1.0 tracks features and progress, but the publish-to-GitHub workflow remains entirely manual:

1. No deterministic enforcement of repetitive actions (formatting, safety checks, notifications) — these rely on Claude remembering to do them via prompts, which is unreliable.
2. The PR lifecycle (branch creation → commits → PR → merge → history update) requires the user or Claude to execute each step manually, often forgetting one.
3. The existing Branch + WIP spec leaves git operations as "Claude only suggests commands" (non-goal). With deterministic hooks now available, we can safely automate these — opt-in, preserving the original behavior by default.
4. Hooks today are silent. There is no log, no health check, no graceful degradation path. A broken hook can fail invisibly.

## Goals

1. Add a layer of **project hooks** that the harness installs into any project, each with a single responsibility.
2. Implement **deterministic PR automation** that integrates with the existing `Branch:` field and WIP limit.
3. Provide a **per-project config** (`.claude-harness/config.sh`) controlling which hooks are active and how they behave.
4. Ensure **observability** via `progress/hooks.log` and the `verify-harness-hooks` health-check skill.
5. **Degrade gracefully** when external tools (`gh`, formatters) are missing — never block Claude's workflow.
6. **Preserve backward compatibility**: defaults match v0.1.0 behavior. Upgrading is non-disruptive.

## Non-goals

- Replacing the Branch + WIP spec — this design builds on top of it.
- Enforcing a specific merge strategy beyond what `gh pr merge` defaults provide.
- Multi-project orchestration (each project has its own config).
- Replacing CI/CD systems — this is local workflow automation, not deploy pipelines.

---

## Design

### 1. Architecture

A new layer of project hooks lives in the plugin and registers via `hooks/hooks.json`. Each hook has a single responsibility. A shared config file (`.claude-harness/config.sh`) at the project root controls behavior.

```
claude-harness/
  hooks/
    # Existing (unchanged)
    session-start.sh
    session-end.sh
    pre-compact.sh
    post-edit-checkpoint.sh

    # New
    post-edit-format.sh
    post-edit-in-progress-watcher.sh
    post-edit-done-watcher.sh
    pre-tool-safety.sh
    stop-notify.sh

    lib/
      defaults.sh                  # baked-in defaults, never edited
      load-config.sh               # validates + sources config.sh, falls back to defaults
      read-feature.sh              # parses feature entries from in-progress/done
      log-hook-event.sh            # appends structured event to hooks.log
      acquire-lock.sh              # flock-based project-level lock

  scripts/harness/
    pr-open.sh
    pr-merge.sh
    rollback-feature.sh

  skills/
    verify-harness-hooks/SKILL.md  # health check

  templates/
    .claude-harness/
      config.sh                    # project config template
```

### 2. Per-project config

`templates/.claude-harness/config.sh` (copied to project root on install):

```bash
# Formatter to run on edited files (.ts, .tsx, .js, .jsx, .go, .py)
# Values: prettier | gofmt | ruff | none
HARNESS_FORMATTER=none

# OS notification when Claude finishes responding
HARNESS_NOTIFY=true

# Automatic branch creation when feature enters in-progress.md
# Default false: preserves Branch+WIP spec's non-goal of "Claude only suggests commands"
HARNESS_AUTO_BRANCH=false

# Automatic PR open when feature enters done.md
HARNESS_AUTO_PR=false

# Safety rules mode
# Values: strict | permissive
HARNESS_SAFETY_RULES=strict

# Base branch for PRs
HARNESS_GITHUB_BASE=main

# Per-rule safety overrides (when SAFETY_RULES=strict)
# Set to true to disable a specific rule
HARNESS_ALLOW_RM_HOME=false
HARNESS_ALLOW_FORCE_PUSH_MAIN=false
HARNESS_ALLOW_RESET_HARD=false
HARNESS_ALLOW_CONFIG_EDIT=false

# Log rotation
HARNESS_LOG_MAX_BYTES=5242880        # 5MB
HARNESS_LOG_ROTATIONS=3
```

Per-user overrides allowed via `.claude-harness/config.local.sh` (sourced after `config.sh`, gitignored).

### 3. Hook specifications

#### 3.1 `post-edit-format.sh`

- **Trigger:** PostToolUse, matcher `Edit|Write|MultiEdit`
- **Input:** JSON on stdin with `tool_name`, `tool_input.file_path`
- **Behavior:**
  - Source `lib/load-config.sh`
  - Skip if `file_path` matches `features/`, `progress/`, `.claude-harness/` (handled elsewhere)
  - Lookup formatter for extension:
    - `.ts|.tsx|.js|.jsx|.json|.md` → `prettier`
    - `.go` → `gofmt`
    - `.py` → `ruff format`
  - Honor `HARNESS_FORMATTER=none` → skip
  - If formatter binary not found: `log-hook-event SKIP reason=formatter-missing formatter=$F`, exit 0
  - Run formatter; capture exit code
  - Log SUCCESS or ERROR
- **Exit:** 0 always (never blocks Claude)

#### 3.2 `post-edit-in-progress-watcher.sh`

- **Trigger:** PostToolUse, matcher `Edit|Write|MultiEdit`
- **Input:** JSON on stdin with `tool_input.file_path`
- **Behavior:**
  - Skip if `file_path` ≠ `features/in-progress.md`
  - Acquire project lock (timeout 5s)
  - Parse current `in-progress.md` for feature entries
  - Compare against `progress/.in-progress.snapshot` to detect new entries
  - For each new entry:
    - Read `Branch:` field via `lib/read-feature.sh`
    - If field missing/malformed: `log ERROR feature=$ID reason=branch-field-invalid`, skip
    - If `HARNESS_AUTO_BRANCH=true`: run `git switch -c $BRANCH`; log SUCCESS or ERROR
    - If `HARNESS_AUTO_BRANCH=false`: `log INFO feature=$ID action=manual-branch-suggested cmd="git switch -c $BRANCH"`
  - Update snapshot file (atomic write: temp file + `mv`)
  - Release lock
- **Exit:** 0 always

#### 3.3 `post-edit-done-watcher.sh`

- **Trigger:** PostToolUse, matcher `Edit|Write|MultiEdit`
- **Input:** JSON on stdin with `tool_input.file_path`
- **Behavior:**
  - Skip if `file_path` ≠ `features/done.md`
  - Acquire project lock (timeout 5s; on timeout: `log WARNING lock-timeout`, skip)
  - Parse current `done.md` for feature entries
  - Compare against `progress/.done.snapshot` to detect new entries
  - For each new entry:
    - Read `Branch:` field
    - Check current branch == `Branch:` field. If mismatch: `log WARNING reason=branch-mismatch current=$X expected=$Y`, skip
    - If `HARNESS_AUTO_PR=true`: invoke `scripts/harness/pr-open.sh $FEAT_ID`
    - If `false`: trigger notification "Feature $FEAT_ID ready for PR"
  - Update snapshot (atomic write: temp file + `mv`)
  - Release lock
- **Exit:** 0 always

#### 3.4 `pre-tool-safety.sh`

- **Trigger:** PreToolUse (no matcher — all tools)
- **Input:** JSON on stdin with `tool_name`, `tool_input`
- **Behavior:**
  - Source config
  - If `HARNESS_SAFETY_RULES=permissive`: log any match but exit 0
  - Rules (each has a stable ID, evaluated in order):

    | Rule ID | Match | Default |
    |---|---|---|
    | `RM_HOME` | `Bash` with `rm -rf /` or `rm -rf ~` or `rm -rf $HOME` | block |
    | `FORCE_PUSH_MAIN` | `Bash` with `git push --force` to `main`/`master` | block |
    | `RESET_HARD` | `Bash` matching regex `git\s+reset\s+--hard\b` | block |
    | `CONFIG_EDIT` | `Edit`/`Write` targeting `.claude-harness/config.sh` | block |

  - If a rule matches and the corresponding `HARNESS_ALLOW_<ID>=true`: log INFO and pass
  - If blocked: write to stderr a message including the rule ID and the 3 escape hatches; exit 2
- **Exit:** 0 (pass) or 2 (block)

Block message format:
```
[claude-harness:pre-tool-safety] Blocked by rule RM_HOME.
Reason: 'rm -rf $HOME' would erase user home directory.
Escape hatches (least → most invasive):
  1. Allow this rule:    HARNESS_ALLOW_RM_HOME=true in .claude-harness/config.sh
  2. Disable category:   HARNESS_SAFETY_RULES=permissive
  3. Disable hook:       chmod -x <hook absolute path printed here at runtime>
```

#### 3.5 `stop-notify.sh`

- **Trigger:** Stop
- **Behavior:**
  - Skip if `HARNESS_NOTIFY=false`
  - Debounce: read `/tmp/claude-harness-last-notify-$HASH`; if last notify <30s ago, increment counter, skip
  - On dispatch: include accumulated counter if >0 ("Claude finished. 3 events queued.")
  - macOS: `osascript -e 'display notification "..." with title "Claude Code"'`
  - Linux: `notify-send "Claude Code" "..."`
- **Exit:** 0 always

### 4. Script specifications

#### 4.1 `pr-open.sh <FEAT-NNN>`

- Validate `gh auth status`; on fail: log ERROR with remediation, exit 0
- Read feature entry via `lib/read-feature.sh`
- Check fork/permission: `gh repo view --json viewerPermission`. If no write access: log ERROR with fork-workflow note, exit 0
- Check for existing PR: `gh pr list --head $BRANCH --json number`. If exists: log INFO `pr-already-exists url=$URL`, exit 0 (idempotent)
- Build PR title: `feat($FEAT_ID): $TITLE`
- Build PR body from feature's `Plan:`, `Verification:`, `Notes:` sections
- `gh pr create --title "..." --body "..." --base $HARNESS_GITHUB_BASE --head $BRANCH`
- Capture PR URL; append to `progress/history.md`
- Log SUCCESS with URL
- **Exit:** 0 always (failures logged, not surfaced as errors)

#### 4.2 `pr-merge.sh <FEAT-NNN | PR#>`

- Resolve PR number from feature ID (via `gh pr list --head $BRANCH`)
- Validate `gh pr view --json state,reviewDecision`; must be `OPEN` + `APPROVED`
- If not approved: log ERROR `pr-not-approved decision=$D`, exit 0
- `gh pr merge $PR --squash --delete-branch`
- Capture merge commit SHA from `gh pr view --json mergeCommit`
- Append to `progress/history.md`: `[date] FEAT-NNN merged in $SHA`
- Update feature entry in `done.md` with `Merged: $SHA`
- Log SUCCESS
- **Exit:** 0 always

#### 4.3 `rollback-feature.sh <FEAT-NNN>`

- Locate feature in `done.md`
- Capture PR comments via `gh pr view --comments --json comments`
- Move feature entry from `done.md` → `in-progress.md`
- Append PR comments to the feature's `### Notes` section, prefixed with `Reviewer feedback (rolled back $DATE):`
- Append to `progress/history.md`: `[date] FEAT-NNN rolled back from done`
- Log SUCCESS
- **Exit:** 0 always

### 5. Shared library specifications

#### 5.1 `lib/defaults.sh`

Defines every `HARNESS_*` variable with a safe default. Sourced first, before `config.sh`.

#### 5.2 `lib/load-config.sh`

```bash
source "$LIB_DIR/defaults.sh"

CONFIG="$PROJECT_ROOT/.claude-harness/config.sh"
if [ -f "$CONFIG" ]; then
  if bash -n "$CONFIG" 2>/tmp/harness-syntax-err; then
    source "$CONFIG"
  else
    "$LIB_DIR/log-hook-event.sh" load-config ERROR \
      reason=syntax-invalid err="$(cat /tmp/harness-syntax-err)"
    echo "[claude-harness] config.sh has syntax errors; using defaults. See progress/hooks.log" >&2
  fi
fi

LOCAL="$PROJECT_ROOT/.claude-harness/config.local.sh"
if [ -f "$LOCAL" ] && bash -n "$LOCAL"; then
  source "$LOCAL"
fi
```

#### 5.3 `lib/log-hook-event.sh <hook> <event> <key=value>...`

- Format: `[YYYY-MM-DD HH:MM:SS] <hook> <EVENT> key=value key=value`
- Event types: `SUCCESS`, `SKIP`, `BLOCK`, `WARNING`, `ERROR`, `INFO`
- Rotate when file exceeds `HARNESS_LOG_MAX_BYTES`:
  - `hooks.log.2.gz` → deleted (if rotations=3)
  - `hooks.log.1` → gzipped to `hooks.log.2.gz`
  - `hooks.log` → renamed to `hooks.log.1`
  - new `hooks.log` created

#### 5.4 `lib/acquire-lock.sh <timeout-seconds>`

- Uses `flock` on `/tmp/claude-harness-$(echo "$PROJECT_ROOT" | shasum | cut -c1-8).lock`
- On timeout: exit 1 (caller decides whether to skip or proceed)
- Concurrent Claude sessions: second instance's hooks will time out → log `SKIP reason=concurrent-session`

#### 5.5 `lib/read-feature.sh <file> <FEAT-ID>`

Parses a markdown feature entry and emits key=value pairs to stdout: `title`, `branch`, `plan`, `verification`, `notes`, `verified`. Returns non-zero if entry not found or `Branch:` field missing/malformed.

### 6. `verify-harness-hooks` skill

A skill invocable from Claude Code. Output is a table of checks with status (green/yellow/red) and remediation commands.

Checks:

1. `hooks.json` registers all 9 expected hooks
2. Each hook script exists and has executable bit set
3. `lib/*.sh` files exist
4. `.claude-harness/config.sh` exists and passes `bash -n`
5. All `HARNESS_*` vars resolve to expected types
6. `gh` CLI installed (only if `HARNESS_AUTO_PR=true`)
7. `gh auth status` healthy (only if `HARNESS_AUTO_PR=true`)
8. Formatter CLI installed (only if `HARNESS_FORMATTER` ≠ none)
9. `progress/hooks.log` exists and is writable; report size + rotation count
10. All features in `backlog.md`, `in-progress.md`, `done.md` parse correctly (Branch field valid)
11. List currently disabled safety rules (transparency)

### 7. `install-into-project.sh` changes

Extended to:

1. Copy `templates/.claude-harness/config.sh` → `$PROJECT_ROOT/.claude-harness/config.sh`
2. Detect environment to suggest defaults:
   - `package.json` with `prettier` dep → suggest `HARNESS_FORMATTER=prettier`
   - `go.mod` present → suggest `HARNESS_FORMATTER=gofmt`
   - `pyproject.toml` with `ruff` → suggest `HARNESS_FORMATTER=ruff`
   - `gh` not installed → force `HARNESS_AUTO_PR=false`, print warning
3. `chmod +x` every hook and script
4. Create `progress/hooks.log` with header
5. Add to `.gitignore`:
   - `progress/hooks.log`
   - `progress/hooks.log.*`
   - `progress/.in-progress.snapshot`
   - `progress/.done.snapshot`
   - `.claude-harness/config.local.sh`
6. Print summary of active hooks based on resolved config

### 8. Migration for existing claude-harness v0.1.0 projects

- `scaffolding-environment` skill detects missing `.claude-harness/config.sh` → asks user before creating
- New hooks register in `hooks.json` but **do nothing** while flags remain false (default)
- Upgrade path is no-op until user opts in; nothing breaks
- `verify-harness-hooks` exposes available features so users know what's possible

### 9. Updates to existing files

| File | Change |
|---|---|
| `hooks/hooks.json` | Register 5 new hooks (format, in-progress-watcher, done-watcher, safety, notify) |
| `scripts/install-into-project.sh` | Environment detection + config copy + chmod + gitignore |
| `skills/scaffolding-environment/SKILL.md` | Legacy-project detection for missing config.sh |
| `docs/workflow.md` | New section: "Project hooks" + opt-in flow for AUTO_BRANCH/AUTO_PR |
| `templates/AGENTS.md` | Mention safety hooks and config.sh |
| `templates/progress/.gitignore` | Add hooks.log* and snapshots |

---

## Coexistence with Branch + WIP spec

The 2026-05-04 spec stays intact. This design:

- **Reads** `Branch:` field; never writes it (`breaking-down-features` still owns that).
- **Respects** the WIP limit; if `in-progress.md` already has an entry, `post-edit-in-progress-watcher.sh` aborts via count check (defense in depth — `managing-feature-list` already enforces this).
- **Replaces** the spec's manual branch-cleanup reminder (step 4) with deterministic execution **only when `HARNESS_AUTO_PR=true`**. Default preserves the original behavior.
- The non-goal "Automatically creating or deleting branches" is explicitly upgraded to "opt-in via `HARNESS_AUTO_BRANCH=true`".

---

## Acceptance criteria

1. Upgrading from v0.1.0 to v0.2.0 with default config produces zero behavior change.
2. With `HARNESS_AUTO_BRANCH=true`, writing a new feature to `in-progress.md` results in `git switch -c $BRANCH` having run.
3. With `HARNESS_AUTO_PR=true`, writing a new feature to `done.md` results in a GitHub PR opened against `$HARNESS_GITHUB_BASE`.
4. `pre-tool-safety.sh` blocks `rm -rf $HOME` with a message naming rule `RM_HOME` and 3 escape hatches.
5. Every hook invocation that proceeds past the file-path skip check produces at least one event in `progress/hooks.log`. Silent skips (e.g., format hook on non-applicable files) are not logged to avoid noise.
6. `verify-harness-hooks` reports all-green on a correctly installed project.
7. With `gh` uninstalled and `HARNESS_AUTO_PR=true`, `post-edit-done-watcher.sh` logs ERROR with remediation, sends notification, exits 0 — Claude session continues uninterrupted.
8. Current branch mismatch with feature `Branch:` field causes `post-edit-done-watcher.sh` to skip with a logged WARNING.
9. `rollback-feature.sh FEAT-NNN` moves entry done → in-progress, captures PR comments into `### Notes`, logs to history.
10. Corrupting `.claude-harness/config.sh` (intentionally invalid bash) does not break hooks — they fall back to defaults and log ERROR with the syntax error line.
11. Running two Claude sessions on the same project: the second session's hooks log `SKIP reason=concurrent-session` and exit 0.
12. `hooks.log` rotates at 5MB; oldest rotation is gzipped; total rotations capped at `HARNESS_LOG_ROTATIONS`.
13. PR opened twice for same branch: second invocation logs `pr-already-exists` and exits 0 (idempotent).
14. User on fork without write access: `pr-open.sh` logs ERROR with fork-workflow note, exits 0.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| `hooks.log` unbounded growth | Rotation at 5MB; max 3 rotations; oldest gzipped; `verify` skill exposes size |
| `config.sh` syntax errors | `lib/load-config.sh` runs `bash -n` first; falls back to `lib/defaults.sh`; logs ERROR with line |
| Race between checkpoint and done-watcher | Shared `flock` on project hash; 5s timeout; skip with WARNING on timeout |
| Safety hook false positive | Per-rule ID with `HARNESS_ALLOW_<ID>=true`; category override; hook disable — all surfaced in block message |
| `gh` auth expires mid-session | Scripts run `gh auth status` first; log ERROR with remediation; exit 0 |
| Hook scripts non-executable after clone | `install-into-project.sh` runs `chmod +x`; `verify` skill checks |
| Notification spam | 30s debounce; accumulate counter; single notification with count |
| Duplicate PR | `pr-open.sh` checks `gh pr list --head $BRANCH` first; idempotent |
| Fork without write access | `pr-open.sh` checks `gh repo view --json viewerPermission` first |
| Missing/malformed `Branch:` field | `lib/read-feature.sh` validates; hooks log ERROR with FEAT-ID; `verify` skill validates all entries |
| Concurrent Claude sessions | Project-level lock; second instance logs SKIP, exits 0 |
