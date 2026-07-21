# Archiving Reference

Slate keeps three append-only files that grow without bound:

| Live file | Role |
|---|---|
| `docs/slate/features/done.md` | Completed features, full card each |
| `docs/slate/bugs/fixed.md` | Fixed bugs, full card each |
| `docs/slate/progress/history.md` | Session log |

Left unbounded, `done.md` reaches thousands of lines. Any skill that reads it
whole pays that cost every time. This document defines the **one sanctioned way**
to keep these files small without losing history.

## The blessed rotation flow

When a live file exceeds **40 entries**, move the **oldest** entries in bulk —
leaving the ~20 most recent — into a period archive:

| Live file | Archive file |
|---|---|
| `docs/slate/features/done.md` | `docs/slate/features/done-archive-YYYYHn.md` |
| `docs/slate/bugs/fixed.md` | `docs/slate/bugs/fixed-archive-YYYYHn.md` |
| `docs/slate/progress/history.md` | `docs/slate/progress/history-archive-YYYYHn.md` |

- `YYYYHn`: `H1` = January–June, `H2` = July–December, by the date you archive.
  Example: archiving on 2026-07-20 appends to `*-archive-2026H2.md`.
- An entry = one `## FEAT-NNN` / `## BUG-NNN` block (for history, one
  `## YYYY-MM-DD — <summary>` session block).
- The archive file is created lazily on first use. No template needed.
- Moved entries are **appended intact** to the archive, oldest-first, preserving
  their original order. Nothing is edited, summarized, or renumbered.

## Why this does NOT violate "never edit done.md"

The anti-pattern *"DO NOT delete or rewrite a feature in done.md"* protects the
**content** of a card: you must never alter what a completed feature says. A
bulk move of whole, untouched entries to the period archive changes **where** a
card lives, not **what** it says. That is the single exception, and it is only
legal as a bulk move — never as an edit to an individual card.

## Why archiving keeps ID assignment correct

The next `FEAT-NNN` / `BUG-NNN` is computed by a bounded search over the **live**
files only (see `feature-format.md` / `bug-format.md`). Archiving moves only the
**oldest** (lowest-numbered) entries. Because IDs increase monotonically, the
highest number always stays in a live file — so the ID search never needs to
open an archive.

**Invariant:** archiving MUST move oldest entries first and MUST NOT touch the
newest ~20. Never archive a high-numbered entry while a lower-numbered one
remains live.

## Who triggers it

Rotation happens inline, inside the skill operation that would grow the file:

- `managing-feature-list`, when appending a completed feature to `done.md`.
- `tracking-bugs`, when moving a bug to `fixed.md`.
- `tracking-progress`, when appending a session block to `history.md`.

If the live file is over threshold at that moment, perform the bulk move as part
of the same operation. There is no background job and no hook that rotates files
behind the user's back.

## What never loads archives

- The ID search reads only live files.
- `session-start.sh` only tails `history.md` and indexes `in-progress.md`.
- `using-slate` lists archive files as canonical-but-never-loaded.

Archives exist to be searched with `grep` on demand (e.g. "what did we do in
2026 H1?"), never bulk-read in normal operation.
