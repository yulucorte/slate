---
name: managing-feature-list
description: Use when the user defines new scope, when about to mark anything complete, when the user asks "what's left", or when moving work between backlog/in-progress/done. Maintains features/backlog.md, features/in-progress.md, features/done.md.
---

# Managing the feature list

The three files in `features/` are the canonical scope of the project. Plans (`docs/superpowers/plans/`) describe HOW; feature list describes WHAT and WHETHER IT WORKS.

## Format of a feature entry

See `docs/feature-format.md` for the full reference. Minimum required fields:

    ## FEAT-XXX: <Title>
    - **Status**: backlog | in_progress | done
    - **Created**: YYYY-MM-DD
    - **Updated**: YYYY-MM-DD
    - **Spec**: docs/superpowers/specs/<file>.md (or `none` if no spec)
    - **Plan**: docs/superpowers/plans/<file>.md (or `none`)
    - **Verification**: playwright | manual | unit-test | integration-test | none
    - **Verified**: YYYY-MM-DD (only present when Status: done)

    ### Subtasks
    - [ ] FEAT-XXX.1: <subtask>
    - [ ] FEAT-XXX.2: <subtask>

    ### Notes
    <free-form>

## Movement rules (FORBIDDEN to violate)

| From | To | Required condition |
|---|---|---|
| backlog.md | in-progress.md | User confirms work starts, or a plan is written |
| in-progress.md | done.md | ALL subtasks `[x]` AND `Verified` field set with a real date |
| in-progress.md | backlog.md | User explicitly defers it (rare) |
| anything | edit done.md | NEVER. Create new feature with `Supersedes: FEAT-XXX` |

## ID assignment

- Read all three files, find the highest existing FEAT-NNN, assign FEAT-NNN+1.
- Subtasks: FEAT-XXX.M where M is the next integer within that feature.

## When subtasks complete

Mark `[x]` and update the `Updated` field. Do NOT move the feature yet — wait until ALL subtasks complete AND verification is done.

## When verification runs

Append to the feature's `### Notes` section: `Verified <date>: <command run>, output: <last 10 lines>`. Then update the `Verified:` field and move to done.md.

## Anti-patterns

- DO NOT create FEAT-XXX entries inline in plans. Always write to `features/backlog.md` first.
- DO NOT mark `Status: done` without a `Verified:` date. The hook `pre-compact.sh` will flag this.
- DO NOT delete or rewrite a feature in `done.md`. Append a successor.
- DO NOT use ambiguous statuses like "almost done" or "WIP". Only `backlog | in_progress | done`.
