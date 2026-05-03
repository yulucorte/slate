---
name: scaffolding-environment
description: Use when the user opens a session in a project that lacks progress/ or features/, or when the user asks to set up claude-harness in this project, or when the SessionStart hook reports the project is uninitialized.
---

# Scaffolding the environment

## When to invoke

- Project has no `progress/` or `features/` directories.
- User says "set up harness here", "init this project", or similar.
- User asks how to use claude-harness in a fresh project.

## What to do

1. Run: `bash $(claude-harness-plugin-root)/scripts/install-into-project.sh`
   - This copies templates into the current project: `progress/`, `features/`, `init.sh`, `AGENTS.md`.
   - It is idempotent: existing files are NEVER overwritten.
2. Run `bash init.sh` to validate the environment.
3. Read the just-created `AGENTS.md` and confirm to the user that the protocol is active.
4. If the project already has a `CLAUDE.md` or `AGENTS.md`, do NOT overwrite. Append a section `## claude-harness protocol` referencing `templates/AGENTS.md`.

## What `init.sh` does (in the user's project)

- Creates required directories if missing.
- Verifies tooling (git, bash, jq optional).
- Runs project-specific tests if present (npm test, pytest, cargo test — auto-detected).
- Exits 0 if env is healthy, non-zero if blocked.

## Anti-patterns

- DO NOT overwrite existing files in the user's project under any circumstance.
- DO NOT run `init.sh` if it doesn't exist (means user hasn't installed yet).
