---
name: using-claude-harness
description: Use when starting any session in a project that contains progress/ or features/ directories. Establishes the protocol for reading current state, updating progress, and respecting the feature list as canonical scope.
---

# Using claude-harness

This skill loads at SessionStart in projects that have been initialized with claude-harness.

## State files (canonical, do not duplicate elsewhere)

- `progress/current.md` — work in flight. Read at session start, update during session, drain at session end.
- `progress/codebase-map.md` — auto-generated structural map. Consult before running `find` or `ls -R`. Regenerates each `init.sh` run; do not edit manually.
- `progress/history.md` — append-only log. Never edit existing entries.
- `features/backlog.md` — desired but not started.
- `features/in-progress.md` — actively being built.
- `features/done.md` — completed and verified. Editing entries here is FORBIDDEN.

## Protocol (mandatory, no exceptions)

1. **At session start**: read the SessionStart hook output. It already injected recent history and active features. Do not re-read those files unless you need details beyond what was injected.
2. **Before dispatching a Superpowers subagent**: invoke `tracking-progress` to log the dispatch.
3. **Before marking any task as done**: invoke `managing-feature-list` to update the feature's subtask state. A feature only moves to done.md when ALL subtasks are checked AND a verification entry exists.
4. **WIP limit**: `features/in-progress.md` must have at most 1 feature. Before moving backlog → in-progress, count active features and warn if ≥ 1 (see managing-feature-list skill). Before moving in-progress → done, remind user to merge and delete the branch.
5. **At session end**: invoke `handing-off-session` to drain current.md into history.md.

## Interop with Superpowers

claude-harness does NOT replace Superpowers. The flow is:
- `superpowers:brainstorming` produces a spec → still goes to `docs/superpowers/specs/`.
- `superpowers:writing-plans` produces a plan → still goes to `docs/superpowers/plans/`.
- AFTER the plan is written, invoke `breaking-down-features` to derive feature entries in `features/backlog.md` (or `in-progress.md` if work starts immediately).
- During `superpowers:subagent-driven-development`, after each subagent returns, invoke `tracking-progress` to persist the report.

## Anti-patterns

- DO NOT read all four `features/*.md` files preemptively. Use only what the SessionStart hook injected, plus targeted reads.
- DO NOT introduce JSON, YAML, or SQLite alternatives. Markdown is the contract.
- DO NOT skip `tracking-progress` because "the commit message has it". Commits are too terse for cross-session recovery.
- DO NOT edit entries in `done.md`. Create a new feature with `Supersedes: FEAT-XXX` instead.
- DO NOT move a second feature to in-progress.md without warning the user there is already one active.
- DO NOT write the `Branch:` field without proposing the auto-suggested name and getting user confirmation.
- DO NOT move a feature to done.md without confirming the user has merged and deleted the branch (unless Branch: none).
