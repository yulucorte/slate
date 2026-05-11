# Project hooks + PR automation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic project-hooks layer (formatter, safety, notifications, observability) plus opt-in PR automation (branch creation, PR open/merge/rollback) to claude-harness v0.1.0 → v0.2.0.

**Architecture:** Single shared library (`hooks/lib/`) loaded by each hook. A per-project `.claude-harness/config.sh` (with `bash -n` validated load + defaults fallback) controls behavior. All hooks exit 0 except `pre-tool-safety.sh` which uses exit 2 to block. Concurrency via `flock`. Observability via `progress/hooks.log` with rotation. Defaults preserve v0.1.0 behavior — every new capability is opt-in.

**Tech Stack:** Bash 5.x, `flock`, `gzip`, `gh` CLI, `osascript` (macOS) / `notify-send` (Linux), `git`, `jq` (already a dependency for hooks).

**Spec:** [`docs/superpowers/specs/2026-05-11-project-hooks-and-pr-automation-design.md`](../specs/2026-05-11-project-hooks-and-pr-automation-design.md)

---

## File Structure

```
claude-harness/
  hooks/
    hooks.json                              # MODIFY: register 5 new hooks
    post-edit-format.sh                     # CREATE
    post-edit-in-progress-watcher.sh        # CREATE
    post-edit-done-watcher.sh               # CREATE
    pre-tool-safety.sh                      # CREATE
    stop-notify.sh                          # CREATE
    lib/
      defaults.sh                           # CREATE
      log-hook-event.sh                     # CREATE
      load-config.sh                        # CREATE
      acquire-lock.sh                       # CREATE
      read-feature.sh                       # CREATE

  scripts/
    install-into-project.sh                 # MODIFY
    harness/
      pr-open.sh                            # CREATE
      pr-merge.sh                           # CREATE
      rollback-feature.sh                   # CREATE

  skills/
    verify-harness-hooks/SKILL.md           # CREATE
    scaffolding-environment/SKILL.md        # MODIFY

  templates/
    .claude-harness/config.sh               # CREATE
    AGENTS.md                               # MODIFY
    progress/.gitignore                     # CREATE

  docs/
    workflow.md                             # MODIFY

  tests/
    fixtures/
      feature-with-branch.md                # CREATE
      config-valid.sh                       # CREATE
      config-syntax-error.sh                # CREATE
    test-lib-defaults.sh                    # CREATE
    test-lib-log-hook-event.sh              # CREATE
    test-lib-load-config.sh                 # CREATE
    test-lib-acquire-lock.sh                # CREATE
    test-lib-read-feature.sh                # CREATE
    test-hook-format.sh                     # CREATE
    test-hook-safety.sh                     # CREATE
    test-hook-notify.sh                     # CREATE
    test-hook-in-progress-watcher.sh        # CREATE
    test-hook-done-watcher.sh               # CREATE
    test-script-pr-open.sh                  # CREATE
    test-script-pr-merge.sh                 # CREATE
    test-script-rollback.sh                 # CREATE
    test-install-v02.sh                     # CREATE

  CHANGELOG.md                              # MODIFY
  .claude-plugin/plugin.json                # MODIFY (version bump)
```

---

## Task 1: Test fixtures

**Files:**
- Create: `tests/fixtures/feature-with-branch.md`
- Create: `tests/fixtures/config-valid.sh`
- Create: `tests/fixtures/config-syntax-error.sh`

- [ ] **Step 1: Create feature fixture with Branch field**

Write `tests/fixtures/feature-with-branch.md`:

```markdown
## FEAT-007: JWT Authentication

- **Status**: in_progress
- **Created**: 2026-05-04
- **Updated**: 2026-05-04
- **Plan**: docs/superpowers/plans/2026-05-04-jwt-auth.md
- **Branch**: feat/feat-007-jwt-authentication
- **Verification**: `npm test -- auth`

### Subtasks
- [x] Design token schema
- [ ] Implement signing service
- [ ] Wire middleware

### Notes
Initial design notes here.

## FEAT-008: Refresh tokens

- **Status**: backlog
- **Created**: 2026-05-05
- **Plan**: (none)
- **Branch**: none
- **Verification**: `npm test -- refresh`

### Subtasks
- [ ] TBD
```

- [ ] **Step 2: Create valid config fixture**

Write `tests/fixtures/config-valid.sh`:

```bash
HARNESS_FORMATTER=prettier
HARNESS_NOTIFY=false
HARNESS_AUTO_BRANCH=true
HARNESS_AUTO_PR=true
HARNESS_SAFETY_RULES=strict
HARNESS_GITHUB_BASE=main
HARNESS_LOG_MAX_BYTES=1024
HARNESS_LOG_ROTATIONS=2
```

- [ ] **Step 3: Create invalid config fixture**

Write `tests/fixtures/config-syntax-error.sh`:

```bash
HARNESS_FORMATTER=prettier
HARNESS_NOTIFY=
# missing closing quote → bash -n will fail
HARNESS_AUTO_PR="oops
```

- [ ] **Step 4: Commit**

```bash
git add tests/fixtures/feature-with-branch.md tests/fixtures/config-valid.sh tests/fixtures/config-syntax-error.sh
git commit -m "test: add fixtures for project-hooks feature"
```

---

## Task 2: `lib/defaults.sh` — baked-in defaults

**Files:**
- Create: `hooks/lib/defaults.sh`
- Test: `tests/test-lib-defaults.sh`

- [ ] **Step 1: Write the failing test**

Write `tests/test-lib-defaults.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$PLUGIN_ROOT/hooks/lib/defaults.sh"

expect_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL $name: expected '$expected', got '$actual'"
    exit 1
  fi
  echo "PASS: $name=$actual"
}

expect_eq "HARNESS_FORMATTER" "none" "$HARNESS_FORMATTER"
expect_eq "HARNESS_NOTIFY" "true" "$HARNESS_NOTIFY"
expect_eq "HARNESS_AUTO_BRANCH" "false" "$HARNESS_AUTO_BRANCH"
expect_eq "HARNESS_AUTO_PR" "false" "$HARNESS_AUTO_PR"
expect_eq "HARNESS_SAFETY_RULES" "strict" "$HARNESS_SAFETY_RULES"
expect_eq "HARNESS_GITHUB_BASE" "main" "$HARNESS_GITHUB_BASE"
expect_eq "HARNESS_ALLOW_RM_HOME" "false" "$HARNESS_ALLOW_RM_HOME"
expect_eq "HARNESS_ALLOW_FORCE_PUSH_MAIN" "false" "$HARNESS_ALLOW_FORCE_PUSH_MAIN"
expect_eq "HARNESS_ALLOW_RESET_HARD" "false" "$HARNESS_ALLOW_RESET_HARD"
expect_eq "HARNESS_ALLOW_CONFIG_EDIT" "false" "$HARNESS_ALLOW_CONFIG_EDIT"
expect_eq "HARNESS_LOG_MAX_BYTES" "5242880" "$HARNESS_LOG_MAX_BYTES"
expect_eq "HARNESS_LOG_ROTATIONS" "3" "$HARNESS_LOG_ROTATIONS"

echo "All defaults tests passed."
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-lib-defaults.sh
bash tests/test-lib-defaults.sh
```

Expected: FAIL with "No such file or directory: hooks/lib/defaults.sh"

- [ ] **Step 3: Create defaults.sh**

Write `hooks/lib/defaults.sh`:

```bash
#!/usr/bin/env bash
# Baked-in defaults for claude-harness project hooks.
# Sourced FIRST, before any user config. Never edit at runtime — override via
# .claude-harness/config.sh (project) or .claude-harness/config.local.sh (user).

: "${HARNESS_FORMATTER:=none}"
: "${HARNESS_NOTIFY:=true}"
: "${HARNESS_AUTO_BRANCH:=false}"
: "${HARNESS_AUTO_PR:=false}"
: "${HARNESS_SAFETY_RULES:=strict}"
: "${HARNESS_GITHUB_BASE:=main}"

: "${HARNESS_ALLOW_RM_HOME:=false}"
: "${HARNESS_ALLOW_FORCE_PUSH_MAIN:=false}"
: "${HARNESS_ALLOW_RESET_HARD:=false}"
: "${HARNESS_ALLOW_CONFIG_EDIT:=false}"

: "${HARNESS_LOG_MAX_BYTES:=5242880}"
: "${HARNESS_LOG_ROTATIONS:=3}"
```

- [ ] **Step 4: Run test, verify it passes**

```bash
bash tests/test-lib-defaults.sh
```

Expected: All "PASS:" lines, ends with "All defaults tests passed."

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/defaults.sh tests/test-lib-defaults.sh
git commit -m "feat(hooks): add lib/defaults.sh with baked-in HARNESS_* defaults"
```

---

## Task 3: `lib/log-hook-event.sh` — structured logging with rotation

**Files:**
- Create: `hooks/lib/log-hook-event.sh`
- Test: `tests/test-lib-log-hook-event.sh`

- [ ] **Step 1: Write the failing test**

Write `tests/test-lib-log-hook-event.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
mkdir -p "$TMPDIR/progress"
export HARNESS_LOG_MAX_BYTES=200
export HARNESS_LOG_ROTATIONS=2

LOG="$PROJECT_ROOT/progress/hooks.log"
SCRIPT="$PLUGIN_ROOT/hooks/lib/log-hook-event.sh"

# Test 1: basic format
"$SCRIPT" test-hook SUCCESS key1=val1 key2=val2
line=$(cat "$LOG")
if ! echo "$line" | grep -qE '^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\] test-hook SUCCESS key1=val1 key2=val2$'; then
  echo "FAIL format: got '$line'"
  exit 1
fi
echo "PASS: log format"

# Test 2: append, not overwrite
"$SCRIPT" test-hook SKIP reason=test
lines=$(wc -l < "$LOG")
if [ "$lines" != "2" ]; then
  echo "FAIL append: expected 2 lines, got $lines"
  exit 1
fi
echo "PASS: append mode"

# Test 3: rotation triggers when log exceeds max bytes
for i in 1 2 3 4 5 6 7 8 9 10; do
  "$SCRIPT" test-hook INFO iteration="$i" padding=xxxxxxxxxxxxxxxxxxxxxxxxxx
done
if [ ! -f "$LOG.1" ]; then
  echo "FAIL rotation: $LOG.1 does not exist"
  ls -la "$TMPDIR/progress"
  exit 1
fi
echo "PASS: rotation creates .1"

# Test 4: oldest rotation deleted when count exceeds HARNESS_LOG_ROTATIONS
for i in 1 2 3 4 5 6 7 8 9 10; do
  "$SCRIPT" test-hook INFO iteration="$i" padding=xxxxxxxxxxxxxxxxxxxxxxxxxx
done
# With HARNESS_LOG_ROTATIONS=2 we should have at most: hooks.log + hooks.log.1 + hooks.log.2.gz
if [ -f "$LOG.3" ] || [ -f "$LOG.3.gz" ]; then
  echo "FAIL retention: too many rotations exist"
  ls -la "$TMPDIR/progress"
  exit 1
fi
echo "PASS: rotation retention"

# Test 5: oldest is gzipped
if [ ! -f "$LOG.2.gz" ]; then
  echo "FAIL gzip: $LOG.2.gz expected"
  ls -la "$TMPDIR/progress"
  exit 1
fi
echo "PASS: oldest rotation gzipped"

rm -rf "$TMPDIR"
echo "All log-hook-event tests passed."
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-lib-log-hook-event.sh
bash tests/test-lib-log-hook-event.sh
```

Expected: FAIL "No such file or directory"

- [ ] **Step 3: Create log-hook-event.sh**

Write `hooks/lib/log-hook-event.sh`:

```bash
#!/usr/bin/env bash
# Usage: log-hook-event.sh <hook-name> <event-type> [key=value]...
# Appends a structured event to $PROJECT_ROOT/progress/hooks.log.
# Rotates when file exceeds $HARNESS_LOG_MAX_BYTES; keeps $HARNESS_LOG_ROTATIONS rotations,
# oldest gzipped.

set -u

HOOK_NAME="${1:-unknown}"
EVENT_TYPE="${2:-INFO}"
shift 2 || true

# Defaults if env not loaded
: "${PROJECT_ROOT:=$(pwd)}"
: "${HARNESS_LOG_MAX_BYTES:=5242880}"
: "${HARNESS_LOG_ROTATIONS:=3}"

LOG="$PROJECT_ROOT/progress/hooks.log"
mkdir -p "$(dirname "$LOG")"

# Build line
TS="$(date '+%Y-%m-%d %H:%M:%S')"
LINE="[$TS] $HOOK_NAME $EVENT_TYPE"
for kv in "$@"; do
  LINE="$LINE $kv"
done

# Append atomically
echo "$LINE" >> "$LOG"

# Rotate if needed
size=$(wc -c < "$LOG" 2>/dev/null | tr -d ' ')
if [ "${size:-0}" -gt "$HARNESS_LOG_MAX_BYTES" ]; then
  # Drop oldest (.N or .N.gz)
  oldest_n="$HARNESS_LOG_ROTATIONS"
  [ -f "$LOG.$oldest_n" ] && rm -f "$LOG.$oldest_n"
  [ -f "$LOG.$oldest_n.gz" ] && rm -f "$LOG.$oldest_n.gz"

  # Shift each rotation up by one (from oldest-1 down to 1)
  i=$((oldest_n - 1))
  while [ "$i" -ge 1 ]; do
    next=$((i + 1))
    if [ -f "$LOG.$i.gz" ]; then
      mv "$LOG.$i.gz" "$LOG.$next.gz"
    elif [ -f "$LOG.$i" ]; then
      # If we're about to become the OLDEST kept rotation, gzip
      if [ "$next" -eq "$oldest_n" ]; then
        gzip -c "$LOG.$i" > "$LOG.$next.gz"
        rm -f "$LOG.$i"
      else
        mv "$LOG.$i" "$LOG.$next"
      fi
    fi
    i=$((i - 1))
  done

  # Rotate current → .1
  mv "$LOG" "$LOG.1"
  : > "$LOG"
fi
```

- [ ] **Step 4: Make executable and run test**

```bash
chmod +x hooks/lib/log-hook-event.sh
bash tests/test-lib-log-hook-event.sh
```

Expected: All PASS, ends with "All log-hook-event tests passed."

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/log-hook-event.sh tests/test-lib-log-hook-event.sh
git commit -m "feat(hooks): add lib/log-hook-event.sh with rotation"
```

---

## Task 4: `lib/load-config.sh` — validate + source config

**Files:**
- Create: `hooks/lib/load-config.sh`
- Test: `tests/test-lib-load-config.sh`

- [ ] **Step 1: Write the failing test**

Write `tests/test-lib-load-config.sh`:

```bash
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
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-lib-load-config.sh
bash tests/test-lib-load-config.sh
```

Expected: FAIL with "No such file"

- [ ] **Step 3: Create load-config.sh**

Write `hooks/lib/load-config.sh`:

```bash
#!/usr/bin/env bash
# Loads project config with defaults fallback.
# Expects $PROJECT_ROOT and $LIB_DIR to be set by the caller.
# Source this; do not execute.

# 1. Always load defaults first
# shellcheck source=defaults.sh
source "$LIB_DIR/defaults.sh"

# 2. Load project config if present and syntactically valid
_HARNESS_CONFIG="$PROJECT_ROOT/.claude-harness/config.sh"
if [ -f "$_HARNESS_CONFIG" ]; then
  if bash -n "$_HARNESS_CONFIG" 2>/tmp/harness-syntax-err.$$; then
    # shellcheck source=/dev/null
    source "$_HARNESS_CONFIG"
  else
    err=$(cat /tmp/harness-syntax-err.$$ 2>/dev/null | tr '\n' ' ')
    "$LIB_DIR/log-hook-event.sh" load-config ERROR \
      reason=syntax-invalid \
      file="$_HARNESS_CONFIG" \
      err="$err"
    echo "[claude-harness] config.sh has syntax errors; using defaults. See progress/hooks.log" >&2
  fi
  rm -f /tmp/harness-syntax-err.$$
fi

# 3. Per-user local overrides (gitignored)
_HARNESS_LOCAL="$PROJECT_ROOT/.claude-harness/config.local.sh"
if [ -f "$_HARNESS_LOCAL" ] && bash -n "$_HARNESS_LOCAL" 2>/dev/null; then
  # shellcheck source=/dev/null
  source "$_HARNESS_LOCAL"
fi

unset _HARNESS_CONFIG _HARNESS_LOCAL
```

- [ ] **Step 4: Run test, verify it passes**

```bash
bash tests/test-lib-load-config.sh
```

Expected: All PASS, ends with "All load-config tests passed."

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/load-config.sh tests/test-lib-load-config.sh
git commit -m "feat(hooks): add lib/load-config.sh with syntax-validated config loading"
```

---

## Task 5: `lib/acquire-lock.sh` — flock wrapper

**Files:**
- Create: `hooks/lib/acquire-lock.sh`
- Test: `tests/test-lib-acquire-lock.sh`

- [ ] **Step 1: Write the failing test**

Write `tests/test-lib-acquire-lock.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"

SCRIPT="$PLUGIN_ROOT/hooks/lib/acquire-lock.sh"

# Test 1: acquires immediately when free
if ! (
  exec 9>"$TMPDIR/test.lock"
  bash "$SCRIPT" 2 9
); then
  echo "FAIL acquire: should succeed when lock is free"
  exit 1
fi
echo "PASS: acquires immediately when free"

# Test 2: times out when held
(
  exec 9>"$TMPDIR/held.lock"
  flock 9
  sleep 3
) &
holder_pid=$!
sleep 0.3

set +e
(
  exec 9>"$TMPDIR/held.lock"
  bash "$SCRIPT" 1 9
)
rc=$?
set -e

wait "$holder_pid" 2>/dev/null || true

if [ "$rc" -eq 0 ]; then
  echo "FAIL timeout: should have returned non-zero"
  exit 1
fi
echo "PASS: returns non-zero on timeout"

rm -rf "$TMPDIR"
echo "All acquire-lock tests passed."
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-lib-acquire-lock.sh
bash tests/test-lib-acquire-lock.sh
```

Expected: FAIL "No such file"

- [ ] **Step 3: Create acquire-lock.sh**

Write `hooks/lib/acquire-lock.sh`:

```bash
#!/usr/bin/env bash
# Usage:
#   exec 9>"/path/to/lockfile"
#   bash acquire-lock.sh <timeout-seconds> 9
# Returns 0 on success, non-zero on timeout.
# Caller is responsible for opening the file descriptor and releasing the lock
# (release happens automatically when the FD is closed / shell exits).

TIMEOUT="${1:-5}"
FD="${2:-9}"

flock -w "$TIMEOUT" "$FD"
```

- [ ] **Step 4: Run test, verify it passes**

```bash
chmod +x hooks/lib/acquire-lock.sh
bash tests/test-lib-acquire-lock.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/acquire-lock.sh tests/test-lib-acquire-lock.sh
git commit -m "feat(hooks): add lib/acquire-lock.sh wrapper around flock"
```

---

## Task 6: `lib/read-feature.sh` — parse feature entry

**Files:**
- Create: `hooks/lib/read-feature.sh`
- Test: `tests/test-lib-read-feature.sh`

- [ ] **Step 1: Write the failing test**

Write `tests/test-lib-read-feature.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md"
SCRIPT="$PLUGIN_ROOT/hooks/lib/read-feature.sh"

# Test 1: extract fields for existing feature
result=$("$SCRIPT" "$FIXTURE" FEAT-007)
echo "$result" | grep -q '^title=JWT Authentication$' || { echo "FAIL title: $result"; exit 1; }
echo "$result" | grep -q '^branch=feat/feat-007-jwt-authentication$' || { echo "FAIL branch: $result"; exit 1; }
echo "$result" | grep -q '^plan=docs/superpowers/plans/2026-05-04-jwt-auth.md$' || { echo "FAIL plan: $result"; exit 1; }
echo "PASS: extracts title, branch, plan for FEAT-007"

# Test 2: returns non-zero for missing feature
set +e
"$SCRIPT" "$FIXTURE" FEAT-999 >/dev/null 2>&1
rc=$?
set -e
if [ "$rc" -eq 0 ]; then
  echo "FAIL missing: should return non-zero for missing feature"
  exit 1
fi
echo "PASS: returns non-zero for missing feature"

# Test 3: feature with Branch=none returns branch=none
result=$("$SCRIPT" "$FIXTURE" FEAT-008)
echo "$result" | grep -q '^branch=none$' || { echo "FAIL branch=none: $result"; exit 1; }
echo "PASS: extracts branch=none for backlog feature"

# Test 4: malformed file (missing Branch field) returns non-zero
TMP=$(mktemp)
cat > "$TMP" <<'EOF'
## FEAT-100: Missing branch field

- **Status**: in_progress
- **Plan**: x.md
- **Verification**: x

### Subtasks
- [ ] x
EOF
set +e
"$SCRIPT" "$TMP" FEAT-100 >/dev/null 2>&1
rc=$?
set -e
rm -f "$TMP"
if [ "$rc" -eq 0 ]; then
  echo "FAIL malformed: should return non-zero when Branch field absent"
  exit 1
fi
echo "PASS: returns non-zero when Branch field absent"

echo "All read-feature tests passed."
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-lib-read-feature.sh
bash tests/test-lib-read-feature.sh
```

Expected: FAIL "No such file"

- [ ] **Step 3: Create read-feature.sh**

Write `hooks/lib/read-feature.sh`:

```bash
#!/usr/bin/env bash
# Usage: read-feature.sh <markdown-file> <FEAT-NNN>
# Emits key=value lines to stdout: title, branch, plan, verification, verified, notes
# Returns:
#   0  on success
#   1  if feature ID not found in file
#   2  if feature found but Branch: field missing

set -u

FILE="$1"
ID="$2"

awk -v id="$ID" '
  BEGIN { found=0; capturing_notes=0; notes="" }
  $0 ~ "^## "id":" {
    found=1
    sub("^## "id": *", "")
    print "title=" $0
    next
  }
  /^## FEAT-/ && found {
    if (capturing_notes && notes != "") print "notes=" notes
    exit
  }
  found && /^- \*\*Branch\*\*:/ {
    sub(/^- \*\*Branch\*\*: */, "")
    sub(/[[:space:]]*$/, "")
    print "branch=" $0
    next
  }
  found && /^- \*\*Plan\*\*:/ {
    sub(/^- \*\*Plan\*\*: */, "")
    sub(/[[:space:]]*$/, "")
    print "plan=" $0
    next
  }
  found && /^- \*\*Verification\*\*:/ {
    sub(/^- \*\*Verification\*\*: */, "")
    sub(/[[:space:]]*$/, "")
    sub(/^`/, ""); sub(/`$/, "")
    print "verification=" $0
    next
  }
  found && /^- \*\*Verified\*\*:/ {
    sub(/^- \*\*Verified\*\*: */, "")
    sub(/[[:space:]]*$/, "")
    print "verified=" $0
    next
  }
  END {
    if (!found) exit 1
  }
' "$FILE" > /tmp/read-feature.$$
rc=$?
if [ "$rc" -ne 0 ]; then
  rm -f /tmp/read-feature.$$
  exit 1
fi

if ! grep -q '^branch=' /tmp/read-feature.$$; then
  rm -f /tmp/read-feature.$$
  exit 2
fi

cat /tmp/read-feature.$$
rm -f /tmp/read-feature.$$
```

- [ ] **Step 4: Run test, verify it passes**

```bash
chmod +x hooks/lib/read-feature.sh
bash tests/test-lib-read-feature.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/read-feature.sh tests/test-lib-read-feature.sh
git commit -m "feat(hooks): add lib/read-feature.sh for feature entry parsing"
```

---

## Task 7: Project config template

**Files:**
- Create: `templates/.claude-harness/config.sh`

- [ ] **Step 1: Create template**

Write `templates/.claude-harness/config.sh`:

```bash
# claude-harness project configuration
# This file controls which hooks are active and how they behave.
# Per-user overrides go in .claude-harness/config.local.sh (gitignored).

# Formatter to run on edited files
# Values: prettier | gofmt | ruff | none
HARNESS_FORMATTER=none

# OS notification when Claude finishes responding
HARNESS_NOTIFY=true

# Automatic branch creation when a feature enters in-progress.md.
# Default false: claude-harness only suggests the command. Set true to let
# the post-edit-in-progress-watcher hook run `git switch -c` automatically.
HARNESS_AUTO_BRANCH=false

# Automatic PR open when a feature enters done.md.
# Default false: a notification is sent and you run `gh pr create` manually.
HARNESS_AUTO_PR=false

# Safety rule mode
# Values: strict | permissive (permissive logs matches but does not block)
HARNESS_SAFETY_RULES=strict

# Base branch for automatically opened PRs
HARNESS_GITHUB_BASE=main

# Per-rule safety overrides (only honored when HARNESS_SAFETY_RULES=strict)
# Set any to "true" to disable that specific rule.
HARNESS_ALLOW_RM_HOME=false
HARNESS_ALLOW_FORCE_PUSH_MAIN=false
HARNESS_ALLOW_RESET_HARD=false
HARNESS_ALLOW_CONFIG_EDIT=false

# Log rotation
HARNESS_LOG_MAX_BYTES=5242880        # 5 MB
HARNESS_LOG_ROTATIONS=3
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n templates/.claude-harness/config.sh && echo OK
```

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add templates/.claude-harness/config.sh
git commit -m "feat(templates): add .claude-harness/config.sh template"
```

---

## Task 8: `post-edit-format.sh` — auto-format edited files

**Files:**
- Create: `hooks/post-edit-format.sh`
- Test: `tests/test-hook-format.sh`

- [ ] **Step 1: Write the failing test**

Write `tests/test-hook-format.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness" "$TMPDIR/src" "$TMPDIR/features"

HOOK="$PLUGIN_ROOT/hooks/post-edit-format.sh"

# Test 1: skip files in features/
echo "junk" > "$TMPDIR/features/in-progress.md"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/in-progress.md"'"}}' | bash "$HOOK"
rc=$?
if [ "$rc" -ne 0 ]; then echo "FAIL skip features: rc=$rc"; exit 1; fi
if [ -f "$TMPDIR/progress/hooks.log" ] && grep -q "post-edit-format" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL skip features: should not log silent skip"
  exit 1
fi
echo "PASS: skips files in features/ silently"

# Test 2: HARNESS_FORMATTER=none → skip with log
echo 'HARNESS_FORMATTER=none' > "$TMPDIR/.claude-harness/config.sh"
echo "const x=1" > "$TMPDIR/src/foo.ts"
echo '{"tool_input":{"file_path":"'"$TMPDIR/src/foo.ts"'"}}' | bash "$HOOK"
if ! grep -q "SKIP.*reason=formatter-disabled" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL formatter=none: expected SKIP reason=formatter-disabled in log"
  cat "$TMPDIR/progress/hooks.log" 2>/dev/null
  exit 1
fi
echo "PASS: HARNESS_FORMATTER=none skips with log"

# Test 3: missing formatter binary → log SKIP, exit 0
echo 'HARNESS_FORMATTER=prettier' > "$TMPDIR/.claude-harness/config.sh"
echo "const x=1" > "$TMPDIR/src/foo.ts"
export PATH="/nonexistent-only"   # no prettier
echo '{"tool_input":{"file_path":"'"$TMPDIR/src/foo.ts"'"}}' | bash "$HOOK"
rc=$?
export PATH="$PATH:/usr/bin:/bin:/usr/local/bin"
if [ "$rc" -ne 0 ]; then echo "FAIL missing formatter exit: rc=$rc"; exit 1; fi
if ! grep -q "SKIP.*reason=formatter-missing" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL missing formatter log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: missing formatter degrades gracefully"

rm -rf "$TMPDIR"
echo "All post-edit-format tests passed."
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-hook-format.sh
bash tests/test-hook-format.sh
```

Expected: FAIL "No such file"

- [ ] **Step 3: Create post-edit-format.sh**

Write `hooks/post-edit-format.sh`:

```bash
#!/usr/bin/env bash
# PostToolUse hook: formats the edited file based on extension.
# Silent skip for files inside features/, progress/, .claude-harness/.
# Never blocks Claude (exit 0 always).

set -u

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

# Read JSON from stdin
INPUT=$(cat 2>/dev/null || true)
FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')

[ -z "${FILE_PATH:-}" ] && exit 0

# Silent skip for harness-managed paths
case "$FILE_PATH" in
  */features/*|*/progress/*|*/.claude-harness/*) exit 0 ;;
esac

# Load config (provides HARNESS_FORMATTER)
# shellcheck source=lib/load-config.sh
source "$LIB_DIR/load-config.sh"

LOG="$LIB_DIR/log-hook-event.sh"

if [ "$HARNESS_FORMATTER" = "none" ]; then
  "$LOG" post-edit-format SKIP reason=formatter-disabled file="$FILE_PATH"
  exit 0
fi

# Map extension → formatter command (only for configured formatter)
ext="${FILE_PATH##*.}"
case "$HARNESS_FORMATTER" in
  prettier)
    case "$ext" in
      ts|tsx|js|jsx|json|md|css|scss|html|yaml|yml) cmd="prettier --write" ;;
      *) "$LOG" post-edit-format SKIP reason=ext-not-supported file="$FILE_PATH" ext="$ext"; exit 0 ;;
    esac ;;
  gofmt)
    case "$ext" in
      go) cmd="gofmt -w" ;;
      *) "$LOG" post-edit-format SKIP reason=ext-not-supported file="$FILE_PATH" ext="$ext"; exit 0 ;;
    esac ;;
  ruff)
    case "$ext" in
      py) cmd="ruff format" ;;
      *) "$LOG" post-edit-format SKIP reason=ext-not-supported file="$FILE_PATH" ext="$ext"; exit 0 ;;
    esac ;;
  *)
    "$LOG" post-edit-format ERROR reason=unknown-formatter formatter="$HARNESS_FORMATTER"
    exit 0 ;;
esac

bin="${cmd%% *}"
if ! command -v "$bin" >/dev/null 2>&1; then
  "$LOG" post-edit-format SKIP reason=formatter-missing formatter="$HARNESS_FORMATTER"
  exit 0
fi

if $cmd "$FILE_PATH" >/dev/null 2>&1; then
  "$LOG" post-edit-format SUCCESS file="$FILE_PATH" formatter="$HARNESS_FORMATTER"
else
  "$LOG" post-edit-format ERROR file="$FILE_PATH" formatter="$HARNESS_FORMATTER"
fi

exit 0
```

- [ ] **Step 4: Run test, verify it passes**

```bash
chmod +x hooks/post-edit-format.sh
bash tests/test-hook-format.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add hooks/post-edit-format.sh tests/test-hook-format.sh
git commit -m "feat(hooks): add post-edit-format with graceful degradation"
```

---

## Task 9: `pre-tool-safety.sh` — block dangerous operations

**Files:**
- Create: `hooks/pre-tool-safety.sh`
- Test: `tests/test-hook-safety.sh`

- [ ] **Step 1: Write the failing test**

Write `tests/test-hook-safety.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness"

HOOK="$PLUGIN_ROOT/hooks/pre-tool-safety.sh"

# Test 1: blocks rm -rf $HOME
set +e
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf $HOME/foo"}}' | bash "$HOOK" 2>/tmp/safety-err
rc=$?
set -e
if [ "$rc" -ne 2 ]; then
  echo "FAIL rm -rf HOME: expected exit 2, got $rc"
  exit 1
fi
if ! grep -q "RM_HOME" /tmp/safety-err; then
  echo "FAIL rm -rf HOME: expected RM_HOME in stderr"
  cat /tmp/safety-err
  exit 1
fi
echo "PASS: blocks rm -rf \$HOME with exit 2 + rule ID"

# Test 2: blocks git push --force to main
set +e
echo '{"tool_name":"Bash","tool_input":{"command":"git push --force origin main"}}' | bash "$HOOK" 2>/dev/null
rc=$?
set -e
if [ "$rc" -ne 2 ]; then echo "FAIL force push main"; exit 1; fi
echo "PASS: blocks git push --force to main"

# Test 3: blocks edits to .claude-harness/config.sh
set +e
echo '{"tool_name":"Edit","tool_input":{"file_path":"'"$TMPDIR/.claude-harness/config.sh"'"}}' | bash "$HOOK" 2>/dev/null
rc=$?
set -e
if [ "$rc" -ne 2 ]; then echo "FAIL config edit"; exit 1; fi
echo "PASS: blocks edits to config.sh"

# Test 4: HARNESS_ALLOW_RM_HOME=true bypasses
echo 'HARNESS_ALLOW_RM_HOME=true' > "$TMPDIR/.claude-harness/config.sh"
set +e
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf $HOME/foo"}}' | bash "$HOOK" 2>/dev/null
rc=$?
set -e
if [ "$rc" -ne 0 ]; then echo "FAIL allow override: rc=$rc"; exit 1; fi
echo "PASS: HARNESS_ALLOW_RM_HOME=true bypasses block"

# Test 5: permissive mode logs but does not block
echo 'HARNESS_SAFETY_RULES=permissive' > "$TMPDIR/.claude-harness/config.sh"
set +e
echo '{"tool_name":"Bash","tool_input":{"command":"rm -rf $HOME/foo"}}' | bash "$HOOK" 2>/dev/null
rc=$?
set -e
if [ "$rc" -ne 0 ]; then echo "FAIL permissive: rc=$rc"; exit 1; fi
if ! grep -q "permissive" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL permissive: expected log entry"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: permissive mode logs but does not block"

# Test 6: safe command passes
echo 'HARNESS_SAFETY_RULES=strict' > "$TMPDIR/.claude-harness/config.sh"
echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | bash "$HOOK"
echo "PASS: safe command passes"

rm -rf "$TMPDIR"
echo "All pre-tool-safety tests passed."
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-hook-safety.sh
bash tests/test-hook-safety.sh
```

Expected: FAIL "No such file"

- [ ] **Step 3: Create pre-tool-safety.sh**

Write `hooks/pre-tool-safety.sh`:

```bash
#!/usr/bin/env bash
# PreToolUse hook: blocks dangerous operations.
# Exits with code 2 on block (stderr message fed back to Claude).
# Exits 0 on pass.

set -u

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

INPUT=$(cat 2>/dev/null || true)
TOOL_NAME=$(echo "$INPUT" | grep -oE '"tool_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"tool_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
COMMAND=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"command"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')
FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')

source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

HOOK_PATH="$CLAUDE_PLUGIN_ROOT/hooks/pre-tool-safety.sh"

emit_block() {
  local rule_id="$1" reason="$2" allow_var="HARNESS_ALLOW_$1"
  cat >&2 <<EOF
[claude-harness:pre-tool-safety] Blocked by rule $rule_id.
Reason: $reason
Escape hatches (least → most invasive):
  1. Allow this rule:    $allow_var=true in .claude-harness/config.sh
  2. Disable category:   HARNESS_SAFETY_RULES=permissive
  3. Disable hook:       chmod -x $HOOK_PATH
EOF
  "$LOG" pre-tool-safety BLOCK rule="$rule_id" tool="$TOOL_NAME"
  exit 2
}

emit_pass() {
  local rule_id="$1" mode="$2"
  "$LOG" pre-tool-safety "$mode" rule="$rule_id" tool="$TOOL_NAME"
}

check_rule() {
  local rule_id="$1" reason="$2"
  local allow_var="HARNESS_ALLOW_$rule_id"
  local allow_val="${!allow_var:-false}"

  if [ "$HARNESS_SAFETY_RULES" = "permissive" ]; then
    emit_pass "$rule_id" PASS-PERMISSIVE
    return 0
  fi
  if [ "$allow_val" = "true" ]; then
    emit_pass "$rule_id" PASS-ALLOWED
    return 0
  fi
  emit_block "$rule_id" "$reason"
}

# RM_HOME: rm -rf affecting / ~ or $HOME
if [ "$TOOL_NAME" = "Bash" ] && echo "$COMMAND" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*[[:space:]]+|-[a-zA-Z]*f[a-zA-Z]*[[:space:]]+|--recursive[[:space:]]+|--force[[:space:]]+)+(/|~|\$HOME)'; then
  check_rule RM_HOME "'rm -rf' against /, ~, or \$HOME would erase critical data."
fi

# FORCE_PUSH_MAIN
if [ "$TOOL_NAME" = "Bash" ] && echo "$COMMAND" | grep -qE 'git[[:space:]]+push[[:space:]]+.*(--force|-f)[[:space:]].*(main|master)'; then
  check_rule FORCE_PUSH_MAIN "Force-pushing to main/master overwrites shared history."
fi

# RESET_HARD
if [ "$TOOL_NAME" = "Bash" ] && echo "$COMMAND" | grep -qE 'git[[:space:]]+reset[[:space:]]+--hard\b'; then
  check_rule RESET_HARD "'git reset --hard' discards uncommitted work irreversibly."
fi

# CONFIG_EDIT
if { [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "MultiEdit" ]; } && \
   echo "$FILE_PATH" | grep -qE '\.claude-harness/config\.sh$'; then
  check_rule CONFIG_EDIT "Editing .claude-harness/config.sh changes hook behavior project-wide."
fi

exit 0
```

- [ ] **Step 4: Run test, verify it passes**

```bash
chmod +x hooks/pre-tool-safety.sh
bash tests/test-hook-safety.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add hooks/pre-tool-safety.sh tests/test-hook-safety.sh
git commit -m "feat(hooks): add pre-tool-safety blocking dangerous ops"
```

---

## Task 10: `stop-notify.sh` — OS notification with debounce

**Files:**
- Create: `hooks/stop-notify.sh`
- Test: `tests/test-hook-notify.sh`

- [ ] **Step 1: Write the failing test**

Write `tests/test-hook-notify.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export NOTIFY_TEST_MODE=1   # hook will write to $NOTIFY_TEST_FILE instead of dispatching
export NOTIFY_TEST_FILE="$TMPDIR/notify.out"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness"

HOOK="$PLUGIN_ROOT/hooks/stop-notify.sh"

# Test 1: HARNESS_NOTIFY=false → skip
echo 'HARNESS_NOTIFY=false' > "$TMPDIR/.claude-harness/config.sh"
bash "$HOOK"
if [ -f "$NOTIFY_TEST_FILE" ]; then
  echo "FAIL: should have skipped"
  exit 1
fi
echo "PASS: HARNESS_NOTIFY=false skips"

# Test 2: HARNESS_NOTIFY=true dispatches once
echo 'HARNESS_NOTIFY=true' > "$TMPDIR/.claude-harness/config.sh"
bash "$HOOK"
if [ ! -f "$NOTIFY_TEST_FILE" ]; then
  echo "FAIL: notification should have been written"
  exit 1
fi
echo "PASS: dispatches when enabled"

# Test 3: debounce within 30s
rm -f "$NOTIFY_TEST_FILE"
bash "$HOOK"
if [ -f "$NOTIFY_TEST_FILE" ]; then
  echo "FAIL: second call within 30s should be debounced"
  exit 1
fi
echo "PASS: debounces within 30s"

rm -rf "$TMPDIR"
rm -f /tmp/claude-harness-last-notify-*
echo "All stop-notify tests passed."
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-hook-notify.sh
bash tests/test-hook-notify.sh
```

Expected: FAIL "No such file"

- [ ] **Step 3: Create stop-notify.sh**

Write `hooks/stop-notify.sh`:

```bash
#!/usr/bin/env bash
# Stop hook: OS notification with 30s debounce.

set -u

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

if [ "$HARNESS_NOTIFY" != "true" ]; then
  exit 0
fi

# Debounce: hash project root, track last fire time
HASH=$(echo -n "$PROJECT_ROOT" | shasum | cut -c1-8)
STATE="/tmp/claude-harness-last-notify-$HASH"
NOW=$(date +%s)
LAST=$(cat "$STATE" 2>/dev/null || echo 0)
DELTA=$((NOW - LAST))
COUNTER_FILE="/tmp/claude-harness-counter-$HASH"

if [ "$DELTA" -lt 30 ]; then
  cur=$(cat "$COUNTER_FILE" 2>/dev/null || echo 1)
  echo $((cur + 1)) > "$COUNTER_FILE"
  "$LOG" stop-notify SKIP reason=debounce delta_s="$DELTA" queued="$(cat $COUNTER_FILE)"
  exit 0
fi

queued=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
rm -f "$COUNTER_FILE"
echo "$NOW" > "$STATE"

if [ "$queued" -gt 0 ]; then
  MSG="Claude finished. $queued event(s) queued."
else
  MSG="Claude finished. Check progress/current.md"
fi

dispatch() {
  if [ -n "${NOTIFY_TEST_MODE:-}" ]; then
    echo "$MSG" > "${NOTIFY_TEST_FILE:-/tmp/notify-test.out}"
    return 0
  fi
  case "$(uname -s)" in
    Darwin) osascript -e "display notification \"$MSG\" with title \"Claude Code\"" 2>/dev/null ;;
    Linux)  command -v notify-send >/dev/null 2>&1 && notify-send "Claude Code" "$MSG" ;;
  esac
}

dispatch
"$LOG" stop-notify SUCCESS queued="$queued"
exit 0
```

- [ ] **Step 4: Run test, verify it passes**

```bash
chmod +x hooks/stop-notify.sh
bash tests/test-hook-notify.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add hooks/stop-notify.sh tests/test-hook-notify.sh
git commit -m "feat(hooks): add stop-notify with 30s debounce + test mode"
```

---

## Task 11: `post-edit-in-progress-watcher.sh` — auto-branch on feature start

**Files:**
- Create: `hooks/post-edit-in-progress-watcher.sh`
- Test: `tests/test-hook-in-progress-watcher.sh`

- [ ] **Step 1: Write the failing test**

Write `tests/test-hook-in-progress-watcher.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness" "$TMPDIR/features"
git -C "$TMPDIR" init -q -b main
git -C "$TMPDIR" -c user.email=t@t.c -c user.name=t commit --allow-empty -qm init

HOOK="$PLUGIN_ROOT/hooks/post-edit-in-progress-watcher.sh"

# Empty in-progress.md establishes baseline snapshot
echo "" > "$TMPDIR/features/in-progress.md"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/in-progress.md"'"}}' | bash "$HOOK"

# Test 1: non-in-progress.md is ignored
echo '{"tool_input":{"file_path":"/tmp/other.md"}}' | bash "$HOOK"
echo "PASS: ignores non-in-progress.md files"

# Test 2: AUTO_BRANCH=false → log INFO with suggestion, no branch created
echo 'HARNESS_AUTO_BRANCH=false' > "$TMPDIR/.claude-harness/config.sh"
cp "$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" "$TMPDIR/features/in-progress.md"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/in-progress.md"'"}}' | bash "$HOOK"

branch=$(git -C "$TMPDIR" branch --show-current)
if [ "$branch" != "main" ]; then
  echo "FAIL: AUTO_BRANCH=false should not switch branches; on $branch"
  exit 1
fi
if ! grep -q "manual-branch-suggested" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected manual-branch-suggested log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: AUTO_BRANCH=false logs INFO, no switch"

# Reset snapshot so the next test sees the feature as new again
rm -f "$TMPDIR/progress/.in-progress.snapshot"

# Test 3: AUTO_BRANCH=true → git switch -c runs
echo 'HARNESS_AUTO_BRANCH=true' > "$TMPDIR/.claude-harness/config.sh"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/in-progress.md"'"}}' | bash "$HOOK"

branch=$(git -C "$TMPDIR" branch --show-current)
if [ "$branch" != "feat/feat-007-jwt-authentication" ]; then
  echo "FAIL: AUTO_BRANCH=true expected branch feat/feat-007-jwt-authentication; got '$branch'"
  exit 1
fi
echo "PASS: AUTO_BRANCH=true creates and switches to branch"

rm -rf "$TMPDIR"
echo "All in-progress-watcher tests passed."
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-hook-in-progress-watcher.sh
bash tests/test-hook-in-progress-watcher.sh
```

Expected: FAIL "No such file"

- [ ] **Step 3: Create post-edit-in-progress-watcher.sh**

Write `hooks/post-edit-in-progress-watcher.sh`:

```bash
#!/usr/bin/env bash
# PostToolUse hook: when features/in-progress.md gains a new feature entry,
# either create the git branch (HARNESS_AUTO_BRANCH=true) or log a suggestion.

set -u

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

INPUT=$(cat 2>/dev/null || true)
FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')

case "$FILE_PATH" in
  */features/in-progress.md) ;;
  *) exit 0 ;;
esac

source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

SNAPSHOT="$PROJECT_ROOT/progress/.in-progress.snapshot"
IP_FILE="$PROJECT_ROOT/features/in-progress.md"

# Acquire project lock
HASH=$(echo -n "$PROJECT_ROOT" | shasum | cut -c1-8)
LOCKFILE="/tmp/claude-harness-$HASH.lock"
exec 9>"$LOCKFILE"
if ! bash "$LIB_DIR/acquire-lock.sh" 5 9; then
  "$LOG" post-edit-in-progress-watcher WARNING reason=lock-timeout
  exit 0
fi

# Bootstrap: no snapshot yet → record current state, do not trigger on existing entries
if [ ! -f "$SNAPSHOT" ]; then
  grep -E '^## FEAT-[0-9]+:' "$IP_FILE" 2>/dev/null | sed -E 's/^## (FEAT-[0-9]+):.*/\1/' > "$SNAPSHOT.tmp"
  mv "$SNAPSHOT.tmp" "$SNAPSHOT"
  exit 0
fi

# Detect new entries
current_ids=$(grep -E '^## FEAT-[0-9]+:' "$IP_FILE" 2>/dev/null | sed -E 's/^## (FEAT-[0-9]+):.*/\1/' || true)
prev_ids=$(cat "$SNAPSHOT")

new_ids=$(comm -23 <(echo "$current_ids" | sort -u) <(echo "$prev_ids" | sort -u))

for feat_id in $new_ids; do
  [ -z "$feat_id" ] && continue
  parse=$(bash "$LIB_DIR/read-feature.sh" "$IP_FILE" "$feat_id" 2>/dev/null) || {
    "$LOG" post-edit-in-progress-watcher ERROR feature="$feat_id" reason=branch-field-invalid
    continue
  }
  branch=$(echo "$parse" | grep '^branch=' | cut -d= -f2-)
  if [ -z "$branch" ] || [ "$branch" = "none" ]; then
    "$LOG" post-edit-in-progress-watcher ERROR feature="$feat_id" reason=branch-missing-or-none
    continue
  fi

  if [ "$HARNESS_AUTO_BRANCH" = "true" ]; then
    if git -C "$PROJECT_ROOT" switch -c "$branch" 2>/dev/null; then
      "$LOG" post-edit-in-progress-watcher SUCCESS feature="$feat_id" branch="$branch" action=switched
    elif git -C "$PROJECT_ROOT" switch "$branch" 2>/dev/null; then
      "$LOG" post-edit-in-progress-watcher SUCCESS feature="$feat_id" branch="$branch" action=already-existed-switched
    else
      "$LOG" post-edit-in-progress-watcher ERROR feature="$feat_id" branch="$branch" reason=git-switch-failed
    fi
  else
    "$LOG" post-edit-in-progress-watcher INFO feature="$feat_id" action=manual-branch-suggested cmd="git switch -c $branch"
  fi
done

# Update snapshot atomically
echo "$current_ids" > "$SNAPSHOT.tmp"
mv "$SNAPSHOT.tmp" "$SNAPSHOT"

exit 0
```

- [ ] **Step 4: Run test, verify it passes**

```bash
chmod +x hooks/post-edit-in-progress-watcher.sh
bash tests/test-hook-in-progress-watcher.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add hooks/post-edit-in-progress-watcher.sh tests/test-hook-in-progress-watcher.sh
git commit -m "feat(hooks): add in-progress-watcher with opt-in auto-branch"
```

---

## Task 12: `post-edit-done-watcher.sh` — auto-PR when feature completes

**Files:**
- Create: `hooks/post-edit-done-watcher.sh`
- Test: `tests/test-hook-done-watcher.sh`

- [ ] **Step 1: Write the failing test**

Write `tests/test-hook-done-watcher.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness" "$TMPDIR/features"
git -C "$TMPDIR" init -q -b main
git -C "$TMPDIR" -c user.email=t@t.c -c user.name=t commit --allow-empty -qm init
git -C "$TMPDIR" checkout -q -b feat/feat-007-jwt-authentication

HOOK="$PLUGIN_ROOT/hooks/post-edit-done-watcher.sh"

# Establish baseline
echo "" > "$TMPDIR/features/done.md"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/done.md"'"}}' | bash "$HOOK"

# Test 1: non-done.md ignored
echo '{"tool_input":{"file_path":"/tmp/other.md"}}' | bash "$HOOK"
echo "PASS: ignores non-done.md files"

# Test 2: AUTO_PR=false → notification log
echo 'HARNESS_AUTO_PR=false
HARNESS_NOTIFY=false' > "$TMPDIR/.claude-harness/config.sh"
cp "$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" "$TMPDIR/features/done.md"
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/done.md"'"}}' | bash "$HOOK"
if ! grep -q "feature-ready-for-pr" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected feature-ready-for-pr log entry"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: AUTO_PR=false logs feature-ready-for-pr"

# Test 3: branch mismatch → WARNING + skip
rm -f "$TMPDIR/progress/.done.snapshot"
git -C "$TMPDIR" checkout -q main
echo '{"tool_input":{"file_path":"'"$TMPDIR/features/done.md"'"}}' | bash "$HOOK"
if ! grep -q "branch-mismatch" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected branch-mismatch log"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: branch mismatch logs WARNING"

rm -rf "$TMPDIR"
echo "All done-watcher tests passed."
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-hook-done-watcher.sh
bash tests/test-hook-done-watcher.sh
```

Expected: FAIL "No such file"

- [ ] **Step 3: Create post-edit-done-watcher.sh**

Write `hooks/post-edit-done-watcher.sh`:

```bash
#!/usr/bin/env bash
# PostToolUse hook: when features/done.md gains a new entry, either open a PR
# (HARNESS_AUTO_PR=true) or send a notification.

set -u

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

INPUT=$(cat 2>/dev/null || true)
FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')

case "$FILE_PATH" in
  */features/done.md) ;;
  *) exit 0 ;;
esac

source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

SNAPSHOT="$PROJECT_ROOT/progress/.done.snapshot"
DONE_FILE="$PROJECT_ROOT/features/done.md"

# Lock
HASH=$(echo -n "$PROJECT_ROOT" | shasum | cut -c1-8)
exec 9>"/tmp/claude-harness-$HASH.lock"
if ! bash "$LIB_DIR/acquire-lock.sh" 5 9; then
  "$LOG" post-edit-done-watcher WARNING reason=lock-timeout
  exit 0
fi

# Bootstrap snapshot if absent
if [ ! -f "$SNAPSHOT" ]; then
  grep -E '^## FEAT-[0-9]+:' "$DONE_FILE" 2>/dev/null | sed -E 's/^## (FEAT-[0-9]+):.*/\1/' > "$SNAPSHOT.tmp"
  mv "$SNAPSHOT.tmp" "$SNAPSHOT"
  exit 0
fi

current_ids=$(grep -E '^## FEAT-[0-9]+:' "$DONE_FILE" 2>/dev/null | sed -E 's/^## (FEAT-[0-9]+):.*/\1/' || true)
prev_ids=$(cat "$SNAPSHOT")
new_ids=$(comm -23 <(echo "$current_ids" | sort -u) <(echo "$prev_ids" | sort -u))

current_branch=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "")

for feat_id in $new_ids; do
  [ -z "$feat_id" ] && continue
  parse=$(bash "$LIB_DIR/read-feature.sh" "$DONE_FILE" "$feat_id" 2>/dev/null) || {
    "$LOG" post-edit-done-watcher ERROR feature="$feat_id" reason=parse-failed
    continue
  }
  branch=$(echo "$parse" | grep '^branch=' | cut -d= -f2-)

  if [ -n "$current_branch" ] && [ -n "$branch" ] && [ "$branch" != "none" ] && [ "$current_branch" != "$branch" ]; then
    "$LOG" post-edit-done-watcher WARNING reason=branch-mismatch feature="$feat_id" current="$current_branch" expected="$branch"
    continue
  fi

  if [ "$HARNESS_AUTO_PR" = "true" ]; then
    bash "$CLAUDE_PLUGIN_ROOT/scripts/harness/pr-open.sh" "$feat_id"
    "$LOG" post-edit-done-watcher SUCCESS feature="$feat_id" action=pr-open-invoked
  else
    "$LOG" post-edit-done-watcher INFO feature="$feat_id" action=feature-ready-for-pr cmd="bash scripts/harness/pr-open.sh $feat_id"
    if [ "$HARNESS_NOTIFY" = "true" ]; then
      bash "$CLAUDE_PLUGIN_ROOT/hooks/stop-notify.sh" </dev/null || true
    fi
  fi
done

echo "$current_ids" > "$SNAPSHOT.tmp"
mv "$SNAPSHOT.tmp" "$SNAPSHOT"

exit 0
```

- [ ] **Step 4: Run test, verify it passes**

```bash
chmod +x hooks/post-edit-done-watcher.sh
bash tests/test-hook-done-watcher.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add hooks/post-edit-done-watcher.sh tests/test-hook-done-watcher.sh
git commit -m "feat(hooks): add done-watcher with branch mismatch guard"
```

---

## Task 13: `scripts/harness/pr-open.sh`

**Files:**
- Create: `scripts/harness/pr-open.sh`
- Test: `tests/test-script-pr-open.sh`

- [ ] **Step 1: Write the failing test (with mocked `gh`)**

Write `tests/test-script-pr-open.sh`:

```bash
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

# Mock gh in a temp dir on PATH
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
export PATH="$MOCK_DIR:$PATH"

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

# Test: missing gh → log ERROR, exit 0
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
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-script-pr-open.sh
bash tests/test-script-pr-open.sh
```

Expected: FAIL "No such file"

- [ ] **Step 3: Create pr-open.sh**

Write `scripts/harness/pr-open.sh`:

```bash
#!/usr/bin/env bash
# Open a GitHub PR for the given feature ID.
# Reads Branch:, title, plan, verification from features/done.md.
# Idempotent: checks for existing PR first.
# Always exits 0; failures logged.

set -u

FEAT_ID="${1:-}"
if [ -z "$FEAT_ID" ]; then
  echo "Usage: pr-open.sh <FEAT-NNN>" >&2
  exit 0
fi

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

if ! command -v gh >/dev/null 2>&1; then
  "$LOG" pr-open ERROR feature="$FEAT_ID" reason=gh-not-installed remediation="install gh from https://cli.github.com"
  exit 0
fi

if ! gh auth status >/dev/null 2>&1; then
  "$LOG" pr-open ERROR feature="$FEAT_ID" reason=gh-auth-failed remediation="run: gh auth login"
  exit 0
fi

DONE="$PROJECT_ROOT/features/done.md"
parse=$(bash "$LIB_DIR/read-feature.sh" "$DONE" "$FEAT_ID" 2>/dev/null) || {
  "$LOG" pr-open ERROR feature="$FEAT_ID" reason=feature-not-found-in-done
  exit 0
}

title=$(echo "$parse" | grep '^title=' | cut -d= -f2-)
branch=$(echo "$parse" | grep '^branch=' | cut -d= -f2-)
verification=$(echo "$parse" | grep '^verification=' | cut -d= -f2-)

if [ -z "$branch" ] || [ "$branch" = "none" ]; then
  "$LOG" pr-open ERROR feature="$FEAT_ID" reason=branch-missing-or-none
  exit 0
fi

# Fork / permission check
perm=$(gh repo view --json viewerPermission 2>/dev/null | grep -oE '"viewerPermission"[[:space:]]*:[[:space:]]*"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/')
case "${perm:-}" in
  ADMIN|MAINTAIN|WRITE) ;;
  *)
    "$LOG" pr-open ERROR feature="$FEAT_ID" reason=no-write-permission perm="${perm:-unknown}" remediation="fork workflow: push to your fork and open PR from there"
    exit 0 ;;
esac

# Idempotency check
existing=$(gh pr list --head "$branch" --json number,url 2>/dev/null || echo "[]")
if echo "$existing" | grep -q '"number"'; then
  url=$(echo "$existing" | grep -oE '"url"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/')
  "$LOG" pr-open INFO feature="$FEAT_ID" reason=pr-already-exists url="$url"
  exit 0
fi

pr_title="feat($FEAT_ID): $title"
pr_body="Automated PR for $FEAT_ID.

Verification: \`$verification\`

---

_Opened by claude-harness post-edit-done-watcher._"

url=$(gh pr create --title "$pr_title" --body "$pr_body" --base "$HARNESS_GITHUB_BASE" --head "$branch" 2>/dev/null) || {
  "$LOG" pr-open ERROR feature="$FEAT_ID" reason=gh-pr-create-failed
  exit 0
}

echo "" >> "$PROJECT_ROOT/progress/history.md"
echo "$(date '+%Y-%m-%d %H:%M:%S') $FEAT_ID PR opened: $url" >> "$PROJECT_ROOT/progress/history.md"
"$LOG" pr-open SUCCESS feature="$FEAT_ID" url="$url"
exit 0
```

- [ ] **Step 4: Run test, verify it passes**

```bash
chmod +x scripts/harness/pr-open.sh
bash tests/test-script-pr-open.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/harness/pr-open.sh tests/test-script-pr-open.sh
git commit -m "feat(scripts): add pr-open.sh with idempotency and degradation"
```

---

## Task 14: `scripts/harness/pr-merge.sh`

**Files:**
- Create: `scripts/harness/pr-merge.sh`
- Test: `tests/test-script-pr-merge.sh`

- [ ] **Step 1: Write the failing test**

Write `tests/test-script-pr-merge.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness" "$TMPDIR/features"
echo "# History" > "$TMPDIR/progress/history.md"
cp "$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" "$TMPDIR/features/done.md"

SCRIPT="$PLUGIN_ROOT/scripts/harness/pr-merge.sh"
MOCK=$(mktemp -d)
export PATH="$MOCK:$PATH"

# Test 1: not approved → ERROR
cat > "$MOCK/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr list") echo '[{"number":42}]' ;;
  "pr view") echo '{"state":"OPEN","reviewDecision":"REVIEW_REQUIRED"}' ;;
  *) echo "unexpected: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$MOCK/gh"
bash "$SCRIPT" FEAT-007
if ! grep -q "pr-not-approved" "$TMPDIR/progress/hooks.log"; then
  echo "FAIL: expected pr-not-approved"
  cat "$TMPDIR/progress/hooks.log"
  exit 1
fi
echo "PASS: refuses to merge when not approved"

# Test 2: approved → merges, captures SHA, updates done.md
cat > "$MOCK/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr list") echo '[{"number":42}]' ;;
  "pr view")
    if [[ "$*" == *mergeCommit* ]]; then
      echo '{"mergeCommit":{"oid":"abc1234deadbeef"}}'
    else
      echo '{"state":"OPEN","reviewDecision":"APPROVED"}'
    fi ;;
  "pr merge") exit 0 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$MOCK/gh"
bash "$SCRIPT" FEAT-007
if ! grep -q "abc1234" "$TMPDIR/progress/history.md"; then
  echo "FAIL: merge SHA not in history"
  cat "$TMPDIR/progress/history.md"
  exit 1
fi
if ! grep -q "Merged: abc1234" "$TMPDIR/features/done.md"; then
  echo "FAIL: done.md not updated with Merged: SHA"
  cat "$TMPDIR/features/done.md"
  exit 1
fi
echo "PASS: merge updates history and done.md"

rm -rf "$TMPDIR" "$MOCK"
echo "All pr-merge tests passed."
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-script-pr-merge.sh
bash tests/test-script-pr-merge.sh
```

Expected: FAIL "No such file"

- [ ] **Step 3: Create pr-merge.sh**

Write `scripts/harness/pr-merge.sh`:

```bash
#!/usr/bin/env bash
set -u

FEAT_ID="${1:-}"
[ -z "$FEAT_ID" ] && { echo "Usage: pr-merge.sh <FEAT-NNN>" >&2; exit 0; }

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  "$LOG" pr-merge ERROR feature="$FEAT_ID" reason=gh-unavailable
  exit 0
fi

DONE="$PROJECT_ROOT/features/done.md"
parse=$(bash "$LIB_DIR/read-feature.sh" "$DONE" "$FEAT_ID" 2>/dev/null) || {
  "$LOG" pr-merge ERROR feature="$FEAT_ID" reason=feature-not-found
  exit 0
}
branch=$(echo "$parse" | grep '^branch=' | cut -d= -f2-)

pr_num=$(gh pr list --head "$branch" --json number 2>/dev/null | grep -oE '"number"[[:space:]]*:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+')
if [ -z "$pr_num" ]; then
  "$LOG" pr-merge ERROR feature="$FEAT_ID" reason=no-pr-for-branch branch="$branch"
  exit 0
fi

state_json=$(gh pr view "$pr_num" --json state,reviewDecision 2>/dev/null)
decision=$(echo "$state_json" | grep -oE '"reviewDecision"[[:space:]]*:[[:space:]]*"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/')
state=$(echo "$state_json" | grep -oE '"state"[[:space:]]*:[[:space:]]*"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/')

if [ "$state" != "OPEN" ] || [ "$decision" != "APPROVED" ]; then
  "$LOG" pr-merge ERROR feature="$FEAT_ID" reason=pr-not-approved state="$state" decision="$decision"
  exit 0
fi

if ! gh pr merge "$pr_num" --squash --delete-branch >/dev/null 2>&1; then
  "$LOG" pr-merge ERROR feature="$FEAT_ID" reason=merge-failed
  exit 0
fi

sha=$(gh pr view "$pr_num" --json mergeCommit 2>/dev/null | grep -oE '"oid"[[:space:]]*:[[:space:]]*"[a-f0-9]+"' | sed -E 's/.*"([a-f0-9]+)"$/\1/')
sha_short="${sha:0:7}"

echo "$(date '+%Y-%m-%d %H:%M:%S') $FEAT_ID merged in $sha_short" >> "$PROJECT_ROOT/progress/history.md"

# Insert "Merged: <sha>" line after the Branch: line for this feature
awk -v id="$FEAT_ID" -v sha="$sha_short" '
  $0 ~ "^## "id":" { print; in_feat=1; next }
  in_feat && /^- \*\*Branch\*\*:/ { print; print "- **Merged**: " sha; in_feat=0; next }
  /^## FEAT-/ && in_feat { in_feat=0 }
  { print }
' "$DONE" > "$DONE.tmp" && mv "$DONE.tmp" "$DONE"

"$LOG" pr-merge SUCCESS feature="$FEAT_ID" pr="$pr_num" sha="$sha_short"
exit 0
```

- [ ] **Step 4: Run test, verify it passes**

```bash
chmod +x scripts/harness/pr-merge.sh
bash tests/test-script-pr-merge.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/harness/pr-merge.sh tests/test-script-pr-merge.sh
git commit -m "feat(scripts): add pr-merge.sh with approval gating"
```

---

## Task 15: `scripts/harness/rollback-feature.sh`

**Files:**
- Create: `scripts/harness/rollback-feature.sh`
- Test: `tests/test-script-rollback.sh`

- [ ] **Step 1: Write the failing test**

Write `tests/test-script-rollback.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$TMPDIR/progress" "$TMPDIR/.claude-harness" "$TMPDIR/features"
echo "# History" > "$TMPDIR/progress/history.md"
cp "$PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" "$TMPDIR/features/done.md"
echo "" > "$TMPDIR/features/in-progress.md"

MOCK=$(mktemp -d)
export PATH="$MOCK:$PATH"
cat > "$MOCK/gh" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr list") echo '[{"number":42}]' ;;
  "pr view") echo '{"comments":[{"author":{"login":"reviewer"},"body":"Please add tests."}]}' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$MOCK/gh"

bash "$PLUGIN_ROOT/scripts/harness/rollback-feature.sh" FEAT-007

if grep -q "## FEAT-007:" "$TMPDIR/features/done.md"; then
  echo "FAIL: FEAT-007 should have been removed from done.md"
  exit 1
fi
if ! grep -q "## FEAT-007:" "$TMPDIR/features/in-progress.md"; then
  echo "FAIL: FEAT-007 should be in in-progress.md"
  cat "$TMPDIR/features/in-progress.md"
  exit 1
fi
if ! grep -q "Please add tests" "$TMPDIR/features/in-progress.md"; then
  echo "FAIL: reviewer comment should be in notes"
  cat "$TMPDIR/features/in-progress.md"
  exit 1
fi
echo "PASS: rollback moves feature + appends review comments"

rm -rf "$TMPDIR" "$MOCK"
echo "All rollback tests passed."
```

- [ ] **Step 2: Run test, verify it fails**

```bash
chmod +x tests/test-script-rollback.sh
bash tests/test-script-rollback.sh
```

Expected: FAIL "No such file"

- [ ] **Step 3: Create rollback-feature.sh**

Write `scripts/harness/rollback-feature.sh`:

```bash
#!/usr/bin/env bash
set -u

FEAT_ID="${1:-}"
[ -z "$FEAT_ID" ] && { echo "Usage: rollback-feature.sh <FEAT-NNN>" >&2; exit 0; }

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LIB_DIR="$CLAUDE_PLUGIN_ROOT/hooks/lib"
: "${PROJECT_ROOT:=$(pwd)}"
export PROJECT_ROOT LIB_DIR

source "$LIB_DIR/load-config.sh"
LOG="$LIB_DIR/log-hook-event.sh"

DONE="$PROJECT_ROOT/features/done.md"
IP="$PROJECT_ROOT/features/in-progress.md"

if ! grep -q "^## $FEAT_ID:" "$DONE"; then
  "$LOG" rollback-feature ERROR feature="$FEAT_ID" reason=not-in-done
  exit 0
fi

# Extract entry (from ## FEAT-ID: line up to but not including the next ## FEAT- or EOF)
ENTRY=$(awk -v id="$FEAT_ID" '
  $0 ~ "^## "id":" { capture=1 }
  /^## FEAT-/ && $0 !~ "^## "id":" && capture { exit }
  capture { print }
' "$DONE")

# Try to get PR comments
parse=$(bash "$LIB_DIR/read-feature.sh" "$DONE" "$FEAT_ID" 2>/dev/null || true)
branch=$(echo "$parse" | grep '^branch=' | cut -d= -f2-)
comments=""
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && [ -n "$branch" ]; then
  pr_num=$(gh pr list --head "$branch" --state all --json number 2>/dev/null | grep -oE '"number"[[:space:]]*:[[:space:]]*[0-9]+' | head -1 | grep -oE '[0-9]+')
  if [ -n "$pr_num" ]; then
    raw=$(gh pr view "$pr_num" --json comments 2>/dev/null || echo "")
    comments=$(echo "$raw" | python3 -c '
import json, sys
try:
  data = json.load(sys.stdin)
  for c in data.get("comments", []):
    author = c.get("author", {}).get("login", "?")
    print("- @" + author + ": " + c.get("body", "").replace("\n", " "))
except Exception:
  pass
' 2>/dev/null || true)
  fi
fi

# Append Notes block to entry
if [ -n "$comments" ]; then
  ENTRY="$ENTRY

### Notes
Reviewer feedback (rolled back $(date '+%Y-%m-%d')):
$comments"
fi

# Remove from done.md
awk -v id="$FEAT_ID" '
  $0 ~ "^## "id":" { skipping=1; next }
  /^## FEAT-/ && skipping && $0 !~ "^## "id":" { skipping=0 }
  !skipping { print }
' "$DONE" > "$DONE.tmp" && mv "$DONE.tmp" "$DONE"

# Append to in-progress.md
echo "" >> "$IP"
echo "$ENTRY" >> "$IP"

echo "$(date '+%Y-%m-%d %H:%M:%S') $FEAT_ID rolled back from done" >> "$PROJECT_ROOT/progress/history.md"
"$LOG" rollback-feature SUCCESS feature="$FEAT_ID"
exit 0
```

- [ ] **Step 4: Run test, verify it passes**

```bash
chmod +x scripts/harness/rollback-feature.sh
bash tests/test-script-rollback.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/harness/rollback-feature.sh tests/test-script-rollback.sh
git commit -m "feat(scripts): add rollback-feature.sh"
```

---

## Task 16: Register new hooks in `hooks.json`

**Files:**
- Modify: `hooks/hooks.json`

- [ ] **Step 1: Replace hooks.json with new registrations**

Write `hooks/hooks.json`:

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
    "PreToolUse": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-tool-safety.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/post-edit-checkpoint.sh" },
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/post-edit-format.sh" },
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/post-edit-in-progress-watcher.sh" },
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/post-edit-done-watcher.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/stop-notify.sh" }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -c "import json; json.load(open('hooks/hooks.json'))" && echo OK
```

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat(hooks): register 5 new hooks in hooks.json"
```

---

## Task 17: Update `install-into-project.sh`

**Files:**
- Modify: `scripts/install-into-project.sh`
- Test: `tests/test-install-v02.sh`

- [ ] **Step 1: Read the current install script**

```bash
cat scripts/install-into-project.sh
```

Note its structure; the new logic is appended at the end (or near the end, before the final "OK" line).

- [ ] **Step 2: Write the failing test**

Write `tests/test-install-v02.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init -q -b main

CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$PLUGIN_ROOT/scripts/install-into-project.sh" >/dev/null

# Config copied
if [ ! -f "$TMPDIR/.claude-harness/config.sh" ]; then
  echo "FAIL: .claude-harness/config.sh not copied"
  exit 1
fi
echo "PASS: config.sh copied"

# Hooks log initialized
if [ ! -f "$TMPDIR/progress/hooks.log" ]; then
  echo "FAIL: progress/hooks.log not created"
  exit 1
fi
echo "PASS: hooks.log created"

# Gitignore entries
for entry in 'progress/hooks.log' '.claude-harness/config.local.sh' 'progress/.in-progress.snapshot' 'progress/.done.snapshot'; do
  if ! grep -qF "$entry" "$TMPDIR/.gitignore" 2>/dev/null; then
    echo "FAIL: .gitignore missing '$entry'"
    cat "$TMPDIR/.gitignore" 2>/dev/null
    exit 1
  fi
done
echo "PASS: gitignore has all required entries"

# Hooks are executable
for hook in post-edit-format.sh pre-tool-safety.sh stop-notify.sh post-edit-in-progress-watcher.sh post-edit-done-watcher.sh; do
  if [ ! -x "$PLUGIN_ROOT/hooks/$hook" ]; then
    echo "FAIL: $hook not executable"
    exit 1
  fi
done
echo "PASS: all new hooks are executable"

cd /
rm -rf "$TMPDIR"
echo "All install-v02 tests passed."
```

- [ ] **Step 3: Modify `scripts/install-into-project.sh`**

Add this block before the final success/OK echo in `scripts/install-into-project.sh` (read the file first, find the end, insert):

```bash
# --- v0.2.0: project hooks layer ---

# Copy config template if absent (do not overwrite user customizations)
if [ ! -f "$PROJECT_ROOT/.claude-harness/config.sh" ]; then
  mkdir -p "$PROJECT_ROOT/.claude-harness"
  cp "$CLAUDE_PLUGIN_ROOT/templates/.claude-harness/config.sh" "$PROJECT_ROOT/.claude-harness/config.sh"

  # Detect environment and suggest formatter / gate AUTO_PR
  if [ -f "$PROJECT_ROOT/package.json" ] && grep -q '"prettier"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
    sed -i.bak 's/^HARNESS_FORMATTER=.*/HARNESS_FORMATTER=prettier/' "$PROJECT_ROOT/.claude-harness/config.sh" && rm -f "$PROJECT_ROOT/.claude-harness/config.sh.bak"
  elif [ -f "$PROJECT_ROOT/go.mod" ]; then
    sed -i.bak 's/^HARNESS_FORMATTER=.*/HARNESS_FORMATTER=gofmt/' "$PROJECT_ROOT/.claude-harness/config.sh" && rm -f "$PROJECT_ROOT/.claude-harness/config.sh.bak"
  fi

  if ! command -v gh >/dev/null 2>&1; then
    echo "[install-into-project] gh CLI not detected — HARNESS_AUTO_PR will stay disabled."
  fi
fi

# Initialize hooks log
mkdir -p "$PROJECT_ROOT/progress"
[ -f "$PROJECT_ROOT/progress/hooks.log" ] || echo "# claude-harness hooks log — see docs/workflow.md" > "$PROJECT_ROOT/progress/hooks.log"

# Ensure all new hook scripts are executable in the plugin
chmod +x "$CLAUDE_PLUGIN_ROOT/hooks/post-edit-format.sh" \
         "$CLAUDE_PLUGIN_ROOT/hooks/post-edit-in-progress-watcher.sh" \
         "$CLAUDE_PLUGIN_ROOT/hooks/post-edit-done-watcher.sh" \
         "$CLAUDE_PLUGIN_ROOT/hooks/pre-tool-safety.sh" \
         "$CLAUDE_PLUGIN_ROOT/hooks/stop-notify.sh" \
         "$CLAUDE_PLUGIN_ROOT/hooks/lib/"*.sh \
         "$CLAUDE_PLUGIN_ROOT/scripts/harness/"*.sh 2>/dev/null || true

# Append .gitignore entries (idempotent)
GI="$PROJECT_ROOT/.gitignore"
touch "$GI"
for entry in 'progress/hooks.log' 'progress/hooks.log.*' 'progress/.in-progress.snapshot' 'progress/.done.snapshot' '.claude-harness/config.local.sh'; do
  grep -qxF "$entry" "$GI" || echo "$entry" >> "$GI"
done

echo "[install-into-project] v0.2.0 hooks installed. Edit .claude-harness/config.sh to opt in to AUTO_BRANCH / AUTO_PR."
```

(Apply this with Edit, locating the appropriate insertion point in the existing script.)

- [ ] **Step 4: Run test, verify it passes**

```bash
chmod +x tests/test-install-v02.sh
bash tests/test-install-v02.sh
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/install-into-project.sh tests/test-install-v02.sh
git commit -m "feat(install): v0.2.0 project hooks layer + env detection"
```

---

## Task 18: `verify-harness-hooks` skill

**Files:**
- Create: `skills/verify-harness-hooks/SKILL.md`

- [ ] **Step 1: Create the skill**

Write `skills/verify-harness-hooks/SKILL.md`:

```markdown
---
name: verify-harness-hooks
description: Run a health check on claude-harness project hooks. Verifies hooks.json registrations, script executability, config syntax, required CLIs (gh, formatter), log state, and feature format. Use when a hook fails silently, after upgrading, or to audit a fresh install.
---

# Verify claude-harness hooks

This skill produces a table of green/yellow/red checks for the project's hooks installation.

## When to invoke

- After running `install-into-project.sh`
- When a hook seems to misbehave or silently skip
- After upgrading claude-harness
- Before enabling `HARNESS_AUTO_PR=true` or `HARNESS_AUTO_BRANCH=true`

## What to check

Run each check below. Report status per check with green (✓), yellow (warning), or red (✗). Include the remediation command for any non-green check.

### Checks

1. **hooks.json registrations**
   - `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json` exists and parses as JSON.
   - All 9 expected hooks registered: session-start, session-end, pre-compact, post-edit-checkpoint, post-edit-format, post-edit-in-progress-watcher, post-edit-done-watcher, pre-tool-safety, stop-notify.

2. **Hook scripts present + executable**
   - Verify each of the 9 hook scripts at `${CLAUDE_PLUGIN_ROOT}/hooks/` exists and has the executable bit set. Same for `${CLAUDE_PLUGIN_ROOT}/hooks/lib/*.sh` and `${CLAUDE_PLUGIN_ROOT}/scripts/harness/*.sh`.

3. **Project config**
   - `.claude-harness/config.sh` exists at project root.
   - `bash -n .claude-harness/config.sh` returns 0 (no syntax errors).
   - If syntax error: show the error and recommend `git restore` or fix manually.

4. **External CLIs (conditional)**
   - If `HARNESS_AUTO_PR=true`: `gh` installed AND `gh auth status` healthy. Otherwise: yellow if not installed.
   - If `HARNESS_FORMATTER=prettier|gofmt|ruff`: corresponding binary in PATH. Otherwise: yellow.

5. **Log state**
   - `progress/hooks.log` exists and is writable. Report size and rotation count.
   - If size approaching `HARNESS_LOG_MAX_BYTES`: yellow with rotation note.

6. **Feature format validity**
   - For each FEAT-XXX in `backlog.md`, `in-progress.md`, `done.md`: verify `Branch:` field exists. List any feature missing the field as yellow (it would break the watchers).

7. **Active safety overrides** (informational, always green)
   - List any `HARNESS_ALLOW_*=true` and `HARNESS_SAFETY_RULES` value so the user sees what's currently allowed.

## Output format

Print a markdown table:

| Check | Status | Detail / Remediation |
|---|---|---|
| hooks.json parses | ✓ | — |
| 9 hooks registered | ✓ | — |
| Hook scripts executable | ✗ | run: `chmod +x $CLAUDE_PLUGIN_ROOT/hooks/*.sh` |
| ... | ... | ... |

End with a one-line summary: `Result: 11/11 checks passed` or similar.

## Implementation notes

- Use `Bash` tool to inspect file presence and `bash -n` for syntax checks.
- Use `Read` tool on hooks.json for parsing.
- Do not modify any files — this is a read-only check.
```

- [ ] **Step 2: Commit**

```bash
git add skills/verify-harness-hooks/SKILL.md
git commit -m "feat(skills): add verify-harness-hooks health check"
```

---

## Task 19: Update `scaffolding-environment` skill

**Files:**
- Modify: `skills/scaffolding-environment/SKILL.md`

- [ ] **Step 1: Read existing skill**

```bash
cat skills/scaffolding-environment/SKILL.md
```

- [ ] **Step 2: Add a "v0.2.0 detection" section**

Add this section near the end of `skills/scaffolding-environment/SKILL.md`, before any closing remarks:

```markdown
## Detecting v0.1.0 → v0.2.0 upgrades

If `progress/` and `features/` already exist (project was scaffolded under v0.1.0) but `.claude-harness/config.sh` does NOT exist:

1. Tell the user: "claude-harness v0.2.0 introduces a project hooks layer (formatter, safety, notifications, optional PR automation). The config file `.claude-harness/config.sh` is missing. Should I create it now with safe defaults?"
2. If the user agrees: run `bash $CLAUDE_PLUGIN_ROOT/scripts/install-into-project.sh` — it is idempotent and will only add the new pieces.
3. If declined: skip silently. The new hooks behave as no-ops without config (defaults are baked-in).

Do NOT auto-create config.sh without consent — the user may be on v0.1.0 deliberately.
```

- [ ] **Step 3: Commit**

```bash
git add skills/scaffolding-environment/SKILL.md
git commit -m "docs(skills): detect v0.1.0→v0.2.0 upgrade need"
```

---

## Task 20: Documentation updates

**Files:**
- Modify: `docs/workflow.md`
- Modify: `templates/AGENTS.md`
- Create: `templates/progress/.gitignore`

- [ ] **Step 1: Add "Project hooks" section to `docs/workflow.md`**

Append to `docs/workflow.md`:

```markdown
## Project hooks (v0.2.0+)

Beyond session-level hooks, claude-harness installs a layer of per-edit and per-tool hooks that run deterministically:

- `post-edit-format` — formats edited files (`HARNESS_FORMATTER=prettier|gofmt|ruff|none`)
- `pre-tool-safety` — blocks `rm -rf $HOME`, force-pushes to main, `git reset --hard`, config edits
- `stop-notify` — OS notification when Claude finishes (30s debounce)
- `post-edit-in-progress-watcher` — when `HARNESS_AUTO_BRANCH=true`, creates the git branch as a feature enters in-progress
- `post-edit-done-watcher` — when `HARNESS_AUTO_PR=true`, opens a PR as a feature lands in done; otherwise just notifies

All behavior controlled by `.claude-harness/config.sh`. Defaults preserve v0.1.0 behavior; opt in deliberately.

### Opting in to PR automation

1. Install `gh` CLI and run `gh auth login`.
2. Set `HARNESS_AUTO_PR=true` in `.claude-harness/config.sh`.
3. Optionally set `HARNESS_AUTO_BRANCH=true` to also auto-create branches at feature start.
4. Invoke the `verify-harness-hooks` skill to confirm everything is green.
5. From now on: moving a feature to `in-progress.md` may create its branch; moving to `done.md` may open its PR.

After PR approval, run `bash scripts/harness/pr-merge.sh FEAT-NNN` to merge + cleanup. If a PR is rejected, run `bash scripts/harness/rollback-feature.sh FEAT-NNN` to move it back to in-progress with the reviewer comments attached.

### Observability

Every hook invocation that proceeds past the file-skip check logs a line to `progress/hooks.log`. Format: `[YYYY-MM-DD HH:MM:SS] hook-name EVENT_TYPE key=value...`. The file rotates at `HARNESS_LOG_MAX_BYTES` bytes; oldest rotation is gzipped.
```

- [ ] **Step 2: Update `templates/AGENTS.md`**

Append:

```markdown

## Project hooks (claude-harness v0.2.0+)

This project may have `.claude-harness/config.sh` with hook configuration. Notable rules:

- `pre-tool-safety.sh` blocks dangerous git/rm operations. If you see a `[claude-harness:pre-tool-safety] Blocked by rule X` message, do not retry blindly — read the reason and adjust.
- `HARNESS_AUTO_BRANCH=true` means moving a feature to `in-progress.md` triggers `git switch -c`. Don't manually switch first.
- `HARNESS_AUTO_PR=true` means moving a feature to `done.md` opens a PR. Make sure the work is committed and verified first.

Logs live at `progress/hooks.log`. If a hook seems to misbehave, invoke the `verify-harness-hooks` skill.
```

- [ ] **Step 3: Create `templates/progress/.gitignore`**

Write `templates/progress/.gitignore`:

```
hooks.log
hooks.log.*
.in-progress.snapshot
.done.snapshot
```

- [ ] **Step 4: Commit**

```bash
git add docs/workflow.md templates/AGENTS.md templates/progress/.gitignore
git commit -m "docs: document project hooks layer + opt-in PR automation"
```

---

## Task 21: Version bump + CHANGELOG

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Bump version in plugin.json**

Read `.claude-plugin/plugin.json`, change `"version": "0.1.0"` → `"version": "0.2.0"`.

- [ ] **Step 2: Add CHANGELOG entry**

Prepend to `CHANGELOG.md` (below the header):

```markdown
## 0.2.0 — 2026-05-11

### Added
- Project hooks layer: `post-edit-format`, `post-edit-in-progress-watcher`, `post-edit-done-watcher`, `pre-tool-safety`, `stop-notify`.
- Shared library `hooks/lib/`: `defaults.sh`, `load-config.sh`, `log-hook-event.sh`, `acquire-lock.sh`, `read-feature.sh`.
- PR automation scripts: `pr-open.sh`, `pr-merge.sh`, `rollback-feature.sh`.
- Per-project config: `.claude-harness/config.sh`.
- Health check skill: `verify-harness-hooks`.
- Structured log: `progress/hooks.log` with rotation.

### Changed
- `install-into-project.sh` now seeds `.claude-harness/config.sh`, sets executable bits, populates `.gitignore`.
- `scaffolding-environment` skill detects v0.1.0 → v0.2.0 upgrades and asks before creating config.

### Compatibility
- All defaults preserve v0.1.0 behavior. New automations (`HARNESS_AUTO_BRANCH`, `HARNESS_AUTO_PR`) are opt-in.
```

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/plugin.json CHANGELOG.md
git commit -m "chore: bump to v0.2.0 + CHANGELOG"
```

---

## Task 22: Run full test suite + integration smoke

**Files:**
- None (verification only)

- [ ] **Step 1: Run every test**

```bash
for t in tests/test-lib-*.sh tests/test-hook-*.sh tests/test-script-*.sh tests/test-install-v02.sh tests/test-parse-features.sh tests/test-checkpoint.sh tests/test-install.sh; do
  echo "=== $t ==="
  bash "$t" || { echo "FAIL: $t"; exit 1; }
done
echo "All tests passed."
```

Expected: every test prints PASS lines and "All ... tests passed." at the end; final line is "All tests passed."

- [ ] **Step 2: Manual smoke test**

```bash
SMOKE=$(mktemp -d)
cd "$SMOKE"
git init -q -b main
git -c user.email=t@t.c -c user.name=t commit --allow-empty -qm init

CLAUDE_PLUGIN_ROOT="$(cd /Users/felipevillacorte/Desktop/claude-harness && pwd)" \
  bash "$CLAUDE_PLUGIN_ROOT/scripts/install-into-project.sh"

# Verify config exists
test -f .claude-harness/config.sh && echo "OK config.sh"
test -f progress/hooks.log && echo "OK hooks.log"
grep -q 'progress/hooks.log' .gitignore && echo "OK gitignore"

# Simulate done.md write (AUTO_PR=false default → should log notification intent)
mkdir -p features
cp "$CLAUDE_PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" features/done.md
echo "" > features/done.md
echo '{"tool_input":{"file_path":"'"$SMOKE/features/done.md"'"}}' | \
  PROJECT_ROOT="$SMOKE" bash "$CLAUDE_PLUGIN_ROOT/hooks/post-edit-done-watcher.sh"
cp "$CLAUDE_PLUGIN_ROOT/tests/fixtures/feature-with-branch.md" features/done.md
echo '{"tool_input":{"file_path":"'"$SMOKE/features/done.md"'"}}' | \
  PROJECT_ROOT="$SMOKE" bash "$CLAUDE_PLUGIN_ROOT/hooks/post-edit-done-watcher.sh"

grep -q "feature-ready-for-pr" progress/hooks.log && echo "OK end-to-end log"

cd /
rm -rf "$SMOKE"
echo "Smoke test passed."
```

Expected: each `OK` line printed; final `Smoke test passed.`

- [ ] **Step 3: Final commit (only if changes made; this task usually has no diff)**

If everything passes and there are no changes to commit, skip. Otherwise:

```bash
git status
git add -A
git commit -m "chore: smoke-test fixes"
```

---

## Self-Review Notes (already applied)

- Every task has Files, TDD steps with actual code, expected outputs, and a commit.
- Type / name consistency: `HARNESS_*` vars, `hooks.log` filename, `Branch:` field, `FEAT-NNN` convention used identically across all tasks.
- Spec coverage check:
  - §1 Architecture → file structure block + Tasks 2-15
  - §2 Per-project config → Task 7
  - §3.1 post-edit-format → Task 8
  - §3.2 post-edit-in-progress-watcher → Task 11
  - §3.3 post-edit-done-watcher → Task 12
  - §3.4 pre-tool-safety → Task 9
  - §3.5 stop-notify → Task 10
  - §4.1-3 pr-open/merge/rollback → Tasks 13-15
  - §5.1-5 lib/* → Tasks 2-6
  - §6 verify-harness-hooks → Task 18
  - §7 install changes → Task 17
  - §8 migration → Task 19
  - §9 file updates → Tasks 16, 19, 20
  - All 14 acceptance criteria → covered by individual test files + Task 22 smoke test
  - All 11 risks → mitigations baked into the relevant scripts
