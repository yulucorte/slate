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
2. Compute next FEAT-XXX with a bounded search — do NOT read the files whole:

       grep -hoE 'FEAT-[0-9]+' features/backlog.md features/in-progress.md features/done.md 2>/dev/null \
         | grep -oE '[0-9]+' | sort -n | tail -1

   Next ID = that number + 1, zero-padded to 3 digits. Empty output → `FEAT-001`.
   Only live files are scanned; archives are never needed (see `docs/archiving.md`).
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
