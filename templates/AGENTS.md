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
| `bugs/open.md` | Open bugs, being diagnosed or fixed |
| `bugs/fixed.md` | Fixed bugs — NEVER edit |
| `ideas/inbox.md` | Raw captured ideas, not yet triaged |
| `ideas/triaged.md` | Triage decisions — NEVER edit |

## Rules

1. Features move: backlog → in-progress → done. Never skip in-progress.
2. A feature goes to done only when ALL subtasks are `[x]` AND `Verified: <date>` is set.
3. Never edit done.md. Create a new feature with `Supersedes: FEAT-XXX`.
4. Feature IDs (FEAT-XXX) are immutable.
5. After a Superpowers plan is written, derive feature entries via `breaking-down-features`.
6. A bug moves to `bugs/fixed.md` only when `Fix`, `Commit`, and `Fixed: <date>` are all set.
7. Never edit `bugs/fixed.md` or `ideas/triaged.md`. Bugs don't reopen — file a new `BUG-XXX`. Ideas triage decisions are permanent — re-triage produces new log lines, not edits.
8. Capture ideas into `ideas/inbox.md` immediately when raised; don't categorize until `/ideas-triage` runs.

## Project-specific

- TODO(user): describe the project's domain.
- TODO(user): list verification commands.
