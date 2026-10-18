---
name: managing-feature-list
description: Use when the user defines new scope, when about to mark anything complete, when the user asks "what's left", or when moving work between backlog/in-progress/done. Maintains docs/slate/features/backlog.md, docs/slate/features/in-progress.md, docs/slate/features/done.md.
---

# Managing the feature list

The three files in `docs/slate/features/` are the canonical scope. Plans (`docs/superpowers/plans/`) describe HOW; the feature list describes WHAT and WHETHER IT WORKS.

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

Do NOT read the files whole. Run `bash <abs-path>/scripts/next-id.sh FEAT`
(the absolute path is in the session-start context, line "IDs/tarjetas") and
use the ID it prints: it already took the max over the live files, the
reservations in `.git/slate-ids/` and local/remote branch names, and reserved
the next number. Reservations are shared by every worktree of the same repo;
they do NOT protect across separate clones or machines (no `fetch`). If the
script is not available, fall back to a bounded `grep` over the live files plus
`ls "$(git rev-parse --git-common-dir)/slate-ids/FEAT"`, then reserve by hand
with `scripts/reserve-id.sh FEAT-NNN` (non-zero exit = taken, try the next).

Subtasks: `FEAT-XXX.M` where `M` is the next integer within the feature.
Subtasks are NOT reserved — they live inside an already-reserved feature, so
there's no cross-branch race to protect. IDs are immutable.

The file search reads only the live files, never the `done-archive-*.md` files:
archiving moves only the oldest (lowest-numbered) entries, so the highest number
always stays live. See `docs/archiving.md`.

## Archiving done.md

`done.md` is append-only and would grow without bound. When it exceeds **40
entries**, rotate before (or right after) appending the completed feature: move
the **oldest** entries in bulk — leaving the ~20 most recent — into
`docs/slate/features/done-archive-YYYYHn.md` (`H1` = Jan–Jun, `H2` = Jul–Dec, by today's
date). Entries move intact, oldest-first. This is the ONLY sanctioned way to
shrink `done.md`; full reference in `docs/archiving.md`.

## When subtasks complete

Mark `[x]` and update `Updated:`. Do not move the feature until ALL subtasks are checked AND `Verified:` is set.

## Anti-patterns

- DO NOT mark `Status: done` without a `Verified:` date.
- DO NOT delete or rewrite a feature in `done.md`. Append a successor. (Moving whole, untouched entries in bulk to `done-archive-YYYYHn.md` is the ONE exception — that changes where a card lives, not what it says. See `docs/archiving.md`.)
- DO NOT use statuses like "almost done" or "WIP". Only `backlog | in_progress | done`.
- DO NOT skip `in-progress.md`. Even retroactive work routes through it.
