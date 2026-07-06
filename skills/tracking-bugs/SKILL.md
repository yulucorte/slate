---
name: tracking-bugs
description: Use when the user reports a bug, when diagnosing a bug's root cause, when a fix is about to be committed, or when the user asks "what bugs are open". Maintains bugs/open.md and bugs/fixed.md.
---

# Tracking bugs

The two files in `bugs/` are the canonical bug record. `bugs/open.md` is
mutable working state; `bugs/fixed.md` is the permanent, append-only record —
same relationship as `features/backlog.md` to `features/done.md`.

## Format of a bug entry

See `docs/bug-format.md` for the full reference. Minimum:

    ## BUG-XXX: <Title>
    - **Status**: open | fixed
    - **Severity**: low | medium | high | critical
    - **Reported-by**: <name/@handle>
    - **Detected**: YYYY-MM-DD
    - **Where**: <file/module/screen>
    - **Root cause**: <free text, or "unknown">
    - **Fix**: <free text, or "none">
    - **Commit**: <sha or branch, or "none">

## Lifecycle

1. **Report**: user describes a bug. Assign next `BUG-XXX` (scan both `bugs/*.md`
   for `^## BUG-NNN`, take `max + 1`). Append to `bugs/open.md` with
   `Root cause: unknown` and `Fix: none` if not yet diagnosed.
2. **Diagnose**: when the root cause is found, update the `Root cause` field
   in place (this is `open.md`, mutation is allowed here).
3. **Fix**: when a fix is committed, fill `Fix`, `Commit`, set
   `Status: fixed` and `Fixed: <date>`, then move the whole entry to
   `bugs/fixed.md`.
4. **Closed bugs never reopen.** If the same bug recurs, file a new
   `BUG-XXX` and note the earlier ID in its `Notes` section.

## ID assignment

Read both `bugs/open.md` and `bugs/fixed.md`, find the highest `BUG-NNN`,
assign `BUG-NNN+1`. IDs are immutable and independent of `FEAT-XXX` numbering.

## Anti-patterns

- DO NOT move a bug to `fixed.md` without `Fix`, `Commit`, and `Fixed:` all set.
- DO NOT edit or delete an entry in `fixed.md`. File a new `BUG-XXX` instead.
- DO NOT reuse a `BUG-XXX` ID after a bug is closed.
