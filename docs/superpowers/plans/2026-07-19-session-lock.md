# Session Lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a two-layer guardian in the Slate plugin that stops two Claude Code sessions on the same repo from stepping on each other's git branch, index, or stash — detected via a shared session lock, enforced via a commit-time guardian hook, verified with a real second Claude Code session.

**Architecture:** Four new hook scripts, wired into `hooks/hooks.json` alongside the existing three (`session-start.sh`, `session-end.sh`, `pre-compact.sh`, all untouched). Layer 1 (`session-lock.sh` on SessionStart + `session-heartbeat.sh` on PostToolUse + `session-lock-cleanup.sh` on SessionEnd) detects branch collisions and auto-isolates into a `git worktree`. Layer 2 (`session-guardian.sh` on PreToolUse/Bash) blocks `git commit`/`git push` if the live branch no longer matches what this session claimed.

**Tech Stack:** bash + python3 (already a hard dependency of `session-start.sh` in this repo, safe to reuse), plain `tests/test-*.sh` scripts run by `scripts/self-test.sh` (this repo does not use bats — confirmed by grep, none installed).

## Global Constraints

- Lock directory: `$(git rev-parse --git-common-dir)/slate-sessions/` — shared across all worktrees of the same repo, lives inside `.git`, never committed. (spec: "Formato del candado")
- Heartbeat = file mtime of the lock file, not a JSON field. TTL = **900 seconds (15 min)**; older locks are ignored as dead, never actively deleted by the reaper. (spec: "Gotcha 2")
- Worktree path: `"$(dirname "$PROJECT_ROOT")/$(basename "$PROJECT_ROOT").slate-worktrees/<8-char session id>"` — always a sibling of the project directory, derived at runtime, never hardcoded to a specific repo. (spec: "Gotcha 4")
- New branch for an isolated session: `slate-session/<8-char session id>`. git itself refuses to check out the same branch in two worktrees, which is what guarantees "never share the active branch."
- Every hook exits 0 on any unexpected error (non-git dir, malformed JSON, `git worktree add` failure) — never blocks a session from starting. The ONE intentional exception is `session-guardian.sh` denying a commit/push on a real branch mismatch.
- `session-lock-cleanup.sh` deletes ONLY this session's lock file. It must never delete a worktree or branch (Felipe's explicit choice: leave them for manual review/merge/delete).
- Do not modify `hooks/session-start.sh`, `hooks/session-end.sh`, `hooks/pre-compact.sh`, or any `skills/*`. Only add new files + new entries in `hooks/hooks.json`.
- `git add` by explicit path only, never `-A`, never a direct commit to `main` — all work happens on `feat/feat-001-session-lock`.

---

### Task 1: `session-lock.sh` — claim path (no collision)

**Files:**
- Create: `hooks/session-lock.sh`
- Test: `tests/test-session-lock.sh`

**Interfaces:**
- Produces: lock file at `<git-common-dir>/slate-sessions/<session_id>.lock`, JSON shape `{"branch": "<name>", "worktree": "<path-or-empty>", "started_at": "<iso8601>"}`. Later tasks (heartbeat, guardian, cleanup) read/touch this exact path and shape.

- [ ] **Step 1: Write the failing test (claim path + different-branch-no-collision case)**

Create `tests/test-session-lock.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-lock.sh"

setup_repo() {
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" config user.email "t@t.com"
  git -C "$dir" config user.name "t"
  git -C "$dir" commit --allow-empty -q -m init
  echo "$dir"
}

# --- Test: no existing locks -> claims current branch, no additionalContext ---
REPO=$(setup_repo)
OUTPUT=$(echo '{"session_id":"sess-aaa"}' | CLAUDE_PROJECT_ROOT="$REPO" bash "$HOOK")
LOCK_FILE="$REPO/.git/slate-sessions/sess-aaa.lock"

[ -f "$LOCK_FILE" ] || { echo "FAIL: lock file not created. Got output: $OUTPUT"; exit 1; }
grep -q '"branch": "master"' "$LOCK_FILE" 2>/dev/null || grep -q '"branch": "main"' "$LOCK_FILE" \
  || { echo "FAIL: lock does not record current branch. Content: $(cat "$LOCK_FILE")"; exit 1; }
if printf '%s' "$OUTPUT" | grep -q additionalContext; then
  echo "FAIL: unexpected additionalContext on no-collision path: $OUTPUT"; exit 1
fi
echo "PASS: no-collision claim produced no additionalContext"
echo "PASS: lock file created with current branch"
rm -rf "$REPO"

# --- Test: existing lock on a DIFFERENT branch -> no collision, own claim proceeds ---
REPO=$(setup_repo)
BR=$(git -C "$REPO" branch --show-current)
git -C "$REPO" checkout -qb other-branch
git -C "$REPO" checkout -q "$BR"
mkdir -p "$REPO/.git/slate-sessions"
cat > "$REPO/.git/slate-sessions/sess-other.lock" <<EOF
{"branch": "other-branch", "worktree": "", "started_at": "2026-01-01T00:00:00Z"}
EOF

OUTPUT2=$(echo '{"session_id":"sess-bbb"}' | CLAUDE_PROJECT_ROOT="$REPO" bash "$HOOK")
[ -f "$REPO/.git/slate-sessions/sess-bbb.lock" ] || { echo "FAIL: own lock not created despite different-branch lock present"; exit 1; }
grep -q "\"branch\": \"$BR\"" "$REPO/.git/slate-sessions/sess-bbb.lock" \
  || { echo "FAIL: claimed wrong branch. Content: $(cat "$REPO/.git/slate-sessions/sess-bbb.lock")"; exit 1; }
echo "PASS: different-branch lock does not trigger collision"
rm -rf "$REPO"

echo ""
echo "All session-lock claim-path tests passed."
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-session-lock.sh`
Expected: FAIL (`hooks/session-lock.sh` does not exist yet — `bash: hooks/session-lock.sh: No such file or directory` or similar).

- [ ] **Step 3: Write minimal implementation**

Create `hooks/session-lock.sh`:

```bash
#!/usr/bin/env bash
# SessionStart hook: session-lock guardian, layer 1.
# Detects if another LIVE session already claims this branch; if so,
# isolates this session into a dedicated git worktree + branch.
# Never blocks a session start — always exits 0.
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"
cd "$PROJECT_ROOT" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)"
[ -z "$GIT_COMMON_DIR" ] && exit 0
case "$GIT_COMMON_DIR" in
  /*) : ;;
  *) GIT_COMMON_DIR="$PROJECT_ROOT/$GIT_COMMON_DIR" ;;
esac

LOCK_DIR="$GIT_COMMON_DIR/slate-sessions"
mkdir -p "$LOCK_DIR" 2>/dev/null || exit 0

STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON=$(cat 2>/dev/null || true)
fi
SESSION_ID=$(printf '%s' "$STDIN_JSON" | python3 -c "import sys,json
try:
    print((json.load(sys.stdin).get('session_id') or '').strip())
except Exception:
    print('')" 2>/dev/null || true)
[ -z "$SESSION_ID" ] && exit 0

CURRENT_BRANCH="$(git branch --show-current 2>/dev/null)"
[ -z "$CURRENT_BRANCH" ] && exit 0   # detached HEAD: nothing to protect

TTL_SECONDS=900
NOW=$(date +%s)

COLLISION=0
for lock in "$LOCK_DIR"/*.lock; do
  [ -e "$lock" ] || continue
  LOCK_SESSION_ID="$(basename "$lock" .lock)"
  [ "$LOCK_SESSION_ID" = "$SESSION_ID" ] && continue

  MTIME=$(stat -f %m "$lock" 2>/dev/null || stat -c %Y "$lock" 2>/dev/null || echo 0)
  AGE=$((NOW - MTIME))
  [ "$AGE" -gt "$TTL_SECONDS" ] && continue   # stale, ignore

  LOCK_BRANCH=$(python3 -c "import json
try:
    print(json.load(open('$lock')).get('branch',''))
except Exception:
    print('')" 2>/dev/null || true)

  if [ "$LOCK_BRANCH" = "$CURRENT_BRANCH" ]; then
    COLLISION=1
    break
  fi
done

CONTEXT=""
LOCK_BRANCH_OUT="$CURRENT_BRANCH"
WT_OUT=""

if [ "$COLLISION" -eq 1 ]; then
  # Handled in Task 3.
  :
fi

python3 -c "import json,sys
data = {'branch': sys.argv[1], 'worktree': sys.argv[2], 'started_at': sys.argv[3]}
json.dump(data, open(sys.argv[4], 'w'))
" "$LOCK_BRANCH_OUT" "$WT_OUT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$LOCK_DIR/$SESSION_ID.lock" 2>/dev/null || true

if [ -n "$CONTEXT" ]; then
  CONTEXT_JSON=$(printf '%s' "$CONTEXT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null \
    || printf '"%s"' "$(printf '%s' "$CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')")
  printf '{"additionalContext": %s}\n' "$CONTEXT_JSON"
fi
exit 0
```

Make it executable: `chmod +x hooks/session-lock.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-session-lock.sh`
Expected: `All session-lock claim-path tests passed.`

- [ ] **Step 5: Commit**

```bash
git add hooks/session-lock.sh tests/test-session-lock.sh
git commit -m "feat: session-lock claim path (FEAT-001.1)"
```

---

### Task 2: `session-lock.sh` — stale lock reaping

**Files:**
- Modify: `hooks/session-lock.sh` (no structural change needed — behavior already implemented in Task 1's loop; this task adds the test proving it and hardens the TTL branch)
- Test: `tests/test-session-lock.sh` (append)

**Interfaces:**
- Consumes: `TTL_SECONDS=900` constant from Task 1.
- Produces: nothing new — confirms existing behavior.

- [ ] **Step 1: Write the failing test (stale lock ignored)**

Append to `tests/test-session-lock.sh` (before the final `echo "All session-lock claim-path tests passed."` line, replace that closing echo and add this block first):

```bash
# --- Test: existing SAME-branch lock but STALE (mtime > 900s old) -> ignored ---
REPO=$(setup_repo)
BR=$(git -C "$REPO" branch --show-current)
mkdir -p "$REPO/.git/slate-sessions"
cat > "$REPO/.git/slate-sessions/sess-stale.lock" <<EOF
{"branch": "$BR", "worktree": "", "started_at": "2020-01-01T00:00:00Z"}
EOF
python3 -c "import os,time; p='$REPO/.git/slate-sessions/sess-stale.lock'; t=time.time()-1000; os.utime(p,(t,t))"

OUTPUT3=$(echo '{"session_id":"sess-fresh"}' | CLAUDE_PROJECT_ROOT="$REPO" bash "$HOOK")
echo "$OUTPUT3" | grep -q additionalContext && { echo "FAIL: stale lock triggered isolation. Output: $OUTPUT3"; exit 1; }
[ -f "$REPO/.git/slate-sessions/sess-fresh.lock" ] || { echo "FAIL: own lock not created"; exit 1; }
[ -d "$REPO.slate-worktrees" ] && { echo "FAIL: worktree created despite stale lock"; exit 1; }
echo "PASS: stale lock (>900s) is ignored, no isolation triggered"
rm -rf "$REPO" "$REPO.slate-worktrees" 2>/dev/null

echo ""
echo "All session-lock claim-path tests passed."
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-session-lock.sh`
Expected: at this point it should actually PASS already, because Task 1's TTL-skip logic (`[ "$AGE" -gt "$TTL_SECONDS" ] && continue`) already exists. Confirm by running — if it passes, that's expected (this task exists to lock the behavior in with an explicit regression test, not to add new code). Note this in the commit message rather than forcing an artificial failure.

- [ ] **Step 3: No implementation change needed**

Nothing to implement — Task 1 already wrote the TTL check. Skip to verification.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-session-lock.sh`
Expected: `All session-lock claim-path tests passed.`

- [ ] **Step 5: Commit**

```bash
git add tests/test-session-lock.sh
git commit -m "test: lock TTL reaping regression test (FEAT-001.2)"
```

---

### Task 3: `session-lock.sh` — collision → worktree isolation

**Files:**
- Modify: `hooks/session-lock.sh`
- Test: `tests/test-session-lock.sh` (append), create `tests/test-session-lock-worktree-visibility.sh`

**Interfaces:**
- Produces: on collision, a real `git worktree` at `"$(dirname "$PROJECT_ROOT")/$(basename "$PROJECT_ROOT").slate-worktrees/<8-char session id>"` on branch `slate-session/<8-char session id>`, plus `additionalContext` in the JSON stdout containing the worktree path and branch name.

- [ ] **Step 1: Write the failing test (real collision -> real worktree)**

Append to `tests/test-session-lock.sh`, replacing the final `echo "All session-lock claim-path tests passed."` with:

```bash
# --- Test: existing SAME-branch FRESH lock -> real collision, isolates into worktree ---
REPO=$(setup_repo)
BR=$(git -C "$REPO" branch --show-current)
mkdir -p "$REPO/.git/slate-sessions"
cat > "$REPO/.git/slate-sessions/sess-live.lock" <<EOF
{"branch": "$BR", "worktree": "", "started_at": "2026-01-01T00:00:00Z"}
EOF

OUTPUT4=$(echo '{"session_id":"sess-colliding"}' | CLAUDE_PROJECT_ROOT="$REPO" bash "$HOOK")
echo "$OUTPUT4" | grep -q additionalContext || { echo "FAIL: no additionalContext on real collision. Output: $OUTPUT4"; exit 1; }
echo "$OUTPUT4" | grep -q "slate-session/sess-col" || { echo "FAIL: additionalContext missing new branch name. Output: $OUTPUT4"; exit 1; }

REPO_PARENT="$(dirname "$REPO")"
REPO_BASE="$(basename "$REPO")"
WT_PATH="${REPO_PARENT}/${REPO_BASE}.slate-worktrees/sess-col"
[ -d "$WT_PATH" ] || { echo "FAIL: worktree directory not created at $WT_PATH"; exit 1; }
WT_BRANCH=$(git -C "$WT_PATH" branch --show-current)
[ "$WT_BRANCH" = "slate-session/sess-col" ] || { echo "FAIL: worktree is on wrong branch: $WT_BRANCH"; exit 1; }

LOCK_FILE="$REPO/.git/slate-sessions/sess-colliding.lock"
grep -q "slate-session/sess-col" "$LOCK_FILE" || { echo "FAIL: colliding session's own lock does not record isolated branch"; exit 1; }
echo "PASS: real branch collision creates isolated worktree on a new branch"

git -C "$REPO" worktree remove --force "$WT_PATH" 2>/dev/null || true
rm -rf "$REPO" "${REPO_PARENT}/${REPO_BASE}.slate-worktrees" 2>/dev/null

echo ""
echo "All session-lock tests passed."
```

Note: `${SESSION_ID:0:8}` of `sess-colliding` is `sess-col` (8 chars) — the test above already uses that exact 8-char prefix throughout, no substitution needed when copying this block verbatim.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-session-lock.sh`
Expected: FAIL on the new collision block — no `additionalContext` produced yet, because Task 1 left the `if [ "$COLLISION" -eq 1 ]; then :; fi` branch as a no-op.

- [ ] **Step 3: Write minimal implementation**

In `hooks/session-lock.sh`, replace the placeholder block:

```bash
if [ "$COLLISION" -eq 1 ]; then
  # Handled in Task 3.
  :
fi
```

with:

```bash
if [ "$COLLISION" -eq 1 ]; then
  SHORT_ID="${SESSION_ID:0:8}"
  NEW_BRANCH="slate-session/${SHORT_ID}"
  PARENT_DIR="$(dirname "$PROJECT_ROOT")"
  BASE_NAME="$(basename "$PROJECT_ROOT")"
  WT_PATH="${PARENT_DIR}/${BASE_NAME}.slate-worktrees/${SHORT_ID}"

  mkdir -p "$(dirname "$WT_PATH")" 2>/dev/null
  if git worktree add "$WT_PATH" -b "$NEW_BRANCH" "$CURRENT_BRANCH" >/dev/null 2>&1; then
    LOCK_BRANCH_OUT="$NEW_BRANCH"
    WT_OUT="$WT_PATH"
    CONTEXT="Otra sesion de Claude Code ya esta activa en la rama '${CURRENT_BRANCH}' de este repo. Para no pisarle la rama, el indice de git, ni el stash, esta sesion quedo aislada en una copia separada del repo:

  ${WT_PATH}  (rama: ${NEW_BRANCH})

A partir de ahora, para CUALQUIER comando git (branch, commit, push, stash, etc.) usa esa carpeta: cd ${WT_PATH} && git ... No operes sobre ${PROJECT_ROOT} hasta que la otra sesion termine."
  else
    CONTEXT="AVISO: otra sesion ya esta activa en la rama '${CURRENT_BRANCH}' y no pude aislar esta sesion en un worktree separado (fallo 'git worktree add'). Tene cuidado: pueden pisarse la rama, el indice o el stash."
  fi
fi
```

(`LOCK_BRANCH_OUT` and `WT_OUT` already default to `$CURRENT_BRANCH` / `""` from Task 1, so the `git worktree add` failure path falls through correctly without extra assignment.)

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-session-lock.sh`
Expected: `All session-lock tests passed.`

- [ ] **Step 5: Write and run the cross-worktree visibility test**

Create `tests/test-session-lock-worktree-visibility.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-lock.sh"

REPO=$(mktemp -d)
git -C "$REPO" init -q
git -C "$REPO" config user.email "t@t.com"
git -C "$REPO" config user.name "t"
git -C "$REPO" commit --allow-empty -q -m init

# Session A runs in the main checkout, claims its branch.
echo '{"session_id":"sess-A"}' | CLAUDE_PROJECT_ROOT="$REPO" bash "$HOOK" >/dev/null

# Add a second, independent worktree by hand (simulates a second checkout
# of the same repo that a second Claude Code session could be pointed at).
WT2="$(mktemp -d)/wt2"
git -C "$REPO" worktree add -q "$WT2" -b manual-second-checkout >/dev/null

# From worktree B, the shared lock directory must resolve to the SAME path
# as from the main checkout, and session A's lock file must be visible there.
COMMON_A="$(git -C "$REPO" rev-parse --git-common-dir)"
case "$COMMON_A" in /*) : ;; *) COMMON_A="$REPO/$COMMON_A" ;; esac
COMMON_B="$(git -C "$WT2" rev-parse --git-common-dir)"
case "$COMMON_B" in /*) : ;; *) COMMON_B="$WT2/$COMMON_B" ;; esac

[ "$COMMON_A" = "$COMMON_B" ] || { echo "FAIL: git-common-dir differs between checkouts: $COMMON_A vs $COMMON_B"; exit 1; }
[ -f "$COMMON_B/slate-sessions/sess-A.lock" ] || { echo "FAIL: session A's lock not visible from worktree B at $COMMON_B/slate-sessions/"; exit 1; }
echo "PASS: lock directory is shared and visible across worktrees of the same repo"

git -C "$REPO" worktree remove --force "$WT2" 2>/dev/null || true
rm -rf "$REPO" "$(dirname "$WT2")" 2>/dev/null

echo ""
echo "All session-lock worktree-visibility tests passed."
```

Run: `bash tests/test-session-lock-worktree-visibility.sh`
Expected: `All session-lock worktree-visibility tests passed.`

- [ ] **Step 6: Commit**

```bash
git add hooks/session-lock.sh tests/test-session-lock.sh tests/test-session-lock-worktree-visibility.sh
git commit -m "feat: session-lock isolates colliding sessions into a worktree (FEAT-001.3)"
```

---

### Task 4: `session-heartbeat.sh`

**Files:**
- Create: `hooks/session-heartbeat.sh`
- Test: `tests/test-session-heartbeat.sh`

**Interfaces:**
- Consumes: lock file path convention from Task 1 (`<git-common-dir>/slate-sessions/<session_id>.lock`).
- Produces: refreshed mtime on that file. Nothing else reads this script's output.

- [ ] **Step 1: Write the failing test**

Create `tests/test-session-heartbeat.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-heartbeat.sh"

REPO=$(mktemp -d)
git -C "$REPO" init -q
git -C "$REPO" config user.email "t@t.com"
git -C "$REPO" config user.name "t"
git -C "$REPO" commit --allow-empty -q -m init

mkdir -p "$REPO/.git/slate-sessions"
LOCK="$REPO/.git/slate-sessions/sess-hb.lock"
echo '{"branch": "main", "worktree": "", "started_at": "2020-01-01T00:00:00Z"}' > "$LOCK"
python3 -c "import os,time; t=time.time()-1000; os.utime('$LOCK',(t,t))"
OLD_MTIME=$(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK")

echo '{"session_id":"sess-hb"}' | CLAUDE_PROJECT_ROOT="$REPO" bash "$HOOK"
NEW_MTIME=$(stat -f %m "$LOCK" 2>/dev/null || stat -c %Y "$LOCK")

[ "$NEW_MTIME" -gt "$OLD_MTIME" ] || { echo "FAIL: lock mtime not refreshed ($OLD_MTIME -> $NEW_MTIME)"; exit 1; }
echo "PASS: heartbeat refreshes lock mtime for an existing lock"

# --- Test: no lock file for this session -> no error, no file created ---
echo '{"session_id":"sess-none"}' | CLAUDE_PROJECT_ROOT="$REPO" bash "$HOOK"
[ -f "$REPO/.git/slate-sessions/sess-none.lock" ] && { echo "FAIL: heartbeat created a lock file it shouldn't have"; exit 1; }
echo "PASS: heartbeat is a no-op when this session has no lock"

rm -rf "$REPO"
echo ""
echo "All session-heartbeat tests passed."
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-session-heartbeat.sh`
Expected: FAIL (`hooks/session-heartbeat.sh` does not exist).

- [ ] **Step 3: Write minimal implementation**

Create `hooks/session-heartbeat.sh`:

```bash
#!/usr/bin/env bash
# PostToolUse hook (all tools): session-lock guardian, heartbeat refresh.
# Touches this session's lock file so it isn't reaped as stale. Strictly
# passive — PostToolUse cannot block anything, and this script never tries.
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"
cd "$PROJECT_ROOT" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)"
[ -z "$GIT_COMMON_DIR" ] && exit 0
case "$GIT_COMMON_DIR" in
  /*) : ;;
  *) GIT_COMMON_DIR="$PROJECT_ROOT/$GIT_COMMON_DIR" ;;
esac

STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON=$(cat 2>/dev/null || true)
fi
SESSION_ID=$(printf '%s' "$STDIN_JSON" | python3 -c "import sys,json
try:
    print((json.load(sys.stdin).get('session_id') or '').strip())
except Exception:
    print('')" 2>/dev/null || true)
[ -z "$SESSION_ID" ] && exit 0

LOCK_FILE="$GIT_COMMON_DIR/slate-sessions/$SESSION_ID.lock"
[ -f "$LOCK_FILE" ] && touch "$LOCK_FILE" 2>/dev/null
exit 0
```

Make it executable: `chmod +x hooks/session-heartbeat.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-session-heartbeat.sh`
Expected: `All session-heartbeat tests passed.`

- [ ] **Step 5: Commit**

```bash
git add hooks/session-heartbeat.sh tests/test-session-heartbeat.sh
git commit -m "feat: session-heartbeat refreshes the session lock (FEAT-001.4)"
```

---

### Task 5: `session-guardian.sh`

**Files:**
- Create: `hooks/session-guardian.sh`
- Test: `tests/test-session-guardian.sh`

**Interfaces:**
- Consumes: lock file shape from Task 1 (`{"branch": ...}`).
- Produces: `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "<text>"}}` on stdout when blocking; empty stdout otherwise. This is a terminal consumer — nothing downstream reads its output.

- [ ] **Step 1: Write the failing test**

Create `tests/test-session-guardian.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-guardian.sh"

setup_repo() {
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" config user.email "t@t.com"
  git -C "$dir" config user.name "t"
  git -C "$dir" commit --allow-empty -q -m init
  echo "$dir"
}

payload() {
  # $1=session_id $2=cwd $3=command
  python3 -c "import json,sys; print(json.dumps({'session_id': sys.argv[1], 'cwd': sys.argv[2], 'tool_input': {'command': sys.argv[3]}}))" "$1" "$2" "$3"
}

# --- Test: branch matches lock -> commit allowed (no deny output) ---
REPO=$(setup_repo)
BR=$(git -C "$REPO" branch --show-current)
mkdir -p "$REPO/.git/slate-sessions"
echo "{\"branch\": \"$BR\", \"worktree\": \"\", \"started_at\": \"2026-01-01T00:00:00Z\"}" > "$REPO/.git/slate-sessions/sess-ok.lock"

OUT1=$(payload "sess-ok" "$REPO" "git commit -m test" | bash "$HOOK")
echo "$OUT1" | grep -q '"permissionDecision": "deny"' && { echo "FAIL: matching branch was denied. Output: $OUT1"; exit 1; }
echo "PASS: commit allowed when branch matches lock"

# --- Test: branch does NOT match lock -> commit denied ---
git -C "$REPO" checkout -qb other-branch
OUT2=$(payload "sess-ok" "$REPO" "git commit -m test" | bash "$HOOK")
echo "$OUT2" | grep -q '"permissionDecision": "deny"' || { echo "FAIL: mismatched branch was NOT denied. Output: $OUT2"; exit 1; }
echo "PASS: commit denied when active branch no longer matches the session's lock"

# --- Test: unrelated command -> hook is a no-op, no output ---
OUT3=$(payload "sess-ok" "$REPO" "git status" | bash "$HOOK")
[ -z "$OUT3" ] || { echo "FAIL: unrelated command produced output: $OUT3"; exit 1; }
echo "PASS: unrelated bash command produces no output"

# --- Test: git push also guarded ---
OUT4=$(payload "sess-ok" "$REPO" "git push origin other-branch" | bash "$HOOK")
echo "$OUT4" | grep -q '"permissionDecision": "deny"' || { echo "FAIL: mismatched-branch push was NOT denied. Output: $OUT4"; exit 1; }
echo "PASS: push is guarded the same way as commit"

# --- Test: no lock for this session -> nothing to guard, allowed ---
OUT5=$(payload "sess-unknown" "$REPO" "git commit -m test" | bash "$HOOK")
echo "$OUT5" | grep -q '"permissionDecision": "deny"' && { echo "FAIL: session with no lock was denied. Output: $OUT5"; exit 1; }
echo "PASS: session with no recorded claim is not blocked"

rm -rf "$REPO"
echo ""
echo "All session-guardian tests passed."
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-session-guardian.sh`
Expected: FAIL (`hooks/session-guardian.sh` does not exist).

- [ ] **Step 3: Write minimal implementation**

Create `hooks/session-guardian.sh`:

```bash
#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash): session-lock guardian, layer 2.
# Blocks git commit/push if the active branch no longer matches what this
# session's lock claimed. Safety net for when layer 1 (session-lock.sh) is
# bypassed — e.g. the branch was changed by hand after the session started.
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"

STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON=$(cat 2>/dev/null || true)
fi

SESSION_ID=$(printf '%s' "$STDIN_JSON" | python3 -c "import sys,json
try:
    print((json.load(sys.stdin).get('session_id') or '').strip())
except Exception:
    print('')" 2>/dev/null || true)
[ -z "$SESSION_ID" ] && exit 0

CMD=$(printf '%s' "$STDIN_JSON" | python3 -c "import sys,json
try:
    print((json.load(sys.stdin).get('tool_input') or {}).get('command') or '')
except Exception:
    print('')" 2>/dev/null || true)
[ -z "$CMD" ] && exit 0

echo "$CMD" | grep -qE '(^|[;&|]|&&)[[:space:]]*git[[:space:]]+(commit|push)\b' || exit 0

CWD=$(printf '%s' "$STDIN_JSON" | python3 -c "import sys,json
try:
    print((json.load(sys.stdin).get('cwd') or '').strip())
except Exception:
    print('')" 2>/dev/null || true)
[ -z "$CWD" ] && CWD="$PROJECT_ROOT"

cd "$CWD" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)"
[ -z "$GIT_COMMON_DIR" ] && exit 0
case "$GIT_COMMON_DIR" in
  /*) : ;;
  *) GIT_COMMON_DIR="$CWD/$GIT_COMMON_DIR" ;;
esac

LOCK_FILE="$GIT_COMMON_DIR/slate-sessions/$SESSION_ID.lock"
[ -f "$LOCK_FILE" ] || exit 0   # no claim on record, nothing to guard

CLAIMED_BRANCH=$(python3 -c "import json
try:
    print(json.load(open('$LOCK_FILE')).get('branch',''))
except Exception:
    print('')" 2>/dev/null || true)
[ -z "$CLAIMED_BRANCH" ] && exit 0

ACTUAL_BRANCH="$(git branch --show-current 2>/dev/null)"

if [ -n "$ACTUAL_BRANCH" ] && [ "$ACTUAL_BRANCH" != "$CLAIMED_BRANCH" ]; then
  REASON="La rama activa ('${ACTUAL_BRANCH}') no coincide con la que esta sesion reclamo ('${CLAIMED_BRANCH}'). Alguien cambio de rama por debajo de esta sesion. Commit/push bloqueado por session-guardian."
  python3 -c "import json,sys
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny', 'permissionDecisionReason': sys.argv[1]}}))
" "$REASON"
fi

exit 0
```

Make it executable: `chmod +x hooks/session-guardian.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-session-guardian.sh`
Expected: `All session-guardian tests passed.`

- [ ] **Step 5: Commit**

```bash
git add hooks/session-guardian.sh tests/test-session-guardian.sh
git commit -m "feat: session-guardian blocks commit/push on branch mismatch (FEAT-001.5)"
```

---

### Task 6: `session-lock-cleanup.sh`

**Files:**
- Create: `hooks/session-lock-cleanup.sh`
- Test: `tests/test-session-lock-cleanup.sh`

**Interfaces:**
- Consumes: lock file path convention from Task 1.
- Produces: deletion of exactly `<git-common-dir>/slate-sessions/<session_id>.lock`. Nothing else.

- [ ] **Step 1: Write the failing test**

Create `tests/test-session-lock-cleanup.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-lock-cleanup.sh"

REPO=$(mktemp -d)
git -C "$REPO" init -q
git -C "$REPO" config user.email "t@t.com"
git -C "$REPO" config user.name "t"
git -C "$REPO" commit --allow-empty -q -m init

mkdir -p "$REPO/.git/slate-sessions"
echo '{"branch": "main", "worktree": "", "started_at": "2026-01-01T00:00:00Z"}' > "$REPO/.git/slate-sessions/sess-end.lock"

# Simulate a worktree this session left behind, to prove cleanup does not touch it.
WT="$REPO.leftover-worktree"
git -C "$REPO" worktree add -q "$WT" -b leftover-branch >/dev/null

echo '{"session_id":"sess-end"}' | CLAUDE_PROJECT_ROOT="$REPO" bash "$HOOK"

[ -f "$REPO/.git/slate-sessions/sess-end.lock" ] && { echo "FAIL: lock file still present after cleanup"; exit 1; }
echo "PASS: session-end removes this session's lock file"

[ -d "$WT" ] || { echo "FAIL: cleanup deleted the leftover worktree — it must not touch worktrees"; exit 1; }
echo "PASS: cleanup leaves worktrees and branches untouched"

git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || true
rm -rf "$REPO" "$WT"
echo ""
echo "All session-lock-cleanup tests passed."
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-session-lock-cleanup.sh`
Expected: FAIL (`hooks/session-lock-cleanup.sh` does not exist).

- [ ] **Step 3: Write minimal implementation**

Create `hooks/session-lock-cleanup.sh`:

```bash
#!/usr/bin/env bash
# SessionEnd hook: session-lock guardian, cleanup.
# Removes ONLY this session's lock file, releasing its branch claim. Never
# touches any worktree or branch it may have created — those stay on disk
# for manual review/merge/delete, by explicit product decision.
set -uo pipefail

PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"
cd "$PROJECT_ROOT" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)"
[ -z "$GIT_COMMON_DIR" ] && exit 0
case "$GIT_COMMON_DIR" in
  /*) : ;;
  *) GIT_COMMON_DIR="$PROJECT_ROOT/$GIT_COMMON_DIR" ;;
esac

STDIN_JSON=""
if [ ! -t 0 ]; then
  STDIN_JSON=$(cat 2>/dev/null || true)
fi
SESSION_ID=$(printf '%s' "$STDIN_JSON" | python3 -c "import sys,json
try:
    print((json.load(sys.stdin).get('session_id') or '').strip())
except Exception:
    print('')" 2>/dev/null || true)
[ -z "$SESSION_ID" ] && exit 0

rm -f "$GIT_COMMON_DIR/slate-sessions/$SESSION_ID.lock" 2>/dev/null || true
exit 0
```

Make it executable: `chmod +x hooks/session-lock-cleanup.sh`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-session-lock-cleanup.sh`
Expected: `All session-lock-cleanup tests passed.`

- [ ] **Step 5: Commit**

```bash
git add hooks/session-lock-cleanup.sh tests/test-session-lock-cleanup.sh
git commit -m "feat: session-lock-cleanup releases the lock at session end (FEAT-001.6)"
```

---

### Task 7: Wire hooks into `hooks/hooks.json`

**Files:**
- Modify: `hooks/hooks.json`
- Test: `tests/test-session-lock-hooks-wired.sh`

**Interfaces:**
- Consumes: file paths from Tasks 1, 4, 5, 6.
- Produces: valid `hooks/hooks.json` with 4 new command entries, existing 3 entries untouched.

- [ ] **Step 1: Write the failing test**

Create `tests/test-session-lock-hooks-wired.sh`:

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"

python3 -c "
import json
d = json.load(open('$HOOKS_JSON'))
h = d['hooks']

def cmds(event):
    out = []
    for group in h.get(event, []):
        for entry in group.get('hooks', []):
            out.append(entry['command'])
    return out

session_start_cmds = cmds('SessionStart')
assert any('session-start.sh' in c for c in session_start_cmds), 'existing session-start.sh missing from SessionStart'
assert any('session-lock.sh' in c for c in session_start_cmds), 'session-lock.sh not wired into SessionStart'

session_end_cmds = cmds('SessionEnd')
assert any('session-end.sh' in c for c in session_end_cmds), 'existing session-end.sh missing from SessionEnd'
assert any('session-lock-cleanup.sh' in c for c in session_end_cmds), 'session-lock-cleanup.sh not wired into SessionEnd'

post_cmds = cmds('PostToolUse')
assert any('session-heartbeat.sh' in c for c in post_cmds), 'session-heartbeat.sh not wired into PostToolUse'

pre_cmds = cmds('PreToolUse')
assert any('session-guardian.sh' in c for c in pre_cmds), 'session-guardian.sh not wired into PreToolUse'

pre_group_matchers = [g.get('matcher') for g in h.get('PreToolUse', [])]
assert 'Bash' in pre_group_matchers, 'PreToolUse for session-guardian.sh must matcher Bash'

pre_compact_cmds = cmds('PreCompact')
assert any('pre-compact.sh' in c for c in pre_compact_cmds), 'existing pre-compact.sh must stay untouched'

print('OK')
"
echo "PASS: all 4 session-lock hooks are wired into hooks.json without disturbing existing entries"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-session-lock-hooks-wired.sh`
Expected: FAIL (`AssertionError: session-lock.sh not wired into SessionStart` or similar).

- [ ] **Step 3: Write minimal implementation**

Replace the full contents of `hooks/hooks.json` with:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh" },
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-lock.sh" }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-end.sh" },
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-lock-cleanup.sh" }
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
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-heartbeat.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-guardian.sh" }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test-session-lock-hooks-wired.sh`
Expected: `PASS: all 4 session-lock hooks are wired into hooks.json without disturbing existing entries`

Then run the full suite to confirm no regression:

Run: `bash scripts/self-test.sh`
Expected: `Results: N pass, 0 fail` (N = previous test count + 6 new test files from this plan).

- [ ] **Step 5: Commit**

```bash
git add hooks/hooks.json tests/test-session-lock-hooks-wired.sh
git commit -m "feat: wire session-lock hooks into hooks.json (FEAT-001.7)"
```

---

### Task 8: Register FEAT-001 in Slate's own tracker

**Files:**
- Modify: `features/backlog.md` (add then immediately move — see step 1)
- Modify: `features/in-progress.md`
- Modify: `progress/current.md`

Invoke `slate:breaking-down-features` and `slate:tracking-progress` per `skills/using-slate/SKILL.md` — this is Slate tracking its own development, using its own protocol.

- [ ] **Step 1: Add FEAT-001 directly to `features/in-progress.md`**

This feature is already actively being built (Tasks 1–7 already committed by the time this task runs), so per the movement rules in `docs/feature-format.md` it goes straight to `in-progress.md`, not `backlog.md`.

Append to `features/in-progress.md`:

```markdown
## FEAT-001: Session lock — guardián de sesiones paralelas
- **Status**: in_progress
- **Created**: 2026-07-19
- **Updated**: 2026-07-19
- **Spec**: docs/superpowers/specs/2026-07-19-session-lock-design.md
- **Plan**: docs/superpowers/plans/2026-07-19-session-lock.md
- **Branch**: feat/feat-001-session-lock
- **Verification**: integration-test

### Subtasks
- [x] FEAT-001.1: session-lock.sh claim path
- [x] FEAT-001.2: session-lock.sh stale-lock reaping test
- [x] FEAT-001.3: session-lock.sh collision -> worktree isolation
- [x] FEAT-001.4: session-heartbeat.sh
- [x] FEAT-001.5: session-guardian.sh
- [x] FEAT-001.6: session-lock-cleanup.sh
- [x] FEAT-001.7: wire hooks into hooks.json
- [ ] FEAT-001.8: real two-session end-to-end verification

### Notes
Dos capas: candado de sesion (SessionStart/PostToolUse/SessionEnd, en `$(git rev-parse --git-common-dir)/slate-sessions/`) + guardian de commit (PreToolUse). TTL de heartbeat 15 min. Worktree de aislamiento vive fuera del repo, se deja en disco al cerrar sesion (decision de Felipe).
```

- [ ] **Step 2: Update `progress/current.md`**

Replace the `_(none in flight)_` placeholder body (or append if other work is already listed) with:

```markdown
# Current work

## FEAT-001: Session lock
- Guardián de sesiones paralelas — candado en git-common-dir + guardián de commit.
- Rama: feat/feat-001-session-lock
- Falta: FEAT-001.8 (prueba real con dos sesiones de Claude Code).

<!-- This file is auto-managed by slate:tracking-progress.
     Entries here represent IN-FLIGHT work for the current session.
     At session end, completed entries are moved to history.md;
     orphaned entries become CARRY-OVER. -->
```

- [ ] **Step 3: Commit**

```bash
git add features/in-progress.md progress/current.md
git commit -m "docs: track FEAT-001 (session lock) in Slate's own tracker"
```

---

### Task 9: Real two-session end-to-end verification (acceptance gate)

**Files:** none created — this task exercises the shipped hooks against a real second Claude Code session.

This is the acceptance criterion from the spec: it is not satisfied by unit tests alone. Guide Felipe (non-technical) through it in plain language.

- [ ] **Step 1: Prepare a disposable test repo with Slate installed**

```bash
TESTREPO=$(mktemp -d)/session-lock-e2e-test
mkdir -p "$TESTREPO" && cd "$TESTREPO" && git init -q
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$PLUGIN_ROOT/scripts/install-into-project.sh" "$TESTREPO"
git add -A && git commit -q -m "init test repo with slate"
echo "Test repo ready at: $TESTREPO"
```

- [ ] **Step 2: Open session A**

In a terminal, `cd "$TESTREPO"` and start Claude Code there. Confirm (via `progress/hooks.log` or by asking the session to check) that `.git/slate-sessions/` now has exactly one `.lock` file recording the current branch.

- [ ] **Step 3: Open session B in the SAME repo path, at the same time**

In a second terminal, `cd "$TESTREPO"` (the exact same path, not a copy) and start a second Claude Code session. Its `SessionStart` should fire `session-lock.sh`, see session A's live lock on the same branch, and inject `additionalContext` telling it to work from an isolated worktree at `<parent-of-TESTREPO>/session-lock-e2e-test.slate-worktrees/<8-char-id>`.

Confirm:
- `git -C "$TESTREPO" worktree list` shows a second entry on a `slate-session/*` branch.
- Session B's own messages/actions reference operating from that isolated path.

- [ ] **Step 4: Confirm the guardian blocks a forced mismatch**

In session A (or by hand in `$TESTREPO`), switch branches: `git checkout -b manual-branch-swap`. Then ask session A to run `git commit --allow-empty -m test`. Expected: the commit is DENIED with the `permissionDecisionReason` message about a branch mismatch (visible to session A as a blocked tool call).

- [ ] **Step 5: Record the result**

If all three checks in Steps 2–4 hold, mark `FEAT-001.8` as done. If anything fails, treat it as a bug: stop, diagnose with `superpowers:systematic-debugging`, fix, and re-run this task from Step 1 — do not mark done on a partial pass.

- [ ] **Step 6: Close out via verification-before-completion**

Invoke `superpowers:verification-before-completion` before declaring FEAT-001 done. Then:

```markdown
Update features/in-progress.md: FEAT-001.8 -> [x], Status -> done, add Verified: 2026-07-19.
```

Move the whole `## FEAT-001` block from `features/in-progress.md` to `features/done.md` (append at end, remove from in-progress) per the movement rules — ALL subtasks `[x]` and `Verified:` set.

- [ ] **Step 7: Commit**

```bash
git add features/in-progress.md features/done.md
git commit -m "docs: FEAT-001 (session lock) verified with a real second session, mark done"
```
