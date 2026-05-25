---
name: managing-feature-list
description: Use when the user defines new scope, when about to mark anything complete, when the user asks "what's left", or when moving work between backlog/in-progress/done. Maintains features/backlog.md, features/in-progress.md, features/done.md.
---

# Managing the feature list

The three files in `features/` are the canonical scope. Plans (`docs/superpowers/plans/`) describe HOW; the feature list describes WHAT and WHETHER IT WORKS.

## Format of a feature entry

See `docs/feature-format.md` for the full reference. Minimum:

    ## FEAT-XXX: <Title>
    - **Status**: backlog | in_progress | done
    - **Created**: YYYY-MM-DD
    - **Updated**: YYYY-MM-DD
    - **Plan**: docs/superpowers/plans/<file>.md (or `none`)
    - **Branch**: feat/feat-NNN-<slug> (or `none`)
    - **Verified**: YYYY-MM-DD (only when Status: done)

    ### Subtasks
    - [ ] FEAT-XXX.1: <subtask>

## Movement rules

Every feature MUST pass through `in-progress.md` so SessionStart can recover context.

| From | To | Condition |
|---|---|---|
| backlog.md | in-progress.md | Work is starting now. Soft recommendation: only one feature in-progress at a time. |
| in-progress.md | done.md | ALL subtasks `[x]` AND `Verified: <date>` set. Verification before moving is recommended. |
| in-progress.md | backlog.md | User explicitly defers it. |
| backlog.md | done.md | FORBIDDEN. Route through `in-progress.md`. |
| any | edit done.md | FORBIDDEN. Create a successor with `Supersedes: FEAT-XXX`. |

## ID assignment

Read all three files, find the highest `FEAT-NNN`, assign `FEAT-NNN+1`. Subtasks: `FEAT-XXX.M` where `M` is the next integer within the feature. IDs are immutable.

## When subtasks complete

Mark `[x]` and update `Updated:`. Do not move the feature until ALL subtasks are checked AND `Verified:` is set.

## Anti-patterns

- DO NOT mark `Status: done` without a `Verified:` date.
- DO NOT delete or rewrite a feature in `done.md`. Append a successor.
- DO NOT use statuses like "almost done" or "WIP". Only `backlog | in_progress | done`.
- DO NOT skip `in-progress.md`. Even retroactive work routes through it.
