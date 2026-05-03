# Day-to-day workflow

## Starting a new project

1. Install the plugin: `git clone ... ~/.claude/plugins/claude-harness`
2. In your new project: `bash ~/.claude/plugins/claude-harness/scripts/install-into-project.sh`
3. Run `bash init.sh` — verify it prints `[init.sh] OK`.
4. Commit: `git add progress/ features/ AGENTS.md init.sh && git commit -m "chore: add claude-harness scaffolding"`
5. Open Claude Code. The `using-claude-harness` protocol is now active.

## Starting a session

The SessionStart hook automatically:

- Runs `init.sh` and appends output to `progress/history.md`.
- Injects the last 30 lines of `history.md` under `## Recent history`.
- Injects all of `progress/current.md` under `## In flight`.
- Injects the first 10 active features under `## Active features`.

You don't need to manually read these files — they're already in context.

## Receiving a new requirement

1. Invoke `superpowers:brainstorming` → produces spec in `docs/superpowers/specs/`.
2. Invoke `superpowers:writing-plans` → produces plan in `docs/superpowers/plans/`.
3. Invoke `breaking-down-features` → creates FEAT-XXX entries in `features/backlog.md`.
4. Review the proposed features with the user before writing them if there are more than 3.

## Working on a feature

1. Invoke `managing-feature-list` to move the feature from `backlog.md` to `in-progress.md`.
2. Invoke `superpowers:subagent-driven-development` to dispatch subagents per task.
3. Before each subagent dispatch, invoke `tracking-progress` to log it in `progress/current.md`.
4. After each subagent returns, invoke `tracking-progress` to write the full report to `progress/subagents/<task>-STATUS.md`.
5. As subtasks complete, update `[x]` in the feature entry and update `Updated:`.
6. When ALL subtasks are `[x]`:
   - Run the declared verification method.
   - Paste the output into the feature's `### Notes` section.
   - Set `Verified: <today>`.
   - Invoke `managing-feature-list` to move to `done.md`.

## Ending a session

1. Invoke `handing-off-session` (or just close the session — the SessionEnd hook handles it automatically).
2. The hook drains `current.md` into `history.md` and commits everything.

## Recovering context in a new session

The SessionStart hook injects everything you need. But if you need more:

- `progress/history.md` — full changelog. Read the last N lines.
- `features/in-progress.md` — what's actively being worked on.
- `progress/subagents/` — full reports from previous subagents.
