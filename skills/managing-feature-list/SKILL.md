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
| backlog.md | in-progress.md | User confirms work starts, or a plan is written; AND no active feature in in-progress (or user explicitly overrides WIP warning) |
| in-progress.md | done.md | ALL subtasks `[x]` AND `Verified` field set with a real date AND user confirms branch merged |
| in-progress.md | backlog.md | User explicitly defers it (rare) |
| anything | edit done.md | NEVER. Create new feature with `Supersedes: FEAT-XXX` |

## WIP limit

`features/in-progress.md` must have at most 1 feature at any time.

Before moving any feature from `backlog.md` to `in-progress.md`:
1. Count `## FEAT-` entries in `features/in-progress.md`.
2. If count = 0: proceed normally.
3. If count ≥ 1: emit this warning and wait for explicit confirmation before proceeding:

> "⚠️ Ya tienes `<existing-id>` activa (`<title>`). El harness recomienda terminarla antes de empezar otra. ¿Quieres continuar de todas formas?"

Only move the feature if the user explicitly confirms. If they don't confirm, stop.

## Branch cleanup on done

This is the required "user confirms branch merged" gate referenced in the movement rules table.

When ALL subtasks are `[x]` and `Verified:` is about to be set, before writing the entry to `done.md`, emit:

> "Feature lista para cerrar. Antes de moverla a done, ¿ya mergeaste `<Branch value>` a main? Si es así, puedes borrarlo con:
> ```
> git branch -d <Branch value>
> ```
> Confirma cuando estés listo y la muevo a done."

Wait for user confirmation before writing to `done.md`. If the feature's `Branch:` is `none`, skip this reminder.

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
- DO NOT move a second feature to in-progress.md without warning the user there is already one active.
- DO NOT write the entry in done.md without confirming the user has merged and deleted the branch (unless Branch: none).
