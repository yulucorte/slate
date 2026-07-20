# Feature Format Reference

## Full schema

    ## FEAT-XXX: <Title>
    - **Status**: backlog | in_progress | done
    - **Created**: YYYY-MM-DD
    - **Updated**: YYYY-MM-DD
    - **Spec**: docs/superpowers/specs/<file>.md | none
    - **Plan**: docs/superpowers/plans/<file>.md | none
    - **Branch**: feat/feat-NNN-<slug>          (none if not yet started)
    - **Verification**: playwright | manual | unit-test | integration-test | none
    - **Verified**: YYYY-MM-DD                 (only when Status: done)
    - **Parent**: FEAT-XXX                     (optional, if this is a sub-feature)
    - **Supersedes**: FEAT-XXX                 (optional, if this replaces a done feature)
    - **Blocks**: FEAT-XXX, FEAT-YYY           (optional)
    - **Blocked by**: FEAT-XXX                 (optional)
    - **Owner**: @handle                       (optional)
    - **Tags**: tag1, tag2                     (optional)

    ### Subtasks
    - [ ] FEAT-XXX.1: <subtask description>
    - [ ] FEAT-XXX.2: <subtask description>

    ### Notes
    <free-form Markdown>

## The `Branch:` field

The `Branch:` field declares the git branch that carries this feature's commits. It exists for traceability; the harness does not act on it automatically.

- **Format**: a branch name (e.g. `feat/feat-042-add-dark-mode-toggle`, `feat/feat-007-jwt-authentication`) or the literal string `none`. The suggested format is `feat/feat-NNN-<slug>`, derived per `breaking-down-features` (slug = title lowercased, hyphens, accents stripped, non-alphanumerics removed).
- **Lifecycle**: features in `backlog.md` always carry `Branch: none`. The real branch name is decided when the feature transitions to `in-progress.md`. `none` may persist into in-progress/done as an explicit opt-out — the feature then ships on whatever branch picks it up.
- **Optional**: the field is recommended but not enforced. If you don't care about branch tracking, set `none` and move on.

## ID rules

- IDs are zero-padded to 3 digits: `FEAT-001`, `FEAT-042`, `FEAT-100`.
- IDs are IMMUTABLE once assigned. Never renumber.
- Subtask IDs: `FEAT-XXX.N` where N starts at 1 within the feature.
- To find the next available ID, use a bounded search — never read the files whole:

      grep -hoE 'FEAT-[0-9]+' features/backlog.md features/in-progress.md features/done.md 2>/dev/null \
        | grep -oE '[0-9]+' | sort -n | tail -1

  Next ID = that number + 1 (empty output → `001`). Only the live files are
  scanned; `done-archive-*.md` is never needed because archiving moves oldest
  entries only, so the highest number always stays live (see `docs/archiving.md`).
- Branch slug rules and the "always `none` in backlog" lifecycle rule live in the [`## The Branch: field`](#the-branch-field) section above.

## Movement rules

| From | To | Required |
|---|---|---|
| `backlog.md` | `in-progress.md` | User confirms work starts OR plan written |
| `in-progress.md` | `done.md` | ALL subtasks `[x]` AND `Verified:` date set |
| `in-progress.md` | `backlog.md` | User explicitly defers (rare) |
| Any | Edit `done.md` | **FORBIDDEN** — create `Supersedes:` successor instead |
| `done.md` (>40 entries) | `done-archive-YYYYHn.md` | Bulk move of oldest entries only. NOT an edit — see [`docs/archiving.md`](archiving.md) |

## Examples

### Simple backlog feature

    ## FEAT-042: Add dark mode toggle
    - **Status**: backlog
    - **Created**: 2026-05-03
    - **Updated**: 2026-05-03
    - **Spec**: none
    - **Plan**: none
    - **Branch**: none
    - **Verification**: manual

    ### Subtasks
    - [ ] FEAT-042.1: Add CSS variables for dark theme
    - [ ] FEAT-042.2: Toggle button in settings UI
    - [ ] FEAT-042.3: Persist preference in localStorage

    ### Notes
    User requested this in session 2026-05-02.

### Completed feature

    ## FEAT-007: JWT authentication
    - **Status**: done
    - **Created**: 2025-11-01
    - **Updated**: 2025-11-15
    - **Spec**: docs/superpowers/specs/2025-11-01-auth.md
    - **Plan**: docs/superpowers/plans/2025-11-01-auth.md
    - **Branch**: feat/feat-007-jwt-authentication
    - **Verification**: playwright
    - **Verified**: 2025-11-15

    ### Subtasks
    - [x] FEAT-007.1: Login form UI
    - [x] FEAT-007.2: POST /auth/login endpoint
    - [x] FEAT-007.3: Session cookie + refresh
    - [x] FEAT-007.4: Playwright e2e green

    ### Notes
    Verified 2025-11-15: npx playwright test auth.spec.ts, output: 4 passed.

### Feature replacing a done one

    ## FEAT-043: JWT authentication v2 (OAuth support)
    - **Status**: in_progress
    - **Created**: 2026-05-03
    - **Updated**: 2026-05-03
    - **Supersedes**: FEAT-007
    - **Branch**: feat/feat-043-jwt-authentication-v2-oauth-support
    - **Verification**: playwright

    ### Subtasks
    - [ ] FEAT-043.1: OAuth provider config
    - [ ] FEAT-043.2: Callback endpoint
    - [ ] FEAT-043.3: Playwright e2e for OAuth flow

### Blocked feature

    ## FEAT-044: PDF export
    - **Status**: backlog
    - **Branch**: none
    - **Blocked by**: FEAT-043
    - **Verification**: manual

    ### Subtasks
    - [ ] FEAT-044.1: Install PDF library
    - [ ] FEAT-044.2: Export button
