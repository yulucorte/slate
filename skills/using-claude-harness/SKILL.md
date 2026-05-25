---
name: using-claude-harness
description: Use when starting any session in a project that contains progress/ or features/ directories. Establishes the protocol for reading current state, updating progress, and respecting the feature list as canonical scope.
---

# Using claude-harness

Loads at SessionStart in projects initialized with claude-harness.

## State files (canonical)

- `progress/current.md` — work in flight. Read at start, update during, drain at end.
- `progress/history.md` — append-only log. Never edit existing entries.
- `features/backlog.md` — desired but not started.
- `features/in-progress.md` — actively being built.
- `features/done.md` — completed. Editing entries here is FORBIDDEN.

## Protocol

1. **Session start**: the hook already injected recent history and active features. Do not re-read those files unless you need detail beyond what was injected.
2. **Before dispatching a subagent**: invoke `tracking-progress` to log the dispatch.
3. **Before marking work done**: invoke `managing-feature-list`. A feature only moves to `done.md` when ALL subtasks are `[x]` AND `Verified: <date>` is set.
4. **Session end**: append the contents of `progress/current.md` to `progress/history.md` under a `## YYYY-MM-DD — <summary>` heading, then clear `current.md`.

## Interop with Superpowers

claude-harness does NOT replace Superpowers.
- `superpowers:brainstorming` → spec in `docs/superpowers/specs/`.
- `superpowers:writing-plans` → plan in `docs/superpowers/plans/`.
- After the plan is approved, invoke `breaking-down-features` to derive entries in `features/backlog.md`.

## Anti-patterns

- DO NOT introduce JSON, YAML, or SQLite alternatives. Markdown is the contract.
- DO NOT edit entries in `done.md`. Create a successor with `Supersedes: FEAT-XXX`.
- DO NOT skip `tracking-progress`. Commit messages are too terse for cross-session recovery.
- DO NOT read all four `features/*.md` files preemptively. Use what the hook injected plus targeted reads.
