# Project protocol

This project uses **Superpowers** + **slate**.

## State files

| File | Purpose |
|---|---|
| `progress/current.md` | In-flight work (updated during session, drained at end) |
| `progress/history.md` | Append-only session log |
| `features/backlog.md` | Not started |
| `features/in-progress.md` | Active work |
| `features/done.md` | Completed — NEVER edit |

## Rules

1. Features move: backlog → in-progress → done. Never skip in-progress.
2. A feature goes to done only when ALL subtasks are `[x]` AND `Verified: <date>` is set.
3. Never edit done.md. Create a new feature with `Supersedes: FEAT-XXX`.
4. Feature IDs (FEAT-XXX) are immutable.
5. After a Superpowers plan is written, derive feature entries via `breaking-down-features`.

## Project-specific

- TODO(user): describe the project's domain.
- TODO(user): list verification commands.
