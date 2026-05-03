---
name: breaking-down-features
description: Use when a Superpowers plan has just been approved, when the user describes new scope, or when an existing feature is too coarse and needs subtasks. Translates plans or natural-language scope into structured FEAT-XXX entries with subtasks.
---

# Breaking down features

## When to invoke

- Right after `superpowers:writing-plans` produces a plan and the user approves it.
- User describes new desired scope (e.g. "I want users to be able to export to PDF").
- An existing feature in `in-progress.md` has subtasks that are themselves too large.

## Steps

1. Determine target file (default: `features/backlog.md`; if user wants to start now: `features/in-progress.md`).
2. Read existing feature IDs across all three files. Compute next FEAT-XXX.
3. For each new feature, write the entry following `docs/feature-format.md`.
4. If deriving from a Superpowers plan, the plan's tasks (`### Task N`) become subtasks `FEAT-XXX.N`. Preserve task numbering.
5. If a parent feature splits into more, KEEP the parent and add subtasks. Do NOT delete it.

## Sizing rules

- A feature: deliverable user value, typically 30 min – 2 days of agent work.
- A subtask: one Superpowers task, typically 2–30 min.
- If a subtask exceeds 30 min mental estimate, promote it to its own feature with `Parent: FEAT-XXX`.

## Anti-patterns

- DO NOT auto-create features without showing the user the proposed entries first if there are more than 3.
- DO NOT renumber existing FEAT-XXX. IDs are immutable.
- DO NOT collapse subtasks into a single bullet. Each one is a checkbox.
