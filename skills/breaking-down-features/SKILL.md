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

1. Determine target file (default: `docs/slate/features/backlog.md`; if work starts now: `docs/slate/features/in-progress.md`).
2. Get the next FEAT-XXX with `bash <abs-path>/scripts/next-id.sh FEAT` (absolute
   path in the session-start context, line "IDs/tarjetas") and use the ID it
   prints — do NOT read the files whole. It takes the max over live files,
   `.git/slate-ids/` and branch names, and reserves it (shared by every
   worktree of the repo; not across clones/machines). Without the script, fall
   back to a bounded `grep` plus `scripts/reserve-id.sh FEAT-NNN`.

   **Creating more than one feature in the same batch (up to 3, see the
   anti-pattern below): call `next-id.sh` once PER feature**, so each gets its
   own reservation; one call does not reserve the rest of the batch.
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
