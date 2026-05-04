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

## Sizing rules

- A feature: deliverable user value, typically 30 min – 2 days of agent work.
- A subtask: one Superpowers task, typically 2–30 min.
- If a subtask exceeds 30 min mental estimate, promote it to its own feature with `Parent: FEAT-XXX`.

## Anti-patterns

- DO NOT auto-create features without showing the user the proposed entries first if there are more than 3.
- DO NOT renumber existing FEAT-XXX. IDs are immutable.
- DO NOT collapse subtasks into a single bullet. Each one is a checkbox.
- DO NOT write the `Branch:` field without proposing the auto-suggested name and waiting for user confirmation.
- DO NOT set a real branch name for features in `backlog.md`. Always use `none`.
