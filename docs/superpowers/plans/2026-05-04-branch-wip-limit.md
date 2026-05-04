# Branch field + WIP limit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `Branch:` field to the feature format, enforce a WIP limit of 1 active feature, auto-suggest branch names, and warn at session start when the current git branch mismatches the active feature.

**Architecture:** Pure text edits across 5 files — 3 skill SKILL.md files, 1 format doc, 1 bash hook. No new files created. Each task is independent and can be committed separately.

**Tech Stack:** Bash, Markdown

---

### Task 1: Add `Branch:` field to feature-format.md

**Files:**
- Modify: `docs/feature-format.md`

- [ ] **Step 1: Add `Branch:` to the full schema block**

In `docs/feature-format.md`, after the `**Plan**:` line (line 10), insert:

```
    - **Branch**: feat/feat-NNN-<slug>          (none if not yet started)
```

Full schema block after change:

```markdown
    ## FEAT-XXX: <Title>
    - **Status**: backlog | in_progress | done
    - **Created**: YYYY-MM-DD
    - **Updated**: YYYY-MM-DD
    - **Spec**: docs/superpowers/specs/<file>.md | none
    - **Plan**: docs/superpowers/plans/<file>.md | none
    - **Branch**: feat/feat-NNN-<slug>          (none if not yet started)
    - **Verification**: playwright | manual | unit-test | integration-test | none
    - **Verified**: YYYY-MM-DD                 (only when Status: done)
    - **Parent**: FEAT-XXX                     (optional, if this is a sub-feature)
    - **Supersedes**: FEAT-XXX                 (optional, if this replaces a done feature)
    - **Blocks**: FEAT-XXX, FEAT-YYY           (optional)
    - **Blocked by**: FEAT-XXX                 (optional)
    - **Owner**: @handle                       (optional)
    - **Tags**: tag1, tag2                     (optional)
```

- [ ] **Step 2: Add `Branch:` to the "Simple backlog feature" example**

After the `**Plan**: none` line in the simple backlog example, add `- **Branch**: none`:

```markdown
    ## FEAT-042: Add dark mode toggle
    - **Status**: backlog
    - **Created**: 2026-05-03
    - **Updated**: 2026-05-03
    - **Spec**: none
    - **Plan**: none
    - **Branch**: none
    - **Verification**: manual
```

- [ ] **Step 3: Add `Branch:` to the "Completed feature" example**

After `**Plan**:` line in the JWT authentication example, add the branch field:

```markdown
    ## FEAT-007: JWT authentication
    - **Status**: done
    - **Created**: 2025-11-01
    - **Updated**: 2025-11-15
    - **Spec**: docs/superpowers/specs/2025-11-01-auth.md
    - **Plan**: docs/superpowers/plans/2025-11-01-auth.md
    - **Branch**: feat/feat-007-jwt-authentication
    - **Verification**: playwright
    - **Verified**: 2025-11-15
```

- [ ] **Step 4: Add `Branch:` to the "Feature replacing a done one" example**

After `**Supersedes**: FEAT-007` in the FEAT-043 example, add:

```markdown
    ## FEAT-043: JWT authentication v2 (OAuth support)
    - **Status**: in_progress
    - **Created**: 2026-05-03
    - **Updated**: 2026-05-03
    - **Supersedes**: FEAT-007
    - **Branch**: feat/feat-043-jwt-authentication-v2-oauth-support
    - **Verification**: playwright
```

- [ ] **Step 5: Add Branch slug rule to ID rules section**

After the last bullet in the "ID rules" section, add:

```markdown
- Branch slugs: lowercase title, spaces → hyphens, strip accents and non-alphanumeric characters except hyphens. Example: "JWT Authentication v2" → `feat/feat-007-jwt-authentication-v2`.
- Features in `backlog.md` always have `Branch: none`. Set it when moving to `in-progress.md`.
```

- [ ] **Step 6: Verify the file looks correct**

Run:
```bash
grep -n "Branch" docs/feature-format.md
```

Expected output — should show Branch on lines in schema, each example, and ID rules:
```
10:    - **Branch**: feat/feat-NNN-<slug>          (none if not yet started)
53:    - **Branch**: none
70:    - **Branch**: feat/feat-007-jwt-authentication
89:    - **Branch**: feat/feat-043-jwt-authentication-v2-oauth-support
...
```

- [ ] **Step 7: Commit**

```bash
git add docs/feature-format.md
git commit -m "feat: add Branch field to feature format"
```

---

### Task 2: Update managing-feature-list skill — WIP limit + branch cleanup

**Files:**
- Modify: `skills/managing-feature-list/SKILL.md`

- [ ] **Step 1: Add WIP limit rule**

After the `## Movement rules` table, add a new section:

```markdown
## WIP limit

`features/in-progress.md` must have at most 1 feature at any time.

Before moving any feature from `backlog.md` to `in-progress.md`:
1. Count `## FEAT-` entries in `features/in-progress.md`.
2. If count = 0: proceed normally.
3. If count ≥ 1: emit this warning and wait for explicit confirmation before proceeding:

> "⚠️ Ya tienes FEAT-XXX activa (`<title>`). El harness recomienda terminarla antes de empezar otra. ¿Quieres continuar de todas formas?"

Only move the feature if the user explicitly confirms. If they don't confirm, stop.
```

- [ ] **Step 2: Add branch cleanup reminder rule**

After the WIP limit section, add:

```markdown
## Branch cleanup on done

When ALL subtasks are `[x]` and `Verified:` is about to be set, before writing the entry to `done.md`, emit:

> "Feature lista para cerrar. Antes de moverla a done, ¿ya mergeaste `<Branch value>` a main? Si es así, puedes borrarlo con:
> ```
> git branch -d <Branch value>
> ```
> Confirma cuando estés listo y la muevo a done."

Wait for user confirmation before writing to `done.md`. If the feature's `Branch:` is `none`, skip this reminder.
```

- [ ] **Step 3: Update movement rules table**

Replace the existing movement rules table with:

```markdown
| From | To | Required condition |
|---|---|---|
| backlog.md | in-progress.md | User confirms work starts, or a plan is written; AND no active feature in in-progress (or user explicitly overrides WIP warning) |
| in-progress.md | done.md | ALL subtasks `[x]` AND `Verified` field set with a real date AND user confirms branch merged |
| in-progress.md | backlog.md | User explicitly defers it (rare) |
| anything | edit done.md | NEVER. Create new feature with `Supersedes: FEAT-XXX` |
```

- [ ] **Step 4: Add WIP and Branch anti-patterns**

At the end of the `## Anti-patterns` section, add:

```markdown
- DO NOT move a second feature to in-progress.md without warning the user there is already one active.
- DO NOT write the entry in done.md without confirming the user has merged and deleted the branch (unless Branch: none).
```

- [ ] **Step 5: Verify**

Run:
```bash
grep -n "WIP\|Branch cleanup\|branch" skills/managing-feature-list/SKILL.md
```

Expected: lines showing the new WIP limit section and branch cleanup section headings.

- [ ] **Step 6: Commit**

```bash
git add skills/managing-feature-list/SKILL.md
git commit -m "feat: add WIP limit and branch cleanup to managing-feature-list skill"
```

---

### Task 3: Update breaking-down-features skill — branch auto-suggest

**Files:**
- Modify: `skills/breaking-down-features/SKILL.md`

- [ ] **Step 1: Add branch auto-suggest section**

After the `## Steps` section (after step 5), add a new section:

```markdown
## Branch auto-suggest

When a feature is being placed in `in-progress.md` (either moved from backlog or created directly there):

1. Derive the slug from the feature title:
   - Lowercase the title
   - Replace spaces with hyphens
   - Strip accents: á→a, é→e, í→i, ó→o, ú→u, ñ→n, ü→u
   - Remove any character that is not alphanumeric or a hyphen
   - Collapse consecutive hyphens into one
   - Example: "JWT Authentication v2 (OAuth)" → `jwt-authentication-v2-oauth`
2. Compose the branch name: `feat/feat-NNN-<slug>` where NNN is the zero-padded feature ID.
3. Propose it to the user:
   > "Propongo el branch `feat/feat-NNN-<slug>`. ¿Lo usamos o prefieres otro nombre?"
4. Wait for the user's response. Use the confirmed name (or their override) as the `Branch:` value.
5. Write `Branch: <confirmed-name>` to the feature entry.

Features written to `backlog.md` always get `Branch: none`. Only set a real branch name when writing to `in-progress.md`.
```

- [ ] **Step 2: Add Branch anti-pattern**

At the end of the `## Anti-patterns` section, add:

```markdown
- DO NOT write the `Branch:` field without proposing the auto-suggested name and waiting for user confirmation.
- DO NOT set a real branch name for features in `backlog.md`. Always use `none`.
```

- [ ] **Step 3: Verify**

```bash
grep -n "Branch\|slug\|branch" skills/breaking-down-features/SKILL.md
```

Expected: lines from the new Branch auto-suggest section.

- [ ] **Step 4: Commit**

```bash
git add skills/breaking-down-features/SKILL.md
git commit -m "feat: add branch auto-suggest to breaking-down-features skill"
```

---

### Task 4: Update using-claude-harness skill — document WIP limit protocol

**Files:**
- Modify: `skills/using-claude-harness/SKILL.md`

- [ ] **Step 1: Add WIP limit to Protocol section**

In the `## Protocol (mandatory, no exceptions)` section, add a new item after item 3:

```markdown
4. **WIP limit**: `features/in-progress.md` must have at most 1 feature. Before moving backlog → in-progress, count active features and warn if ≥ 1 (see managing-feature-list skill). Before moving in-progress → done, remind user to merge and delete the branch.
```

Renumber the old item 4 (session end) to item 5.

- [ ] **Step 2: Add WIP and Branch anti-patterns**

At the end of the `## Anti-patterns` section, add:

```markdown
- DO NOT move a second feature to in-progress.md without warning the user there is already one active.
- DO NOT write the `Branch:` field without proposing the auto-suggested name and getting user confirmation.
- DO NOT move a feature to done.md without confirming the user has merged and deleted the branch (unless Branch: none).
```

- [ ] **Step 3: Verify**

```bash
grep -n "WIP\|Branch\|branch" skills/using-claude-harness/SKILL.md
```

Expected: lines from the new protocol item and anti-patterns.

- [ ] **Step 4: Commit**

```bash
git add skills/using-claude-harness/SKILL.md
git commit -m "feat: document WIP limit and branch protocol in using-claude-harness skill"
```

---

### Task 5: Update session-start.sh — branch mismatch check

**Files:**
- Modify: `hooks/session-start.sh`

- [ ] **Step 1: Add branch check block after the ACTIVE_FEATURES section**

After the `done` line that closes the `for ffile in` loop (currently line 47), insert this block:

```bash
# Branch mismatch check: warn if current git branch differs from active feature's Branch field
BRANCH_WARNING=""
CURRENT_BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || true)
if [ -n "$CURRENT_BRANCH" ] && [ -f "$PROJECT_ROOT/features/in-progress.md" ]; then
  ACTIVE_BRANCH=$(grep -m1 '\*\*Branch\*\*:' "$PROJECT_ROOT/features/in-progress.md" \
    | sed 's/.*\*\*Branch\*\*: *//' | tr -d '[:space:]' || true)
  if [ -n "$ACTIVE_BRANCH" ] && [ "$ACTIVE_BRANCH" != "none" ] \
     && [ "$CURRENT_BRANCH" != "$ACTIVE_BRANCH" ]; then
    BRANCH_WARNING="⚠️ Estás en branch \`$CURRENT_BRANCH\` pero la feature activa usa \`$ACTIVE_BRANCH\`. Para cambiarte: \`git checkout $ACTIVE_BRANCH\`"
  fi
fi
```

- [ ] **Step 2: Append BRANCH_WARNING to the CONTEXT string**

Replace the CONTEXT build block (lines 49-61) with:

```bash
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

if [ -n "$BRANCH_WARNING" ]; then
  CONTEXT="${CONTEXT}

## Branch warning
${BRANCH_WARNING}"
fi
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n hooks/session-start.sh
```

Expected: no output (clean parse).

- [ ] **Step 4: Smoke test with matching branch**

In a test project that has `features/in-progress.md` with `**Branch**: feat/test-branch`, while on branch `feat/test-branch`:

```bash
CLAUDE_PROJECT_ROOT=/path/to/test-project bash hooks/session-start.sh | python3 -m json.tool | grep -A2 "additionalContext" | head -5
```

Expected: no "Branch warning" section in the output.

- [ ] **Step 5: Smoke test with mismatching branch**

Same test project, while on branch `main`:

```bash
CLAUDE_PROJECT_ROOT=/path/to/test-project bash hooks/session-start.sh | python3 -c "import sys,json; print(json.load(sys.stdin)['additionalContext'])" | grep -A2 "Branch warning"
```

Expected:
```
## Branch warning
⚠️ Estás en branch `main` pero la feature activa usa `feat/test-branch`. Para cambiarte: `git checkout feat/test-branch`
```

- [ ] **Step 6: Commit**

```bash
git add hooks/session-start.sh
git commit -m "feat: add branch mismatch warning to session-start hook"
```
