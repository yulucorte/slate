# Bug Traceability + Idea Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add bug traceability (`bugs/open.md` → `bugs/fixed.md`) and zero-friction idea capture (`ideas/inbox.md` → `ideas/triaged.md`) to the Slate plugin, following the exact markdown-only, append-only-history pattern `features/` already uses.

**Architecture:** Two new parallel state-file pairs (`bugs/`, `ideas/`) installed into projects the same way `features/` is — via `templates/` + `scripts/install-into-project.sh`. Two new skills (`tracking-bugs`, `managing-ideas`) drive the lifecycle, mirroring `managing-feature-list`. Two new slash commands (`/idea`, `/ideas-triage`) give explicit triggers alongside natural-language ones. `hooks/session-start.sh` gains a lightweight count-only injection block, consistent with its existing "index, not dump" design.

**Tech Stack:** Bash (install script, hooks, tests), Markdown (skills, templates, docs). No new runtime dependencies.

## Global Constraints

- Markdown only. No JSON/YAML/SQLite state files (per `README.md` Philosophy section).
- `bugs/fixed.md` and `ideas/triaged.md` are append-only — editing existing entries is FORBIDDEN, same rule as `features/done.md`.
- IDs (`BUG-XXX`) are immutable once assigned, zero-padded to 3 digits, independent numbering from `FEAT-XXX`.
- SessionStart injection stays lightweight: counts/IDs only, never full entry bodies (per commit `4c57836` and the design spec).
- Install script must stay idempotent: `_copy_if_missing` pattern, never overwrite existing project files.
- Every new skill must be justifiable in one sentence (per README Philosophy: "3 hooks, 4 skills... if you cannot justify a new one in one sentence, it does not belong here").
- Spec: `docs/superpowers/specs/2026-07-06-bugs-and-ideas-tracking-design.md`.

---

### Task 1: Bug format reference doc + bug templates

**Files:**
- Create: `docs/bug-format.md`
- Create: `templates/bugs/open.md`
- Create: `templates/bugs/fixed.md`
- Test: `tests/test-bug-templates.sh`

**Interfaces:**
- Produces: the `BUG-XXX` schema (Status, Severity, Reported-by, Detected, Where, Root cause, Fix, Commit, Related feature, Fixed) that Task 2 (`tracking-bugs` skill) and Task 6 (install script) both reference by field name.

- [ ] **Step 1: Write `docs/bug-format.md`**

```markdown
# Bug Format Reference

## Full schema

    ## BUG-XXX: <Title>
    - **Status**: open | fixed
    - **Severity**: low | medium | high | critical
    - **Reported-by**: <name/@handle>
    - **Detected**: YYYY-MM-DD
    - **Where**: <file/module/screen>
    - **Root cause**: <free text; "unknown" until diagnosed>
    - **Fix**: <free text describing the fix>
    - **Commit**: <sha or branch>          (none until fixed)
    - **Related feature**: FEAT-XXX         (optional)
    - **Fixed**: YYYY-MM-DD                 (only when Status: fixed)

## ID rules

- IDs are zero-padded to 3 digits: `BUG-001`, `BUG-042`, `BUG-100`.
- IDs are IMMUTABLE once assigned. Never renumber.
- Numbering is independent of `FEAT-XXX` — the two sequences never collide by design, but there is no requirement that they interleave.
- To find the next available ID: scan both `bugs/*.md` files for `^## BUG-NNN` and take `max(NNN) + 1`.

## Movement rules

| From | To | Required |
|---|---|---|
| `open.md` | `fixed.md` | `Fix`, `Commit`, and `Fixed:` date all set |
| Any | Edit `fixed.md` | **FORBIDDEN** — bugs don't reopen. File a new `BUG-XXX` if it recurs; reference the earlier one in Notes. |

## Examples

### Open bug

    ## BUG-001: Login button unresponsive on Safari
    - **Status**: open
    - **Severity**: high
    - **Reported-by**: @felipe
    - **Detected**: 2026-07-01
    - **Where**: src/components/LoginButton.tsx
    - **Root cause**: unknown
    - **Fix**: none
    - **Commit**: none
    - **Related feature**: FEAT-007

    ### Notes
    Only reproduces on Safari 17, not Chrome/Firefox.

### Fixed bug

    ## BUG-002: Off-by-one in pagination
    - **Status**: fixed
    - **Severity**: medium
    - **Reported-by**: @felipe
    - **Detected**: 2026-06-20
    - **Where**: src/api/paginate.py
    - **Root cause**: `page * limit` used instead of `(page - 1) * limit`
    - **Fix**: Corrected offset calculation, added regression test
    - **Commit**: a1b2c3d
    - **Fixed**: 2026-06-21

    ### Notes
    Verified with test_paginate.py::test_second_page.
```

- [ ] **Step 2: Write `templates/bugs/open.md`**

```markdown
# Open bugs

<!-- Bugs found but not yet fixed. Status: open.
     Add via slate:tracking-bugs.
     Move to fixed.md once Fix, Commit, and Fixed: date are all set. -->
```

- [ ] **Step 3: Write `templates/bugs/fixed.md`**

```markdown
# Fixed bugs

<!-- FORBIDDEN to edit existing entries. If a bug recurs, file a new
     BUG-XXX and reference the earlier one in Notes. -->
```

- [ ] **Step 4: Write `tests/test-bug-templates.sh`**

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Test 1: bug-format.md documents all required fields ---
DOC="$PLUGIN_ROOT/docs/bug-format.md"
[ -f "$DOC" ] || { echo "FAIL: docs/bug-format.md missing"; exit 1; }
for field in Status Severity Reported-by Detected Where "Root cause" Fix Commit Fixed; do
  grep -q -- "$field" "$DOC" || { echo "FAIL: docs/bug-format.md missing field '$field'"; exit 1; }
done
echo "PASS: docs/bug-format.md documents all required fields"

# --- Test 2: templates/bugs/fixed.md declares append-only rule ---
FIXED_TPL="$PLUGIN_ROOT/templates/bugs/fixed.md"
[ -f "$FIXED_TPL" ] || { echo "FAIL: templates/bugs/fixed.md missing"; exit 1; }
grep -qi "FORBIDDEN" "$FIXED_TPL" || { echo "FAIL: templates/bugs/fixed.md missing FORBIDDEN warning"; exit 1; }
echo "PASS: templates/bugs/fixed.md declares append-only rule"

# --- Test 3: templates/bugs/open.md exists and is non-empty ---
OPEN_TPL="$PLUGIN_ROOT/templates/bugs/open.md"
[ -s "$OPEN_TPL" ] || { echo "FAIL: templates/bugs/open.md missing or empty"; exit 1; }
echo "PASS: templates/bugs/open.md exists"

echo ""
echo "All bug template tests passed."
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/test-bug-templates.sh`
Expected: `All bug template tests passed.`

- [ ] **Step 6: Commit**

```bash
git add docs/bug-format.md templates/bugs/open.md templates/bugs/fixed.md tests/test-bug-templates.sh
git commit -m "feat(bugs): add bug format reference and templates"
```

---

### Task 2: `tracking-bugs` skill

**Files:**
- Create: `skills/tracking-bugs/SKILL.md`
- Test: `tests/test-skill-frontmatter.sh`

**Interfaces:**
- Consumes: the schema from `docs/bug-format.md` (Task 1).
- Produces: nothing consumed by later tasks directly — this is a leaf skill, invoked directly by the agent at runtime.

- [ ] **Step 1: Write `skills/tracking-bugs/SKILL.md`**

```markdown
---
name: tracking-bugs
description: Use when the user reports a bug, when diagnosing a bug's root cause, when a fix is about to be committed, or when the user asks "what bugs are open". Maintains bugs/open.md and bugs/fixed.md.
---

# Tracking bugs

The two files in `bugs/` are the canonical bug record. `bugs/open.md` is
mutable working state; `bugs/fixed.md` is the permanent, append-only record —
same relationship as `features/backlog.md` to `features/done.md`.

## Format of a bug entry

See `docs/bug-format.md` for the full reference. Minimum:

    ## BUG-XXX: <Title>
    - **Status**: open | fixed
    - **Severity**: low | medium | high | critical
    - **Reported-by**: <name/@handle>
    - **Detected**: YYYY-MM-DD
    - **Where**: <file/module/screen>
    - **Root cause**: <free text, or "unknown">
    - **Fix**: <free text, or "none">
    - **Commit**: <sha or branch, or "none">

## Lifecycle

1. **Report**: user describes a bug. Assign next `BUG-XXX` (scan both `bugs/*.md`
   for `^## BUG-NNN`, take `max + 1`). Append to `bugs/open.md` with
   `Root cause: unknown` and `Fix: none` if not yet diagnosed.
2. **Diagnose**: when the root cause is found, update the `Root cause` field
   in place (this is `open.md`, mutation is allowed here).
3. **Fix**: when a fix is committed, fill `Fix`, `Commit`, set
   `Status: fixed` and `Fixed: <date>`, then move the whole entry to
   `bugs/fixed.md`.
4. **Closed bugs never reopen.** If the same bug recurs, file a new
   `BUG-XXX` and note the earlier ID in its `Notes` section.

## ID assignment

Read both `bugs/open.md` and `bugs/fixed.md`, find the highest `BUG-NNN`,
assign `BUG-NNN+1`. IDs are immutable and independent of `FEAT-XXX` numbering.

## Anti-patterns

- DO NOT move a bug to `fixed.md` without `Fix`, `Commit`, and `Fixed:` all set.
- DO NOT edit or delete an entry in `fixed.md`. File a new `BUG-XXX` instead.
- DO NOT reuse a `BUG-XXX` ID after a bug is closed.
```

- [ ] **Step 2: Write `tests/test-skill-frontmatter.sh` (covers all new skills, run once)**

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

check_skill() {
  local name="$1"
  local file="$PLUGIN_ROOT/skills/$name/SKILL.md"
  [ -f "$file" ] || { echo "FAIL: $file missing"; exit 1; }
  head -1 "$file" | grep -q '^---$' || { echo "FAIL: $file missing frontmatter opening"; exit 1; }
  grep -q "^name: $name$" "$file" || { echo "FAIL: $file frontmatter name mismatch"; exit 1; }
  grep -q "^description:" "$file" || { echo "FAIL: $file missing description"; exit 1; }
  echo "PASS: $name frontmatter valid"
}

check_skill "tracking-bugs"
check_skill "managing-ideas"

echo ""
echo "All skill frontmatter tests passed."
```

Note: this test references `managing-ideas` (Task 4) and will fail until
that task lands. Run it again at the end of Task 4 — do not treat a Task 2
failure on the `managing-ideas` check as a regression in Task 2's own work.

- [ ] **Step 3: Run the frontmatter check for `tracking-bugs` only to confirm Task 2's part passes**

Run: `grep -q "^name: tracking-bugs$" skills/tracking-bugs/SKILL.md && echo OK`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add skills/tracking-bugs/SKILL.md tests/test-skill-frontmatter.sh
git commit -m "feat(bugs): add tracking-bugs skill"
```

---

### Task 3: Idea format reference doc + idea templates

**Files:**
- Create: `docs/idea-format.md`
- Create: `templates/ideas/inbox.md`
- Create: `templates/ideas/triaged.md`
- Test: `tests/test-idea-templates.sh`

**Interfaces:**
- Produces: the inbox line format (`- YYYY-MM-DD HH:MM — <text>`) and the triaged entry format (Area/Priority/Outcome) that Task 4 (`managing-ideas` skill) and Task 6 (install script) reference.

- [ ] **Step 1: Write `docs/idea-format.md`**

```markdown
# Idea Format Reference

## Inbox entry (ideas/inbox.md)

Deliberately minimal — capture must never interrupt flow.

    - YYYY-MM-DD HH:MM — <raw idea text, verbatim>

No area, priority, or status at capture time. `ideas/inbox.md` is a mutable
working queue: lines are removed once triaged (promoted or archived).
Lines left `kept-pending` stay in the queue untouched.

## Triaged entry (ideas/triaged.md)

Append-only. This file is the permanent triage record — `inbox.md` is not.

    ## YYYY-MM-DD — Triage session
    - <idea text> — **Area**: frontend|backend|db|ux|other — **Priority**: low|med|high — **Outcome**: promoted:FEAT-XXX | archived | kept-pending

## Outcomes

| Outcome | Effect on inbox.md | Effect on triaged.md |
|---|---|---|
| `promoted:FEAT-XXX` | line removed | logged with the resulting FEAT-XXX |
| `archived` | line removed | logged |
| `kept-pending` | line stays | logged (so the decision not to decide is still visible) |

## Example

    ## 2026-07-06 — Triage session
    - Add PDF export for reports — **Area**: backend — **Priority**: med — **Outcome**: promoted:FEAT-051
    - Dark mode toggle — **Area**: frontend — **Priority**: low — **Outcome**: kept-pending
    - Rewrite onboarding copy in Latin — **Area**: other — **Priority**: low — **Outcome**: archived
```

- [ ] **Step 2: Write `templates/ideas/inbox.md`**

```markdown
# Ideas inbox

<!-- Raw, untriaged ideas. Add via slate:managing-ideas (capture) or /idea.
     Run /ideas-triage to group by area and decide: promote to a feature,
     archive, or leave pending. Lines are removed once promoted or archived. -->
```

- [ ] **Step 3: Write `templates/ideas/triaged.md`**

```markdown
# Ideas triaged

<!-- Append-only record of triage decisions. FORBIDDEN to edit existing
     entries. See docs/idea-format.md (in the slate plugin) for the format. -->
```

- [ ] **Step 4: Write `tests/test-idea-templates.sh`**

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# --- Test 1: idea-format.md documents both entry formats ---
DOC="$PLUGIN_ROOT/docs/idea-format.md"
[ -f "$DOC" ] || { echo "FAIL: docs/idea-format.md missing"; exit 1; }
grep -q "Area" "$DOC" || { echo "FAIL: docs/idea-format.md missing Area field"; exit 1; }
grep -q "Priority" "$DOC" || { echo "FAIL: docs/idea-format.md missing Priority field"; exit 1; }
grep -q "Outcome" "$DOC" || { echo "FAIL: docs/idea-format.md missing Outcome field"; exit 1; }
echo "PASS: docs/idea-format.md documents required fields"

# --- Test 2: templates/ideas/triaged.md declares append-only rule ---
TRIAGED_TPL="$PLUGIN_ROOT/templates/ideas/triaged.md"
[ -f "$TRIAGED_TPL" ] || { echo "FAIL: templates/ideas/triaged.md missing"; exit 1; }
grep -qi "FORBIDDEN" "$TRIAGED_TPL" || { echo "FAIL: templates/ideas/triaged.md missing FORBIDDEN warning"; exit 1; }
echo "PASS: templates/ideas/triaged.md declares append-only rule"

# --- Test 3: templates/ideas/inbox.md exists and is non-empty ---
INBOX_TPL="$PLUGIN_ROOT/templates/ideas/inbox.md"
[ -s "$INBOX_TPL" ] || { echo "FAIL: templates/ideas/inbox.md missing or empty"; exit 1; }
echo "PASS: templates/ideas/inbox.md exists"

echo ""
echo "All idea template tests passed."
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/test-idea-templates.sh`
Expected: `All idea template tests passed.`

- [ ] **Step 6: Commit**

```bash
git add docs/idea-format.md templates/ideas/inbox.md templates/ideas/triaged.md tests/test-idea-templates.sh
git commit -m "feat(ideas): add idea format reference and templates"
```

---

### Task 4: `managing-ideas` skill

**Files:**
- Create: `skills/managing-ideas/SKILL.md`
- Modify: `tests/test-skill-frontmatter.sh` (no change needed — it already checks `managing-ideas`; this task makes that check pass)

**Interfaces:**
- Consumes: the format from `docs/idea-format.md` (Task 3).
- Produces: nothing consumed downstream by other tasks — `commands/idea.md` and `commands/ideas-triage.md` (Task 5) reference this skill by name (`managing-ideas`) in their prompts.

- [ ] **Step 1: Write `skills/managing-ideas/SKILL.md`**

```markdown
---
name: managing-ideas
description: Use when the user wants to jot down a future idea mid-session ("anota esta idea...", "se me ocurrió que...", or /idea), or when running /ideas-triage to group, prioritize, and promote/archive accumulated ideas. Maintains ideas/inbox.md and ideas/triaged.md.
---

# Managing ideas

Two triggers, one skill — same shape as `managing-feature-list` covering
multiple lifecycle stages.

## Capture (low friction — no judgment calls)

Trigger: the user says something like "anota esta idea...", "se me ocurrió
que...", or runs `/idea "<text>"`.

Action: append one line to `ideas/inbox.md`:

    - YYYY-MM-DD HH:MM — <raw idea text, verbatim>

Do not categorize, prioritize, or ask clarifying questions at capture time.
The whole point is zero interruption to the current flow.

## Triage (explicit, on demand)

Trigger: the user runs `/ideas-triage`.

Steps:

1. Read `ideas/inbox.md` in full (it's meant to stay short between triage
   passes).
2. Group the lines by area: frontend, backend, db, ux, other. Propose a
   priority (low/med/high) per group based on your judgment of impact/effort.
3. Present the grouped list to the user and ask, per idea (or per group if
   they're fine batching): promote, archive, or keep pending.
4. For each `promote`: invoke `breaking-down-features` to create the
   `FEAT-XXX` entry, then log the idea in `ideas/triaged.md` with
   `Outcome: promoted:FEAT-XXX`, and remove that line from `ideas/inbox.md`.
5. For each `archive`: log with `Outcome: archived`, remove the line from
   `ideas/inbox.md`.
6. For each `keep pending`: log with `Outcome: kept-pending`, but leave the
   line in `ideas/inbox.md` untouched — it comes up again next triage.

See `docs/idea-format.md` for the exact entry formats.

## Anti-patterns

- DO NOT categorize or prioritize at capture time — that's triage's job.
- DO NOT edit or delete existing entries in `ideas/triaged.md`. It is
  append-only.
- DO NOT silently drop a `kept-pending` idea from `inbox.md` — only
  `promoted` and `archived` outcomes remove the line.
- DO NOT invent a `FEAT-XXX` ID yourself when promoting — always go through
  `breaking-down-features` so ID assignment stays centralized.
```

- [ ] **Step 2: Run the full skill frontmatter test**

Run: `bash tests/test-skill-frontmatter.sh`
Expected: `All skill frontmatter tests passed.`

- [ ] **Step 3: Commit**

```bash
git add skills/managing-ideas/SKILL.md
git commit -m "feat(ideas): add managing-ideas skill"
```

---

### Task 5: `/idea` and `/ideas-triage` commands

**Files:**
- Create: `commands/idea.md`
- Create: `commands/ideas-triage.md`
- Test: `tests/test-commands.sh`

**Interfaces:**
- Consumes: `managing-ideas` skill name (Task 4) — both command prompts explicitly tell the agent to invoke it.

- [ ] **Step 1: Write `commands/idea.md`**

```markdown
---
description: Capture a quick development idea into ideas/inbox.md without interrupting current work.
---

Invoke the `managing-ideas` skill's capture path for this idea: $ARGUMENTS

Append it to `ideas/inbox.md` as a single dated line, verbatim, per
`docs/idea-format.md`. Do not categorize, prioritize, or ask follow-up
questions — just capture it and confirm in one line.
```

- [ ] **Step 2: Write `commands/ideas-triage.md`**

```markdown
---
description: Triage the ideas inbox — group by area, propose priority, and promote/archive/keep-pending each idea.
---

Invoke the `managing-ideas` skill's triage path.

Read `ideas/inbox.md`, group the entries by area (frontend/backend/db/ux/other),
propose a priority per group, and walk me through each idea asking whether to
promote it to a feature (via `breaking-down-features`), archive it, or leave
it pending. Log every decision to `ideas/triaged.md` per `docs/idea-format.md`.
```

- [ ] **Step 3: Write `tests/test-commands.sh`**

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

check_command() {
  local name="$1"
  local file="$PLUGIN_ROOT/commands/$name.md"
  [ -f "$file" ] || { echo "FAIL: $file missing"; exit 1; }
  head -1 "$file" | grep -q '^---$' || { echo "FAIL: $file missing frontmatter opening"; exit 1; }
  grep -q "^description:" "$file" || { echo "FAIL: $file missing description"; exit 1; }
  echo "PASS: commands/$name.md valid"
}

check_command "idea"
check_command "ideas-triage"

echo ""
echo "All command tests passed."
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test-commands.sh`
Expected: `All command tests passed.`

- [ ] **Step 5: Commit**

```bash
git add commands/idea.md commands/ideas-triage.md tests/test-commands.sh
git commit -m "feat(ideas): add /idea and /ideas-triage commands"
```

---

### Task 6: Install script, AGENTS.md template, and README updates

**Files:**
- Modify: `scripts/install-into-project.sh`
- Modify: `templates/AGENTS.md`
- Modify: `README.md`
- Modify: `tests/test-install.sh`

**Interfaces:**
- Consumes: `templates/bugs/{open,fixed}.md` (Task 1), `templates/ideas/{inbox,triaged}.md` (Task 3).
- Produces: `bugs/` and `ideas/` directories with their template files present in any project that runs the install script — this is what a project actually gets, so it's the integration point for everything above.

- [ ] **Step 1: Modify `scripts/install-into-project.sh` — add directories and copy calls**

Change the `mkdir -p` line (currently line 16):

```bash
mkdir -p progress/subagents features docs/superpowers/plans docs/superpowers/specs
```

to:

```bash
mkdir -p progress/subagents features bugs ideas docs/superpowers/plans docs/superpowers/specs
```

Add after the existing `features/*.md` copy block (after line 42, before the blank line and `echo ""`):

```bash
_copy_if_missing "$PLUGIN_ROOT/templates/bugs/open.md"        "bugs/open.md"
_copy_if_missing "$PLUGIN_ROOT/templates/bugs/fixed.md"       "bugs/fixed.md"

_copy_if_missing "$PLUGIN_ROOT/templates/ideas/inbox.md"      "ideas/inbox.md"
_copy_if_missing "$PLUGIN_ROOT/templates/ideas/triaged.md"    "ideas/triaged.md"
```

- [ ] **Step 2: Modify `templates/AGENTS.md` — add table rows and rules**

In the state files table, add two rows after the `features/done.md` row:

```markdown
| `bugs/open.md` | Open bugs, being diagnosed or fixed |
| `bugs/fixed.md` | Fixed bugs — NEVER edit |
| `ideas/inbox.md` | Raw captured ideas, not yet triaged |
| `ideas/triaged.md` | Triage decisions — NEVER edit |
```

In the Rules section, add after rule 5:

```markdown
6. A bug moves to `bugs/fixed.md` only when `Fix`, `Commit`, and `Fixed: <date>` are all set.
7. Never edit `bugs/fixed.md` or `ideas/triaged.md`. Bugs don't reopen — file a new `BUG-XXX`. Ideas triage decisions are permanent — re-triage produces new log lines, not edits.
8. Capture ideas into `ideas/inbox.md` immediately when raised; don't categorize until `/ideas-triage` runs.
```

- [ ] **Step 3: Modify `README.md` — add table rows and flow mention**

In the "What it creates in your project" table, add after the `features/done.md` row:

```markdown
| `bugs/open.md` | Open bugs |
| `bugs/fixed.md` | Fixed bugs — never edit |
| `ideas/inbox.md` | Raw captured ideas |
| `ideas/triaged.md` | Idea triage decisions — never edit |
```

In the Flow section, add a new item after item 5:

```markdown
6. **Bugs** are tracked independently via `tracking-bugs`: reported to `bugs/open.md`, moved to `bugs/fixed.md` once `Fix`/`Commit`/`Fixed:` are set.
7. **Ideas** raised mid-session land in `ideas/inbox.md` via `managing-ideas` (or `/idea`), with no friction. Running `/ideas-triage` groups them by area, and promotes selected ones into `features/backlog.md` via `breaking-down-features`.
```

- [ ] **Step 4: Extend `tests/test-install.sh` — add assertions for new files**

Add to the `expected_files` array (after `"features/done.md"`):

```bash
  "bugs/open.md"
  "bugs/fixed.md"
  "ideas/inbox.md"
  "ideas/triaged.md"
```

Add a new check after the existing "Test 4: progress/subagents dir exists" block, before `rm -rf "$TMPDIR_PROJECT"`:

```bash
# --- Test 5: bugs/ and ideas/ dirs exist ---
for d in "bugs" "ideas"; do
  if [ ! -d "$TMPDIR_PROJECT/$d" ]; then
    echo "FAIL: $d/ not created"
    rm -rf "$TMPDIR_PROJECT"
    exit 1
  fi
done
echo "PASS: bugs/ and ideas/ exist"
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/test-install.sh`
Expected: `All install tests passed.` (plus the new `PASS: bugs/ and ideas/ exist` line)

- [ ] **Step 6: Commit**

```bash
git add scripts/install-into-project.sh templates/AGENTS.md README.md tests/test-install.sh
git commit -m "feat: wire bugs/ and ideas/ into the install script and docs"
```

---

### Task 7: SessionStart hook — lightweight bug/idea counts

**Files:**
- Modify: `hooks/session-start.sh`
- Create: `tests/test-session-start-counts.sh`

**Interfaces:**
- Consumes: `bugs/open.md` (`^## BUG-` headers) and `ideas/inbox.md` (non-empty `- ` lines) — both installed by Task 6.
- Produces: two additional lines in the `additionalContext` JSON payload, appended in both the `startup|clear` and `compact|resume` branches.

- [ ] **Step 1: Add count computation to `hooks/session-start.sh`**

Insert after the existing `INPROGRESS_INDEX` block (after line 56, `[ -z "$INPROGRESS_INDEX" ] && INPROGRESS_INDEX="(ninguna feature en progreso)"`):

```bash
# Bugs open + ideas pending: counts and IDs only, never full entry bodies —
# same "index, not dump" principle as INPROGRESS_INDEX above. Skip cleanly
# if bugs/ or ideas/ don't exist (projects installed before this feature).
BUGS_LINE=""
if [ -f "$PROJECT_ROOT/bugs/open.md" ]; then
  BUG_IDS=$(grep -o '^## BUG-[0-9]\{3\}' "$PROJECT_ROOT/bugs/open.md" 2>/dev/null | sed 's/^## //' | paste -sd, - || true)
  BUG_COUNT=$(printf '%s' "$BUG_IDS" | tr ',' '\n' | grep -c . || true)
  [ "$BUG_COUNT" -gt 0 ] 2>/dev/null && BUGS_LINE="## Bugs abiertos: ${BUG_COUNT} (${BUG_IDS})"
fi

IDEAS_LINE=""
if [ -f "$PROJECT_ROOT/ideas/inbox.md" ]; then
  IDEA_COUNT=$(grep -c '^- ' "$PROJECT_ROOT/ideas/inbox.md" 2>/dev/null || true)
  [ "${IDEA_COUNT:-0}" -gt 0 ] 2>/dev/null && IDEAS_LINE="## Ideas pendientes: ${IDEA_COUNT} (correr /ideas-triage)"
fi
```

- [ ] **Step 2: Append the new lines in both branches of the `case` statement**

Change the `compact|resume` branch (currently):

```bash
  compact|resume)
    # The agent already has the protocol in context. Inject the bare minimum:
    # in-progress index + the single most recent history line. No header.
    CONTEXT="## In-progress (índice)
${INPROGRESS_INDEX}

## History (última)
$(history_tail 1)"
    ;;
```

to:

```bash
  compact|resume)
    # The agent already has the protocol in context. Inject the bare minimum:
    # in-progress index + the single most recent history line. No header.
    CONTEXT="## In-progress (índice)
${INPROGRESS_INDEX}

## History (última)
$(history_tail 1)"
    [ -n "$BUGS_LINE" ] && CONTEXT="${CONTEXT}
${BUGS_LINE}"
    [ -n "$IDEAS_LINE" ] && CONTEXT="${CONTEXT}
${IDEAS_LINE}"
    ;;
```

Change the `*` (startup|clear) branch similarly — after the existing
`CONTEXT="Slate activo ...` assignment and before the closing `;;`, add:

```bash
    [ -n "$BUGS_LINE" ] && CONTEXT="${CONTEXT}
${BUGS_LINE}"
    [ -n "$IDEAS_LINE" ] && CONTEXT="${CONTEXT}
${IDEAS_LINE}"
    ;;
```

- [ ] **Step 3: Write `tests/test-session-start-counts.sh`**

```bash
#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"; rm -rf "$TMPDIR_PROJECT" 2>/dev/null || true' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/session-start.sh"

TMPDIR_PROJECT=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT/progress" "$TMPDIR_PROJECT/features" "$TMPDIR_PROJECT/bugs" "$TMPDIR_PROJECT/ideas"
touch "$TMPDIR_PROJECT/progress/history.md" "$TMPDIR_PROJECT/progress/current.md"
touch "$TMPDIR_PROJECT/features/in-progress.md"

cat > "$TMPDIR_PROJECT/bugs/open.md" <<'EOF'
# Open bugs

## BUG-001: Login button unresponsive
- **Status**: open

## BUG-002: Pagination off by one
- **Status**: open
EOF

cat > "$TMPDIR_PROJECT/ideas/inbox.md" <<'EOF'
# Ideas inbox

- 2026-07-01 10:00 — Add PDF export
EOF

OUTPUT=$(echo '{"source":"startup"}' | CLAUDE_PROJECT_ROOT="$TMPDIR_PROJECT" bash "$HOOK")

echo "$OUTPUT" | grep -q "Bugs abiertos: 2 (BUG-001,BUG-002)" || { echo "FAIL: bug count/IDs missing from output. Got: $OUTPUT"; exit 1; }
echo "PASS: bug count injected correctly"

echo "$OUTPUT" | grep -q "Ideas pendientes: 1" || { echo "FAIL: idea count missing from output. Got: $OUTPUT"; exit 1; }
echo "PASS: idea count injected correctly"

# --- Test: no bugs/ideas dirs -> hook does not error, no bug/idea lines ---
TMPDIR_PROJECT2=$(mktemp -d)
mkdir -p "$TMPDIR_PROJECT2/progress" "$TMPDIR_PROJECT2/features"
touch "$TMPDIR_PROJECT2/progress/history.md" "$TMPDIR_PROJECT2/progress/current.md" "$TMPDIR_PROJECT2/features/in-progress.md"

OUTPUT2=$(echo '{"source":"startup"}' | CLAUDE_PROJECT_ROOT="$TMPDIR_PROJECT2" bash "$HOOK")
echo "$OUTPUT2" | grep -q "Bugs abiertos" && { echo "FAIL: bug line present when bugs/ absent"; exit 1; }
echo "PASS: no bug/idea lines when directories absent, hook did not error"

rm -rf "$TMPDIR_PROJECT" "$TMPDIR_PROJECT2"
echo ""
echo "All session-start count tests passed."
```

- [ ] **Step 4: Run the test to verify it fails before Steps 1–2 are applied**

Run: `bash tests/test-session-start-counts.sh`
Expected: FAIL with "bug count/IDs missing from output" (hook doesn't emit the line yet)

- [ ] **Step 5: Apply Steps 1–2 to `hooks/session-start.sh`, then re-run**

Run: `bash tests/test-session-start-counts.sh`
Expected: `All session-start count tests passed.`

- [ ] **Step 6: Run the full existing test suite to confirm no regression**

Run: `bash scripts/self-test.sh`
Expected: `Results: N pass, 0 fail` (N = total test file count, all passing)

- [ ] **Step 7: Commit**

```bash
git add hooks/session-start.sh tests/test-session-start-counts.sh
git commit -m "feat: inject lightweight bug/idea counts on SessionStart"
```

---

### Task 8: Changelog and final full-suite verification

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add a new entry to the top of `CHANGELOG.md`**

```markdown
## 1.2.0 — 2026-07-06

Adds bug traceability and idea capture, following the same markdown-only,
append-only-history pattern as `features/`.

### Added
- `bugs/open.md` / `bugs/fixed.md` — bug tracking with `BUG-XXX` IDs,
  independent numbering from `FEAT-XXX`. See `docs/bug-format.md`.
- `ideas/inbox.md` / `ideas/triaged.md` — zero-friction idea capture plus
  explicit triage (group by area, promote/archive/keep-pending). See
  `docs/idea-format.md`.
- Skills: `tracking-bugs`, `managing-ideas`.
- Commands: `/idea "<text>"`, `/ideas-triage`.
- `hooks/session-start.sh` now injects open-bug count + IDs and
  pending-idea count, same lightweight index principle as the existing
  in-progress features index.

```

(Leave the existing `## 1.1.0 — 2026-06-22` section and everything below it
unchanged.)

- [ ] **Step 2: Run the full test suite**

Run: `bash scripts/self-test.sh`
Expected: `Results: N pass, 0 fail`

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: changelog entry for bug traceability and idea capture"
```

## Self-Review Notes

- **Spec coverage**: bugs/open.md+fixed.md (Task 1, 2, 6), ideas/inbox.md+triaged.md (Task 3, 4, 6), commands (Task 5), SessionStart hook (Task 7), install script + AGENTS.md + README (Task 6), CHANGELOG (Task 8). All spec sections have a task.
- **Placeholder scan**: no TBD/TODO; every step has literal file content.
- **Type/field consistency**: `BUG-XXX` field names (`Status`, `Severity`, `Reported-by`, `Detected`, `Where`, `Root cause`, `Fix`, `Commit`, `Related feature`, `Fixed`) match across `docs/bug-format.md`, `templates/bugs/*.md`, and `skills/tracking-bugs/SKILL.md`. Idea outcome values (`promoted:FEAT-XXX`, `archived`, `kept-pending`) match across `docs/idea-format.md` and `skills/managing-ideas/SKILL.md`.
