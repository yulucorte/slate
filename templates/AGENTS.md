# Project protocol

This project uses **Superpowers** + **claude-harness**. Both are loaded at session start.

## State locations

| File | Purpose |
|---|---|
| `progress/current.md` | Live state of in-flight work |
| `progress/history.md` | Append-only changelog (do not edit past entries) |
| `progress/subagents/*.md` | Full reports from each subagent |
| `features/backlog.md` | Desired features, not started |
| `features/in-progress.md` | Active features |
| `features/done.md` | Completed features (FORBIDDEN to edit) |
| `docs/superpowers/specs/` | Design specs (Superpowers default) |
| `docs/superpowers/plans/` | Implementation plans (Superpowers default) |
| `init.sh` | Environment scaffolding and smoke test |

## Mandatory rules (override skills where conflicting)

1. Before any response, the agent must invoke `tracking-progress` (in claude-harness) and `managing-feature-list` if the request implies scope work.
2. After `superpowers:writing-plans` produces a plan, immediately invoke `breaking-down-features` to derive feature entries.
3. After `superpowers:subagent-driven-development` marks a task complete, also invoke `tracking-progress` to persist the report.
4. A feature only moves to `done.md` when ALL subtasks are `[x]` AND `Verified: <date>` is set.
5. Never edit entries in `done.md`. Add a successor with `Supersedes:`.

## How to verify a feature

1. Run the verification method declared in the feature (`playwright`, `manual`, `unit-test`, etc.).
2. Paste the relevant output into the feature's `### Notes` section.
3. Set `Verified: <today>`.
4. Move the feature to `done.md` via `managing-feature-list`.

## Project-specific (fill in)

- TODO(user): describe the project's domain in 2 lines.
- TODO(user): list any project-specific verification commands here.

## Project hooks (claude-harness v0.2.0+)

This project may have `.claude-harness/config.sh` with hook configuration. Notable rules:

- `pre-tool-safety.sh` blocks dangerous git/rm operations. If you see a `[claude-harness:pre-tool-safety] Blocked by rule X` message, do not retry blindly — read the reason and adjust.
- `HARNESS_AUTO_BRANCH=true` means moving a feature to `in-progress.md` triggers `git switch -c`. Don't manually switch first.
- `HARNESS_AUTO_PR=true` means moving a feature to `done.md` opens a PR. Make sure the work is committed and verified first.

Logs live at `progress/hooks.log`. If a hook seems to misbehave, invoke the `verify-harness-hooks` skill.
