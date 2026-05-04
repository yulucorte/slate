# Branch field + WIP limit — Design spec

**Date:** 2026-05-04
**Status:** approved

---

## Problem

claude-harness tracks feature progress but has no awareness of git branches. Users accumulate half-finished branches because:
1. There is no `Branch:` field linking a feature to its branch.
2. There is no constraint preventing multiple features from being active simultaneously.
3. Session start does not warn when the current branch mismatches the active feature.

## Goals

1. Add a `Branch:` field to the feature format so each feature is explicitly linked to a branch.
2. Enforce a WIP limit of 1: at most one feature in `in-progress.md` at any time.
3. Auto-suggest the branch name when moving a feature to in-progress; user confirms or overrides.
4. Warn at session start if the current git branch doesn't match the active feature's branch.
5. Remind the user to merge and delete the branch before moving a feature to `done.md`.

## Non-goals

- Automatically creating or deleting branches (Claude only suggests commands).
- Enforcing merge strategy (rebase vs merge).
- Multi-branch workflows (one branch per subtask).

---

## Design

### 1. Feature format — new `Branch:` field

Added to `docs/feature-format.md` after `Plan:`, before `Verification:`:

```markdown
- **Branch**: feat/feat-NNN-<slug>   (none if not yet started)
```

- Value is `none` for all features in `backlog.md`.
- Value is set when the feature moves to `in-progress.md`.
- The slug is derived from the feature title: lowercase, spaces → hyphens, no accents or special characters.
- Example: `FEAT-007: JWT Authentication` → `feat/feat-007-jwt-authentication`

### 2. WIP limit in managing-feature-list

Before moving any feature from `backlog → in-progress`, count entries currently in `features/in-progress.md`.

**If count = 0:** proceed normally.

**If count ≥ 1:** emit a strong warning:
> "⚠️ Ya tienes FEAT-XXX activa (`<title>`). El harness recomienda terminarla antes de empezar otra. ¿Quieres continuar de todas formas?"

Only proceed if the user explicitly confirms. If no confirmation is given, do not move the feature.

### 3. Branch auto-suggestion in breaking-down-features

When a feature is moved to `in-progress` (or created directly there):

1. Derive slug: title → lowercase → spaces to hyphens → strip non-alphanumeric except hyphens.
2. Propose: `feat/feat-NNN-<slug>`.
3. Ask user: "Propongo el branch `feat/feat-NNN-<slug>`. ¿Lo usamos o prefieres otro nombre?"
4. Write the confirmed name to the `Branch:` field.

Features in backlog always have `Branch: none`.

### 4. Branch cleanup reminder in managing-feature-list

When all subtasks are `[x]` and `Verified:` is set, before writing the entry to `done.md`:

> "Feature lista para cerrar. Antes de moverla a done, ¿ya mergeaste `feat/feat-NNN-<slug>` a main? Si es así, puedes borrarlo con:
> ```
> git branch -d feat/feat-NNN-<slug>
> ```
> Confirma cuando estés listo y la muevo a done."

Claude waits for user confirmation before writing to `done.md`.

### 5. Session-start hook — branch mismatch warning

Added to `hooks/session-start.sh` before JSON emission:

```bash
BRANCH_WARNING=""
CURRENT_BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || true)
if [ -n "$CURRENT_BRANCH" ] && [ -f "$PROJECT_ROOT/features/in-progress.md" ]; then
  ACTIVE_BRANCH=$(grep -m1 '^\*\*Branch\*\*:' "$PROJECT_ROOT/features/in-progress.md" \
    | sed 's/.*: *//' | tr -d '[:space:]' || true)
  if [ -n "$ACTIVE_BRANCH" ] && [ "$ACTIVE_BRANCH" != "none" ] \
     && [ "$CURRENT_BRANCH" != "$ACTIVE_BRANCH" ]; then
    BRANCH_WARNING="⚠️ Estás en branch \`$CURRENT_BRANCH\` pero la feature activa usa \`$ACTIVE_BRANCH\`. Para cambiarte: \`git checkout $ACTIVE_BRANCH\`"
  fi
fi
```

The warning is appended to the `CONTEXT` string already injected via `additionalContext`. Silent if branches match.

---

## Files to modify

| File | Change |
|---|---|
| `docs/feature-format.md` | Add `Branch:` to schema and examples |
| `skills/managing-feature-list/SKILL.md` | WIP limit rule + branch cleanup reminder |
| `skills/breaking-down-features/SKILL.md` | Branch auto-suggest on move to in-progress |
| `skills/using-claude-harness/SKILL.md` | Document WIP limit in protocol + anti-patterns |
| `hooks/session-start.sh` | Branch mismatch check |

## Acceptance criteria

- A feature in `backlog.md` always has `Branch: none`.
- Moving a feature to `in-progress.md` always results in a confirmed `Branch:` value.
- If `in-progress.md` already has an entry, Claude warns before adding another.
- Session start injects a visible warning when current branch ≠ active feature branch.
- Moving a feature to `done.md` is gated on user confirming merge + branch deletion.
