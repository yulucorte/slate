# Feature Format Reference

## Full schema

    ## FEAT-XXX: <Title>
    - **Status**: backlog | in_progress | done
    - **Created**: YYYY-MM-DD
    - **Updated**: YYYY-MM-DD
    - **Branch**: feat/XXX-slug | none
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

The `Branch:` field declares the git branch that will carry this feature's commits.

- **Format**: a branch name (e.g. `feat/042-dark-mode`, `fix/auth-redirect`) or the literal string `none`.
- **`none`** means the feature ships on the current branch — no dedicated branch will be created, and no PR will be opened automatically for it.
- **When required**: any feature that will go through the watcher hooks must declare `Branch:` — that is, whenever `HARNESS_AUTO_BRANCH=true` (or you intend to use the `harness-create-branch` skill) for in-progress features, or `HARNESS_AUTO_PR=true` (or you intend to use the `harness-open-pr` skill) for done features. In these cases the field is **mandatory**, with `none` as the explicit opt-out.
- **When optional**: if both `HARNESS_AUTO_BRANCH=false` and `HARNESS_AUTO_PR=false` and you don't plan to use the manual skills, the field may be omitted. It is still recommended for traceability.
- **What happens if missing**: the watcher hooks (`post-edit-in-progress-watcher.sh`, `post-edit-done-watcher.sh`) emit a yellow `warn` line via `emit-status.sh` (reason `branch-missing-or-none`) and skip the automated action. The `verify-harness-hooks` skill flags such features as yellow. Nothing breaks — the feature simply does not auto-branch or auto-PR.
- **`done` semantics**: when a feature is moved to `done.md`, the done watcher will only open a PR if the current git branch matches the feature's `Branch:` value. A mismatch produces a `warn` with reason `branch-mismatch`.

The field is read by [hooks/lib/read-feature.sh](../hooks/lib/read-feature.sh) and consumed by both watchers, [scripts/harness/pr-open.sh](../scripts/harness/pr-open.sh), and the `harness-create-branch` / `harness-open-pr` skills.

## ID rules

- IDs are zero-padded to 3 digits: `FEAT-001`, `FEAT-042`, `FEAT-100`.
- IDs are IMMUTABLE once assigned. Never renumber.
- Subtask IDs: `FEAT-XXX.N` where N starts at 1 within the feature.
- To find the next available ID: run `next_feature_id features/` from `scripts/lib/parse-features.sh`.
- Branch slugs: lowercase title, spaces → hyphens, strip accents and non-alphanumeric characters except hyphens. Example: "JWT Authentication v2" → `feat/feat-007-jwt-authentication-v2`.
- Features in `backlog.md` always have `Branch: none`. Set it when moving to `in-progress.md`.

## Movement rules

| From | To | Required |
|---|---|---|
| `backlog.md` | `in-progress.md` | User confirms work starts OR plan written |
| `in-progress.md` | `done.md` | ALL subtasks `[x]` AND `Verified:` date set |
| `in-progress.md` | `backlog.md` | User explicitly defers (rare) |
| Any | Edit `done.md` | **FORBIDDEN** — create `Supersedes:` successor instead |

## Examples

### Simple backlog feature

    ## FEAT-042: Add dark mode toggle
    - **Status**: backlog
    - **Created**: 2026-05-03
    - **Updated**: 2026-05-03
    - **Branch**: feat/042-dark-mode
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
    - **Branch**: feat/007-jwt-auth
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
    - **Branch**: feat/043-oauth
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

(`Branch: none` here is an explicit opt-out from auto-branching: this small task will ride on whatever branch picks it up.)

    ### Subtasks
    - [ ] FEAT-044.1: Install PDF library
    - [ ] FEAT-044.2: Export button
