# Features

This directory is the canonical scope of the project.

- **`backlog.md`** — features we want to build, not yet started.
- **`in-progress.md`** — features being actively worked on.
- **`done.md`** — completed and verified features. **FORBIDDEN to edit.**

See `docs/feature-format.md` (in the claude-harness plugin) for the full format reference.

## Quick example

    ## FEAT-001: User login with email/password
    - **Status**: in_progress
    - **Created**: 2025-11-01
    - **Updated**: 2025-11-02
    - **Spec**: docs/superpowers/specs/2025-11-01-auth-design.md
    - **Plan**: docs/superpowers/plans/2025-11-01-auth.md
    - **Verification**: playwright

    ### Subtasks
    - [x] FEAT-001.1: Login form UI
    - [x] FEAT-001.2: POST /auth/login endpoint
    - [ ] FEAT-001.3: Session cookie + refresh
    - [ ] FEAT-001.4: Playwright e2e green

    ### Notes
    Auth uses JWT in httpOnly cookies. See spec for token rotation policy.
