# Bug Format Reference

## Full schema

    ## BUG-XXX: <Title>
    - **Status**: open | fixed
    - **Severity**: low | medium | high | critical
    - **Reported-by**: <name/@handle>
    - **Detected**: YYYY-MM-DD
    - **Where**: <file/module/screen>
    - **Root cause**: <free text; "unknown" until diagnosed>
    - **Fix**: <free text describing the fix>
    - **Commit**: <sha or branch>          (none until fixed)
    - **Related feature**: FEAT-XXX         (optional)
    - **Fixed**: YYYY-MM-DD                 (only when Status: fixed)

## ID rules

- IDs are zero-padded to 3 digits: `BUG-001`, `BUG-042`, `BUG-100`.
- IDs are IMMUTABLE once assigned. Never renumber.
- Numbering is independent of `FEAT-XXX` — the two sequences never collide by design, but there is no requirement that they interleave.
- To find the next available ID: scan both `bugs/*.md` files for `^## BUG-NNN` and take `max(NNN) + 1`.

## Movement rules

| From | To | Required |
|---|---|---|
| `open.md` | `fixed.md` | `Fix`, `Commit`, and `Fixed:` date all set |
| Any | Edit `fixed.md` | **FORBIDDEN** — bugs don't reopen. File a new `BUG-XXX` if it recurs; reference the earlier one in Notes. |

## Examples

### Open bug

    ## BUG-001: Login button unresponsive on Safari
    - **Status**: open
    - **Severity**: high
    - **Reported-by**: @felipe
    - **Detected**: 2026-07-01
    - **Where**: src/components/LoginButton.tsx
    - **Root cause**: unknown
    - **Fix**: none
    - **Commit**: none
    - **Related feature**: FEAT-007

    ### Notes
    Only reproduces on Safari 17, not Chrome/Firefox.

### Fixed bug

    ## BUG-002: Off-by-one in pagination
    - **Status**: fixed
    - **Severity**: medium
    - **Reported-by**: @felipe
    - **Detected**: 2026-06-20
    - **Where**: src/api/paginate.py
    - **Root cause**: `page * limit` used instead of `(page - 1) * limit`
    - **Fix**: Corrected offset calculation, added regression test
    - **Commit**: a1b2c3d
    - **Fixed**: 2026-06-21

    ### Notes
    Verified with test_paginate.py::test_second_page.
