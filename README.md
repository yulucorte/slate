# slate

Markdown-only persistent state and feature tracking for [Claude Code](https://claude.ai/code). Lightweight companion to [Superpowers](https://github.com/obra/superpowers).

## Why

Superpowers gives Claude great working habits within a session: brainstorming → spec → plan → TDD execution → review. But it does not solve:

- **Cross-session state** — what was the agent doing yesterday?
- **Canonical feature scope** — which work is actually committed to, and is it actually done?
- **Context at session start** — without re-reading the whole repo on each `/clear` or compact.

slate fills exactly those three gaps. Nothing more.

## Install

```bash
# Once, per Claude Code install:
/plugin install yulucorte/slate

# Once, per project:
bash ~/.claude/plugins/cache/.../slate/scripts/install-into-project.sh
```

The install script copies templates into the current project. It is idempotent and never overwrites existing files.

## What it creates in your project

| Path | Purpose |
|---|---|
| `AGENTS.md` | Protocol the agent reads at session start |
| `init.sh` | Runs on every SessionStart to refresh `progress/codebase-map.md` |
| `progress/current.md` | In-flight work for the current session |
| `progress/history.md` | Append-only session log |
| `progress/subagents/` | One file per dispatched subagent |
| `features/backlog.md` | Not started |
| `features/in-progress.md` | Active work |
| `features/done.md` | Completed — never edit |
| `bugs/open.md` | Open bugs |
| `bugs/fixed.md` | Fixed bugs — never edit |
| `ideas/inbox.md` | Raw captured ideas |
| `ideas/triaged.md` | Idea triage decisions — never edit |

## Flow

1. **Brainstorm** with `superpowers:brainstorming`. Spec goes to `docs/superpowers/specs/`.
2. **Plan** with `superpowers:writing-plans`. Plan goes to `docs/superpowers/plans/`.
3. **Derive features** with `breaking-down-features`. Entries land in `features/backlog.md` or `features/in-progress.md`.
4. **Execute** with `superpowers:subagent-driven-development`. Each dispatch is logged by `tracking-progress`.
5. **Done** moves a feature to `done.md` only when ALL subtasks are `[x]` AND `Verified: <date>` is set.
6. **Bugs** are tracked independently via `tracking-bugs`: reported to `bugs/open.md`, moved to `bugs/fixed.md` once `Fix`/`Commit`/`Fixed:` are set.
7. **Ideas** raised mid-session land in `ideas/inbox.md` via `managing-ideas` (or `/idea`), with no friction. Running `/ideas-triage` groups them by area, and promotes selected ones into `features/backlog.md` via `breaking-down-features`.

## Philosophy

- **Markdown only.** No JSON, YAML, or SQLite state files. Anything the agent writes is anything you can `grep`.
- **Append-only `done.md`.** Edits there are forbidden. Successors carry a `Supersedes: FEAT-XXX` line.
- **Immutable FEAT IDs.** Once assigned, never renumber.
- **3 hooks, 4 skills.** If you cannot justify a new one in one sentence, it does not belong here.

## License

MIT — see [LICENSE](LICENSE).
