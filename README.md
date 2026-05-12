# claude-harness

Markdown-only project memory for Claude Code agents. Use alongside Superpowers.

## Why

Superpowers gives Claude Code powerful brainstorming, planning, and subagent execution skills. But three gaps remain between sessions:

1. No persistent state: there's no `progress/current.md` tracking what's in-flight or `progress/history.md` logging what happened.
2. No canonical feature list: no structured backlog, in-progress, or done tracking with verification requirements.
3. No session scaffolding: no equivalent of `init.sh` to validate the environment at startup.

claude-harness fills those gaps without replacing Superpowers.

## Install

```bash
# As a Claude Code plugin (recommended)
/plugin marketplace add <usuario>/claude-harness
/plugin install claude-harness@claude-harness

# In a specific project (installs templates)
bash ~/.claude/plugins/claude-harness/scripts/install-into-project.sh
```

See [docs/installation.md](docs/installation.md) for full details.

## What it adds

### Skills

| Skill | Purpose |
|---|---|
| `using-claude-harness` | Meta-skill: loads at SessionStart, establishes the protocol |
| `tracking-progress` | Logs subagent dispatches and reports to `progress/` |
| `managing-feature-list` | Moves features between backlog/in-progress/done |
| `scaffolding-environment` | Initializes a project that hasn't been set up yet |
| `handing-off-session` | Drains `current.md` into `history.md` at session end |
| `breaking-down-features` | Translates plans into FEAT-XXX entries |
| `harness-doctor` | Diagnoses install state and prints concrete fix commands for any failed check |
| `harness-open-pr` | Manually triggers `pr-open.sh` for a feature when `HARNESS_AUTO_PR=false` |
| `harness-create-branch` | Manually creates the git branch declared in a feature's `Branch:` field when `HARNESS_AUTO_BRANCH=false` |

### Hooks

| Hook | Trigger | Effect |
|---|---|---|
| `session-start.sh` | SessionStart | Injects history, current work, active features into context |
| `session-end.sh` | SessionEnd | Drains current.md → history.md, auto-commits |
| `pre-compact.sh` | PreCompact | Snapshots transcript, logs compaction event |
| `post-edit-checkpoint.sh` | PostToolUse (Edit/Write) | Auto-commits edits to progress/ or features/ |

## Coexistence with Superpowers

Superpowers handles **brainstorming → planning → subagent execution**. claude-harness handles **persistent state → feature tracking → session scaffolding**. They compose without conflict: Superpowers writes to `docs/superpowers/`, claude-harness writes to `progress/` and `features/`. See [docs/interop-with-superpowers.md](docs/interop-with-superpowers.md).

## License

MIT
