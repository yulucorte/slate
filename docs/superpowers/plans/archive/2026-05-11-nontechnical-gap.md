# Non-Technical Gap Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make claude-harness v0.2.0 actually useful for a non-technical user by adding visible feedback, an interactive diagnosis skill, and manual one-shot skills for branch/PR creation.

**Architecture:** Three complementary changes layered on top of the existing hook system: (1) a tiny `emit-status.sh` helper that prints to stderr (visible to the user in Claude Code) in addition to the existing `progress/hooks.log`; (2) a `scripts/harness/doctor.sh` diagnostic script wrapped by a `harness-doctor` skill that shows the user concrete fix commands for any failed check; (3) two thin skills (`harness-open-pr`, `harness-create-branch`) that let the user trigger manual actions when AUTO_* flags are false. Defaults stay safe; value becomes visible.

**Tech Stack:** Bash 5.x, `gh` CLI (conditional), `git`. No new runtime dependencies.

---

## File Structure

**New files:**

- `hooks/lib/emit-status.sh` — Helper that emits a single-line status to stderr AND appends to hooks.log. Wraps existing `log-hook-event.sh`. One responsibility: surface a user-visible message with consistent formatting.
- `scripts/harness/doctor.sh` — Standalone diagnostic that runs the same checks as `verify-harness-hooks` skill but prints each failure with the exact fix command. One responsibility: tell the user what's wrong and how to fix it.
- `skills/harness-doctor/SKILL.md` — Thin skill that invokes `doctor.sh` and explains the output.
- `skills/harness-open-pr/SKILL.md` — Thin skill that invokes existing `pr-open.sh` for a given feature.
- `skills/harness-create-branch/SKILL.md` — Thin skill that resolves a feature's `Branch:` field and runs `git switch -c`.
- `tests/test-emit-status.sh` — Test coverage for the new helper.
- `tests/test-doctor.sh` — Test coverage for doctor.sh.

**Modified files:**

- `hooks/pre-tool-safety.sh` — Replace inline stderr heredoc with `emit-status.sh` call so all hooks use the same format.
- `hooks/post-edit-in-progress-watcher.sh` — Add `emit-status.sh` calls on SUCCESS, INFO (suggestion), and ERROR paths.
- `hooks/post-edit-done-watcher.sh` — Add `emit-status.sh` calls on SUCCESS, INFO (suggestion), and ERROR paths. INFO message points the user at the new `harness-open-pr` skill.
- `.claude-plugin/plugin.json` — Bump version 0.2.0 → 0.3.0.
- `CHANGELOG.md` — Prepend v0.3.0 entry.
- `README.md` — Add the 3 new skills to the skills table.
- `docs/workflow.md` — Add a "When something looks wrong" section pointing to `harness-doctor`.
- `skills/verify-harness-hooks/SKILL.md` — Add a one-liner pointing at `harness-doctor` for users who want fix hints in addition to checks.

---

### Task 1: `emit-status.sh` helper

**Files:**
- Create: `hooks/lib/emit-status.sh`
- Test: `tests/test-emit-status.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/test-emit-status.sh`:

```bash
#!/usr/bin/env bash
# Test: emit-status.sh writes formatted line to stderr AND appends to hooks.log
set -u
TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PROJECT_ROOT="$TESTDIR"
export HARNESS_LOG_MAX_BYTES=5242880
export HARNESS_LOG_ROTATIONS=3

PASS=0
FAIL=0

assert_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
assert_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# Test 1: ok icon goes to stderr with check mark
out=$(bash "$REPO_ROOT/hooks/lib/emit-status.sh" ok test-hook "operation succeeded" 2>&1 1>/dev/null)
case "$out" in
  *"✓ harness:"*"operation succeeded"*) assert_pass "ok emits ✓ to stderr" ;;
  *) assert_fail "ok stderr was: $out" ;;
esac

# Test 2: block icon emits ✗
out=$(bash "$REPO_ROOT/hooks/lib/emit-status.sh" block test-hook "dangerous op" 2>&1 1>/dev/null)
case "$out" in
  *"✗ harness:"*"dangerous op"*) assert_pass "block emits ✗ to stderr" ;;
  *) assert_fail "block stderr was: $out" ;;
esac

# Test 3: suggest emits →
out=$(bash "$REPO_ROOT/hooks/lib/emit-status.sh" suggest test-hook "consider doing X" 2>&1 1>/dev/null)
case "$out" in
  *"→ harness:"*"consider doing X"*) assert_pass "suggest emits → to stderr" ;;
  *) assert_fail "suggest stderr was: $out" ;;
esac

# Test 4: warn emits !
out=$(bash "$REPO_ROOT/hooks/lib/emit-status.sh" warn test-hook "something off" 2>&1 1>/dev/null)
case "$out" in
  *"! harness:"*"something off"*) assert_pass "warn emits ! to stderr" ;;
  *) assert_fail "warn stderr was: $out" ;;
esac

# Test 5: also appends to hooks.log
bash "$REPO_ROOT/hooks/lib/emit-status.sh" ok test-hook "logged too" key=value 2>/dev/null
if grep -q "test-hook STATUS_OK msg=\"logged too\" key=value" "$TESTDIR/progress/hooks.log" 2>/dev/null; then
  assert_pass "ok also appended to hooks.log"
else
  assert_fail "log was: $(cat "$TESTDIR/progress/hooks.log" 2>/dev/null || echo MISSING)"
fi

# Test 6: unknown icon defaults to • (dot) and does not crash
out=$(bash "$REPO_ROOT/hooks/lib/emit-status.sh" gibberish test-hook "fallback" 2>&1 1>/dev/null)
case "$out" in
  *"• harness:"*"fallback"*) assert_pass "unknown icon falls back to •" ;;
  *) assert_fail "fallback stderr was: $out" ;;
esac

echo "---"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-emit-status.sh`
Expected: FAIL (script doesn't exist yet)

- [ ] **Step 3: Write the helper**

Create `hooks/lib/emit-status.sh`:

```bash
#!/usr/bin/env bash
# Usage: emit-status.sh <icon> <hook-name> <message> [key=value]...
# Emits a user-visible line to stderr AND logs to progress/hooks.log.
#
# Icons: ok | block | suggest | warn | (anything else → •)
# Stderr format: "<glyph> harness: <message>"
# Log format:    "[ts] <hook> STATUS_<UPPER_ICON> msg=\"...\" key=value..."

set -u

ICON="${1:-info}"
HOOK_NAME="${2:-unknown}"
MESSAGE="${3:-}"
shift 3 2>/dev/null || true

case "$ICON" in
  ok)      GLYPH="✓"; LEVEL="STATUS_OK" ;;
  block)   GLYPH="✗"; LEVEL="STATUS_BLOCK" ;;
  suggest) GLYPH="→"; LEVEL="STATUS_SUGGEST" ;;
  warn)    GLYPH="!"; LEVEL="STATUS_WARN" ;;
  *)       GLYPH="•"; LEVEL="STATUS_INFO" ;;
esac

# Stderr (user-visible)
echo "$GLYPH harness: $MESSAGE" >&2

# Log (machine-readable, includes any extra key=value pairs)
CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_SCRIPT="$CLAUDE_PLUGIN_ROOT/hooks/lib/log-hook-event.sh"
if [ -x "$LOG_SCRIPT" ] || [ -f "$LOG_SCRIPT" ]; then
  bash "$LOG_SCRIPT" "$HOOK_NAME" "$LEVEL" "msg=\"$MESSAGE\"" "$@"
fi
```

- [ ] **Step 4: Make executable, run test**

```bash
chmod +x hooks/lib/emit-status.sh
bash tests/test-emit-status.sh
```

Expected: `Results: 6 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/emit-status.sh tests/test-emit-status.sh
git commit -m "feat(hooks): add emit-status helper for user-visible stderr output"
```

---

### Task 2: Wire `emit-status.sh` into `pre-tool-safety.sh`

**Files:**
- Modify: `hooks/pre-tool-safety.sh:23-35` (the `emit_block` function)

Goal: replace the existing inline heredoc with a call to `emit-status.sh` so the safety hook uses the same format as the watchers. Keep the verbose escape-hatch hint (it's genuinely useful when blocked) but route the headline through emit-status.

- [ ] **Step 1: Update the test (add stderr-format assertion)**

Existing test for pre-tool-safety should already pass; verify by reading current test, then add one new assertion that the blocked output contains `✗ harness:`. If `tests/test-pre-tool-safety.sh` exists, append:

```bash
# Test: BLOCK emits ✗ harness: prefix
INPUT='{"tool_name":"Bash","command":"rm -rf $HOME"}'
out=$(echo "$INPUT" | bash "$REPO_ROOT/hooks/pre-tool-safety.sh" 2>&1 1>/dev/null) || true
case "$out" in
  *"✗ harness:"*) assert_pass "BLOCK output uses ✗ harness: prefix" ;;
  *) assert_fail "BLOCK stderr was: $out" ;;
esac
```

Run: `bash tests/test-pre-tool-safety.sh` — Expected: NEW assertion fails (the old heredoc emits "[claude-harness:pre-tool-safety]" not "✗ harness:").

- [ ] **Step 2: Modify `emit_block`**

In `hooks/pre-tool-safety.sh`, replace lines 23-35 with:

```bash
emit_block() {
  local rule_id="$1" reason="$2" allow_var="HARNESS_ALLOW_$1"
  bash "$LIB_DIR/emit-status.sh" block pre-tool-safety "blocked $rule_id: $reason" tool="$TOOL_NAME"
  cat >&2 <<EOF
  Override options:
    1. Allow this rule:    $allow_var=true in .claude-harness/config.sh
    2. Disable category:   HARNESS_SAFETY_RULES=permissive
    3. Disable hook:       chmod -x $HOOK_PATH
EOF
  exit 2
}
```

(The detailed override hint stays — it's load-bearing UX. Only the headline format changes.)

- [ ] **Step 3: Run the test**

Run: `bash tests/test-pre-tool-safety.sh`
Expected: all assertions pass including the new `✗ harness:` one.

- [ ] **Step 4: Commit**

```bash
git add hooks/pre-tool-safety.sh tests/test-pre-tool-safety.sh
git commit -m "feat(hooks): route safety block headline through emit-status"
```

---

### Task 3: Wire `emit-status.sh` into watcher hooks

**Files:**
- Modify: `hooks/post-edit-in-progress-watcher.sh:60-71`
- Modify: `hooks/post-edit-done-watcher.sh:53-75`
- Modify: `tests/test-in-progress-watcher.sh` (or equivalent)
- Modify: `tests/test-done-watcher.sh` (or equivalent)

Goal: when a watcher takes action (success), suggests action (info), or fails (error), the user sees it.

- [ ] **Step 1: Update in-progress-watcher tests**

Add to the existing in-progress-watcher test file a stderr assertion for each path:

```bash
# Branch created path: SUCCESS emits ✓
# (run scenario with HARNESS_AUTO_BRANCH=true, capture stderr, assert ✓ harness)
# Suggestion path: INFO emits →
# (run scenario with HARNESS_AUTO_BRANCH=false, capture stderr, assert → harness)
# Error path: ERROR emits ✗
# (run scenario with malformed feature, capture stderr, assert ✗ harness)
```

Run the existing test runner to see it fail on the new assertions.

- [ ] **Step 2: Modify `post-edit-in-progress-watcher.sh`**

Replace lines 60-71 with:

```bash
  EMIT="$LIB_DIR/emit-status.sh"

  if [ "$HARNESS_AUTO_BRANCH" = "true" ]; then
    if git -C "$PROJECT_ROOT" switch -c "$branch" 2>/dev/null; then
      bash "$EMIT" ok post-edit-in-progress-watcher "branch $branch created for $feat_id" feature="$feat_id" branch="$branch" action=switched
    elif git -C "$PROJECT_ROOT" switch "$branch" 2>/dev/null; then
      bash "$EMIT" ok post-edit-in-progress-watcher "switched to existing branch $branch for $feat_id" feature="$feat_id" branch="$branch" action=already-existed-switched
    else
      bash "$EMIT" block post-edit-in-progress-watcher "could not switch to $branch (uncommitted changes?)" feature="$feat_id" branch="$branch"
    fi
  else
    bash "$EMIT" suggest post-edit-in-progress-watcher "$feat_id ready — run: git switch -c $branch (or invoke harness-create-branch skill)" feature="$feat_id" branch="$branch" cmd="git switch -c $branch"
  fi
```

Also replace the error-path log calls (lines 52 and 57) with emit-status warn-level:

```bash
# Line 52 area
  parse=$(bash "$LIB_DIR/read-feature.sh" "$IP_FILE" "$feat_id" 2>/dev/null) || {
    bash "$LIB_DIR/emit-status.sh" warn post-edit-in-progress-watcher "feature $feat_id has invalid Branch: field" feature="$feat_id"
    continue
  }
```

```bash
# Line 57 area
  if [ -z "$branch" ] || [ "$branch" = "none" ]; then
    bash "$LIB_DIR/emit-status.sh" warn post-edit-in-progress-watcher "feature $feat_id has no Branch: field — add one to enable auto-branch" feature="$feat_id"
    continue
  fi
```

- [ ] **Step 3: Modify `post-edit-done-watcher.sh`**

Replace lines 53-75 with:

```bash
EMIT="$LIB_DIR/emit-status.sh"

for feat_id in $new_ids; do
  [ -z "$feat_id" ] && continue
  parse=$(bash "$LIB_DIR/read-feature.sh" "$DONE_FILE" "$feat_id" 2>/dev/null) || {
    bash "$EMIT" warn post-edit-done-watcher "feature $feat_id could not be parsed in done.md" feature="$feat_id"
    continue
  }
  branch=$(echo "$parse" | grep '^branch=' | cut -d= -f2-)

  if [ -n "$current_branch" ] && [ -n "$branch" ] && [ "$branch" != "none" ] && [ "$current_branch" != "$branch" ]; then
    bash "$EMIT" warn post-edit-done-watcher "$feat_id marked done but current branch is $current_branch (expected $branch); skipping" feature="$feat_id" current="$current_branch" expected="$branch"
    continue
  fi

  if [ "$HARNESS_AUTO_PR" = "true" ]; then
    if bash "$CLAUDE_PLUGIN_ROOT/scripts/harness/pr-open.sh" "$feat_id" 2>/dev/null; then
      bash "$EMIT" ok post-edit-done-watcher "PR opened for $feat_id" feature="$feat_id" action=pr-open-invoked
    else
      bash "$EMIT" warn post-edit-done-watcher "PR open failed for $feat_id — run harness-doctor to diagnose" feature="$feat_id"
    fi
  else
    bash "$EMIT" suggest post-edit-done-watcher "$feat_id ready for PR — invoke harness-open-pr skill or run: bash scripts/harness/pr-open.sh $feat_id" feature="$feat_id" cmd="bash scripts/harness/pr-open.sh $feat_id"
  fi
done
```

- [ ] **Step 4: Run tests**

```bash
bash tests/test-in-progress-watcher.sh
bash tests/test-done-watcher.sh
```

Expected: both pass including new stderr assertions.

- [ ] **Step 5: Commit**

```bash
git add hooks/post-edit-in-progress-watcher.sh hooks/post-edit-done-watcher.sh tests/test-in-progress-watcher.sh tests/test-done-watcher.sh
git commit -m "feat(hooks): emit user-visible status from watcher hooks"
```

---

### Task 4: `scripts/harness/doctor.sh`

**Files:**
- Create: `scripts/harness/doctor.sh`
- Test: `tests/test-doctor.sh`

Goal: a standalone script that runs the same checks as `verify-harness-hooks` skill, but for each failed/yellow check prints an explicit "Fix: <command>" line so a non-technical user can copy-paste.

- [ ] **Step 1: Write the failing test**

Create `tests/test-doctor.sh`:

```bash
#!/usr/bin/env bash
# Test: doctor.sh exits 0 on healthy install, prints fix hints on failures.
set -u
TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

assert_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
assert_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# Test 1: doctor.sh runs without crashing in an empty project
mkdir -p "$TESTDIR/empty"
out=$(cd "$TESTDIR/empty" && PROJECT_ROOT="$TESTDIR/empty" bash "$REPO_ROOT/scripts/harness/doctor.sh" 2>&1) || true
case "$out" in
  *"claude-harness doctor"*) assert_pass "doctor prints header" ;;
  *) assert_fail "no header in: $out" ;;
esac

# Test 2: doctor.sh detects missing .claude-harness/config.sh and prints fix
case "$out" in
  *"config.sh"*"Fix:"*"install-into-project.sh"*) assert_pass "missing config produces install fix hint" ;;
  *) assert_fail "no install hint in: $out" ;;
esac

# Test 3: with a healthy install (config exists, dirs present), doctor exits 0
mkdir -p "$TESTDIR/healthy/.claude-harness" "$TESTDIR/healthy/features" "$TESTDIR/healthy/progress"
touch "$TESTDIR/healthy/features/in-progress.md" "$TESTDIR/healthy/features/done.md" "$TESTDIR/healthy/features/backlog.md"
echo "# config" > "$TESTDIR/healthy/.claude-harness/config.sh"
PROJECT_ROOT="$TESTDIR/healthy" bash "$REPO_ROOT/scripts/harness/doctor.sh" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  assert_pass "healthy install exits 0"
else
  assert_fail "healthy install exited $rc"
fi

# Test 4: corrupt config.sh produces a "Fix:" hint
echo "this is not valid bash (((" > "$TESTDIR/healthy/.claude-harness/config.sh"
out=$(PROJECT_ROOT="$TESTDIR/healthy" bash "$REPO_ROOT/scripts/harness/doctor.sh" 2>&1) || true
case "$out" in
  *"config.sh"*"syntax"*"Fix:"*) assert_pass "corrupt config produces fix hint" ;;
  *) assert_fail "no syntax fix in: $out" ;;
esac

# Test 5: missing gh CLI WHEN HARNESS_AUTO_PR=true is reported (skip if gh installed)
if ! command -v gh >/dev/null 2>&1; then
  echo "# config" > "$TESTDIR/healthy/.claude-harness/config.sh"
  out=$(HARNESS_AUTO_PR=true PROJECT_ROOT="$TESTDIR/healthy" bash "$REPO_ROOT/scripts/harness/doctor.sh" 2>&1) || true
  case "$out" in
    *"gh CLI"*"Fix:"*"brew install gh"*) assert_pass "missing gh when AUTO_PR produces install hint" ;;
    *) assert_fail "no gh hint: $out" ;;
  esac
else
  echo "SKIP: gh CLI present, cannot test absent-gh path"
fi

echo "---"
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-doctor.sh`
Expected: FAIL (doctor.sh doesn't exist)

- [ ] **Step 3: Write `doctor.sh`**

Create `scripts/harness/doctor.sh`:

```bash
#!/usr/bin/env bash
# claude-harness doctor: diagnoses install state and prints concrete fixes.
# Exits 0 if no critical issues, 1 if a critical check fails.

set -u

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
: "${PROJECT_ROOT:=$(pwd)}"

fails=0
warns=0

header() {
  echo "claude-harness doctor — $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Project: $PROJECT_ROOT"
  echo "Plugin:  $CLAUDE_PLUGIN_ROOT"
  echo "---"
}

ok()    { echo "  ✓ $1"; }
warn()  { echo "  ! $1"; [ -n "${2:-}" ] && echo "     Fix: $2"; warns=$((warns+1)); }
fail()  { echo "  ✗ $1"; [ -n "${2:-}" ] && echo "     Fix: $2"; fails=$((fails+1)); }

check_config() {
  echo
  echo "Project config"
  if [ ! -f "$PROJECT_ROOT/.claude-harness/config.sh" ]; then
    fail "missing $PROJECT_ROOT/.claude-harness/config.sh" \
         "run: bash $CLAUDE_PLUGIN_ROOT/scripts/install-into-project.sh"
    return
  fi
  if ! bash -n "$PROJECT_ROOT/.claude-harness/config.sh" 2>/dev/null; then
    fail "config.sh has bash syntax errors" \
         "review with: bash -n $PROJECT_ROOT/.claude-harness/config.sh"
    return
  fi
  ok "config.sh exists and parses"
}

check_state_dirs() {
  echo
  echo "State directories"
  for d in features progress; do
    if [ -d "$PROJECT_ROOT/$d" ]; then
      ok "$d/ exists"
    else
      fail "$d/ directory missing" \
           "run: bash $CLAUDE_PLUGIN_ROOT/scripts/install-into-project.sh"
    fi
  done
}

check_external_clis() {
  echo
  echo "External CLIs"

  # Load config to know what's needed
  if [ -f "$PROJECT_ROOT/.claude-harness/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$PROJECT_ROOT/.claude-harness/config.sh" 2>/dev/null || true
  fi
  : "${HARNESS_AUTO_PR:=false}"
  : "${HARNESS_FORMATTER:=none}"

  # flock (always required by watcher hooks)
  if command -v flock >/dev/null 2>&1; then
    ok "flock present"
  else
    fail "flock not installed (watcher hooks need it)" \
         "macOS: brew install flock | Linux: apt-get install util-linux"
  fi

  # gh (conditional on AUTO_PR)
  if [ "$HARNESS_AUTO_PR" = "true" ]; then
    if ! command -v gh >/dev/null 2>&1; then
      fail "gh CLI not installed but HARNESS_AUTO_PR=true" \
           "macOS: brew install gh | Linux: see https://cli.github.com/"
    elif ! gh auth status >/dev/null 2>&1; then
      fail "gh CLI not authenticated" \
           "run: gh auth login"
    else
      ok "gh CLI installed and authenticated"
    fi
  else
    if command -v gh >/dev/null 2>&1; then
      ok "gh CLI present (optional — AUTO_PR=false)"
    else
      warn "gh CLI not installed (optional unless AUTO_PR=true)" \
           "skip unless you plan to use auto-PR"
    fi
  fi

  # formatter (conditional)
  case "$HARNESS_FORMATTER" in
    prettier) command -v prettier >/dev/null 2>&1 && ok "prettier present" \
                || warn "HARNESS_FORMATTER=prettier but binary missing" "npm i -g prettier" ;;
    gofmt)    command -v gofmt >/dev/null 2>&1 && ok "gofmt present" \
                || warn "HARNESS_FORMATTER=gofmt but binary missing" "install Go toolchain" ;;
    ruff)     command -v ruff >/dev/null 2>&1 && ok "ruff present" \
                || warn "HARNESS_FORMATTER=ruff but binary missing" "pip install ruff" ;;
    none|"")  ok "no formatter configured (HARNESS_FORMATTER=none)" ;;
    *)        warn "unknown HARNESS_FORMATTER=$HARNESS_FORMATTER" "set to: prettier|gofmt|ruff|none" ;;
  esac
}

check_hooks_registration() {
  echo
  echo "Plugin hooks"
  local hf="$CLAUDE_PLUGIN_ROOT/hooks/hooks.json"
  if [ ! -f "$hf" ]; then
    fail "hooks.json missing at $hf" "reinstall the plugin"
    return
  fi
  if ! grep -q '"hooks"' "$hf" 2>/dev/null; then
    fail "hooks.json doesn't contain a hooks array" "reinstall the plugin"
    return
  fi
  ok "hooks.json present"
}

check_logs() {
  echo
  echo "Log state"
  local log="$PROJECT_ROOT/progress/hooks.log"
  if [ -f "$log" ]; then
    local size; size=$(wc -c < "$log" 2>/dev/null | tr -d ' ')
    ok "hooks.log present (${size:-0} bytes)"
  else
    ok "hooks.log not yet created (no hooks have fired)"
  fi
}

summary() {
  echo
  echo "---"
  if [ "$fails" -eq 0 ] && [ "$warns" -eq 0 ]; then
    echo "Result: all checks passed."
    return 0
  fi
  echo "Result: $fails failed, $warns warnings."
  if [ "$fails" -gt 0 ]; then
    echo "Address the ✗ items above before relying on hook automation."
    return 1
  fi
  return 0
}

header
check_config
check_state_dirs
check_external_clis
check_hooks_registration
check_logs
summary
```

- [ ] **Step 4: Make executable, run test**

```bash
chmod +x scripts/harness/doctor.sh
bash tests/test-doctor.sh
```

Expected: `Results: 5 passed, 0 failed` (or 4 if gh is installed and the absent-gh test is skipped).

- [ ] **Step 5: Commit**

```bash
git add scripts/harness/doctor.sh tests/test-doctor.sh
git commit -m "feat(scripts): add doctor.sh diagnostic with fix hints"
```

---

### Task 5: Three new skills (`harness-doctor`, `harness-open-pr`, `harness-create-branch`)

**Files:**
- Create: `skills/harness-doctor/SKILL.md`
- Create: `skills/harness-open-pr/SKILL.md`
- Create: `skills/harness-create-branch/SKILL.md`

Goal: thin wrappers that the agent invokes when the user says things like "diagnose harness", "open PR for X", "create branch for Y".

- [ ] **Step 1: Create `harness-doctor` skill**

Create `skills/harness-doctor/SKILL.md`:

```markdown
---
name: harness-doctor
description: Use when the user asks to diagnose claude-harness setup, says hooks aren't working, mentions "doctor", asks "what's wrong with harness", or after install to verify everything is ready. Runs scripts/harness/doctor.sh and explains the output with prioritized fix actions.
---

# claude-harness doctor

Diagnose the project's claude-harness install and tell the user exactly what to fix.

## When to invoke

- User says: "diagnose harness", "what's wrong with harness", "is harness set up correctly?", "harness doctor"
- After running `install-into-project.sh` to verify
- When the user reports a hook misbehaving
- Before the user enables `HARNESS_AUTO_PR=true` or `HARNESS_AUTO_BRANCH=true`

## How to invoke

Run the diagnostic script and present results:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/harness/doctor.sh"
```

The script prints each check with ✓ / ! / ✗ and includes a `Fix:` line for any failure. Exit code 0 = healthy, 1 = critical issues.

## Reporting to the user

1. If exit code 0: confirm the install is healthy in one line.
2. If exit code 1: list the ✗ items first (critical), then ! items (warnings), with the suggested Fix command for each. Group by category (config / CLIs / hooks / logs).
3. Offer to walk the user through running the first Fix command. Do NOT run installation commands (e.g. `brew install`, `gh auth login`, `npm install -g`) automatically — these need user consent.
4. After the user fixes something, offer to re-run the diagnostic.

## What to avoid

- Don't run `brew install`, `gh auth login`, or `pip install` without explicit user permission.
- Don't recommend disabling safety rules unless the user asks specifically.
- Don't modify `.claude-harness/config.sh` from this skill — point the user to the file and the variable to change.
```

- [ ] **Step 2: Create `harness-open-pr` skill**

Create `skills/harness-open-pr/SKILL.md`:

```markdown
---
name: harness-open-pr
description: Use when the user asks to open a PR for a claude-harness feature, says "open PR for FEAT-X", "create a pull request for the dark-mode feature", or wants to manually trigger the PR open script when HARNESS_AUTO_PR=false. Wraps scripts/harness/pr-open.sh.
---

# Open a PR for a harness feature

Manually trigger `pr-open.sh` for a completed feature. Used when `HARNESS_AUTO_PR=false` (the default) and the user wants to open the PR explicitly.

## When to invoke

- User says: "open PR for FEAT-X", "open the dark-mode PR", "create PR for the feature I just finished"
- After a feature lands in `features/done.md` and the user wants the PR opened
- After a watcher hook printed a `→ harness: FEAT-X ready for PR` suggestion

## Preconditions to verify

1. The feature exists in `features/done.md` (not `in-progress.md`). If not, ask the user whether they want to mark it done first.
2. The current git branch matches the feature's `Branch:` field. If not, surface the mismatch and ask whether to switch first.
3. `gh` CLI installed and authenticated. If unsure, invoke the `harness-doctor` skill.

## How to invoke

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/harness/pr-open.sh" "<FEAT-ID>"
```

The script handles idempotency (if a PR already exists for the branch, it reports it and exits 0).

## Reporting to the user

- Success: print the PR URL the script outputs.
- Failure: read the recent lines of `progress/hooks.log` for the error reason, present it, and suggest `harness-doctor` if the cause is unclear.
```

- [ ] **Step 3: Create `harness-create-branch` skill**

Create `skills/harness-create-branch/SKILL.md`:

```markdown
---
name: harness-create-branch
description: Use when the user asks to create the git branch for a claude-harness feature, says "create branch for FEAT-X", "switch to the dark-mode branch", or wants to manually trigger branch creation when HARNESS_AUTO_BRANCH=false. Reads the feature's Branch field and runs git switch -c.
---

# Create a branch for a harness feature

Manually create the git branch declared in a feature's `Branch:` field. Used when `HARNESS_AUTO_BRANCH=false` (the default) and the user wants the branch explicitly.

## When to invoke

- User says: "create branch for FEAT-X", "switch to the branch for the dark-mode feature", "make the branch"
- After a feature lands in `features/in-progress.md` and the user wants the branch
- After a watcher hook printed a `→ harness: FEAT-X ready — run: git switch -c ...` suggestion

## Preconditions

1. Feature exists in `features/in-progress.md` with a `Branch:` field that is not `none`.
2. Working tree has no uncommitted changes that would block a branch switch. If dirty, ask the user whether to commit/stash first — do not silently lose work.

## How to invoke

```bash
# Parse the feature's Branch field
BRANCH=$(bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/read-feature.sh" \
  "${PROJECT_ROOT:-.}/features/in-progress.md" "<FEAT-ID>" \
  | grep '^branch=' | cut -d= -f2-)

# Create or switch
git -C "${PROJECT_ROOT:-.}" switch -c "$BRANCH" 2>/dev/null \
  || git -C "${PROJECT_ROOT:-.}" switch "$BRANCH"
```

## Reporting to the user

- Newly created: "Branch `<branch>` created and checked out."
- Already existed: "Branch `<branch>` already existed — switched to it."
- Failed: surface the git error and suggest checking working tree state.
```

- [ ] **Step 4: Commit**

```bash
git add skills/harness-doctor/SKILL.md skills/harness-open-pr/SKILL.md skills/harness-create-branch/SKILL.md
git commit -m "feat(skills): add harness-doctor, harness-open-pr, harness-create-branch"
```

---

### Task 6: Version bump + documentation

**Files:**
- Modify: `.claude-plugin/plugin.json` (version field)
- Modify: `CHANGELOG.md` (prepend v0.3.0 entry)
- Modify: `README.md` (add new skills to skills table)
- Modify: `docs/workflow.md` (add "When something looks wrong" section)
- Modify: `skills/verify-harness-hooks/SKILL.md` (cross-reference harness-doctor)

- [ ] **Step 1: Bump version**

In `.claude-plugin/plugin.json`, change:

```json
"version": "0.2.0"
```

to:

```json
"version": "0.3.0"
```

- [ ] **Step 2: Update CHANGELOG**

Prepend to `CHANGELOG.md`:

```markdown
## 0.3.0 — 2026-05-11

### Added
- `emit-status.sh` helper that surfaces hook events to stderr (visible to the user) in addition to `progress/hooks.log`.
- `scripts/harness/doctor.sh` — diagnostic script that prints concrete fix commands for failed checks.
- `harness-doctor` skill — invoke when the user asks "what's wrong with harness" or after install.
- `harness-open-pr` skill — manually trigger `pr-open.sh` when `HARNESS_AUTO_PR=false`.
- `harness-create-branch` skill — manually create the feature branch when `HARNESS_AUTO_BRANCH=false`.

### Changed
- `pre-tool-safety.sh`, `post-edit-in-progress-watcher.sh`, `post-edit-done-watcher.sh` now route status to the user via `emit-status.sh` instead of staying silent in the log.
- Watcher INFO messages (when AUTO_* is false) point users at the new skills.

```

- [ ] **Step 3: Update README skills table**

In `README.md`, locate the skills table and add three rows for `harness-doctor`, `harness-open-pr`, `harness-create-branch`. Match the existing format (name | description columns).

- [ ] **Step 4: Update `docs/workflow.md`**

Append a new section at the end:

```markdown
## When something looks wrong

If a hook seems to misbehave, or you're not sure whether your install is healthy:

- Ask Claude to "diagnose harness" or "run harness doctor" — the `harness-doctor` skill runs `scripts/harness/doctor.sh` and walks you through each fix.
- Tail the log: `tail -f progress/hooks.log`
- Check the most recent hook events: `tail -30 progress/hooks.log`

If a watcher printed `→ harness: FEAT-X ready ...` but nothing happened, that's expected when `HARNESS_AUTO_BRANCH=false` or `HARNESS_AUTO_PR=false` (defaults). Ask Claude to run the suggested skill:

- `harness-create-branch` — creates the branch for a feature in `in-progress.md`
- `harness-open-pr` — opens the PR for a feature in `done.md`
```

- [ ] **Step 5: Cross-reference in `verify-harness-hooks/SKILL.md`**

Append one line near the top (after the `## When to invoke` section):

```markdown
> **Want fix commands, not just a status table?** Invoke the `harness-doctor` skill instead — it runs the same checks plus prints `Fix:` lines.
```

- [ ] **Step 6: Verify and commit**

```bash
# Run all tests to ensure nothing regressed
for t in tests/test-*.sh; do bash "$t" || echo "FAILED: $t"; done

# Stage and commit
git add .claude-plugin/plugin.json CHANGELOG.md README.md docs/workflow.md skills/verify-harness-hooks/SKILL.md
git commit -m "chore(release): bump version to 0.3.0, update docs"
```

---

## Self-Review Checklist

After all tasks complete, the controller should verify:

1. **emit-status.sh visible in every relevant hook path** — pre-tool-safety BLOCK, in-progress-watcher SUCCESS/INFO/ERROR, done-watcher SUCCESS/INFO/ERROR.
2. **doctor.sh exits 0 on a freshly installed project** — install + immediately run doctor should be green.
3. **Skills discoverable** — `harness-doctor`, `harness-open-pr`, `harness-create-branch` descriptions contain enough trigger words ("diagnose", "open PR", "create branch", feature IDs) for the agent to pick them up.
4. **Defaults unchanged** — `HARNESS_AUTO_BRANCH=false`, `HARNESS_AUTO_PR=false`, `HARNESS_FORMATTER=none` still the bake-in defaults; this PR only adds visibility, not new automation by default.
5. **All existing tests still pass** — run `for t in tests/test-*.sh; do bash "$t"; done` and verify zero regressions.
