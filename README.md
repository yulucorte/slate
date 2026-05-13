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

For a deeper architectural snapshot (state, file roles, dependencies, gaps), see [docs/STATE-OF-HARNESS.md](docs/STATE-OF-HARNESS.md). A diagram of the plugin/user-project split lives in [docs/assets/claude-harness-overview.excalidraw](docs/assets/claude-harness-overview.excalidraw) (Excalidraw source — open with <https://excalidraw.com> to view); the ASCII reproduction is in [STATE-OF-HARNESS.md §2](docs/STATE-OF-HARNESS.md#2-architecture-ascii). See [docs/contributing.md](docs/contributing.md#regenerating-the-architecture-diagram) for how to regenerate it.

### Skills (11)

| Skill | Trigger |
|---|---|
| `using-claude-harness` | Meta-skill loaded at SessionStart; establishes the protocol for reading state and respecting `features/` as canonical scope |
| `tracking-progress` | Dispatching/receiving a subagent, starting/finishing a task, or user asks "where are we" — maintains `progress/current.md` + `history.md` |
| `managing-feature-list` | Defining new scope, marking a task complete, moving features between `backlog/in-progress/done` |
| `scaffolding-environment` | Session opened in a project that lacks `progress/` or `features/`, or user asks to set up the harness |
| `handing-off-session` | End of session, before `/clear` or `/compact` — drains `current.md` and writes a session summary |
| `breaking-down-features` | After a Superpowers plan is approved, or user describes new scope — translates plans into structured `FEAT-XXX` entries with subtasks |
| `consulting-project-map` | Loaded at SessionStart when `docs/project-map.md` exists — surfaces vision, current phase, exit criteria, and ADR conventions as read-only context |
| `harness-doctor` | User asks to "diagnose harness", or after install — runs `scripts/harness/doctor.sh` and reports `✓/!/✗` per check |
| `harness-open-pr` | "Open PR for FEAT-X" when `HARNESS_AUTO_PR=false` — wraps `scripts/harness/pr-open.sh` |
| `harness-create-branch` | "Create branch for FEAT-X" when `HARNESS_AUTO_BRANCH=false` — reads the feature's `Branch:` field and runs `git switch -c` |
| `verify-harness-hooks` | After install or upgrade, before enabling `AUTO_*`, or a hook is misbehaving — read-only audit of `hooks.json`, scripts, config, and recent log |

### Hooks (9 across 6 events)

Source of truth: [hooks/hooks.json](hooks/hooks.json).

| Hook | Event | Matcher | Effect |
|---|---|---|---|
| `session-start.sh` | SessionStart | `startup\|resume\|clear\|compact` | Injects last 30 history lines, `current.md`, and first 10 active features into context; runs `init.sh` if present |
| `session-end.sh` | SessionEnd | — | Drains non-empty `current.md` into `history.md`, resets `current.md`, auto-commits `progress/` + `features/` |
| `pre-compact.sh` | PreCompact | `auto\|manual` | Snapshots the live transcript into `progress/transcripts/<epoch>.snap`, logs the compaction |
| `pre-tool-safety.sh` | PreToolUse | — (all tools) | Blocks `rm -rf $HOME`, `git push --force` to main/master, `git reset --hard`, and edits to `.claude-harness/config.sh`. Each rule overrideable via `HARNESS_ALLOW_*=true`. Exits 2 on block |
| `post-edit-checkpoint.sh` | PostToolUse | `Edit\|Write\|MultiEdit` | Auto-commits edits that touch `progress/` or `features/` |
| `post-edit-format.sh` | PostToolUse | `Edit\|Write\|MultiEdit` | Runs `HARNESS_FORMATTER` (prettier/gofmt/ruff/none) on supported extensions; skips `features/`, `progress/`, `.claude-harness/` |
| `post-edit-in-progress-watcher.sh` | PostToolUse | `Edit\|Write\|MultiEdit` | Only acts when `features/in-progress.md` was edited. Detects new `FEAT-NNN` via snapshot diff; creates the declared branch (`HARNESS_AUTO_BRANCH=true`) or emits a `suggest` line |
| `post-edit-done-watcher.sh` | PostToolUse | `Edit\|Write\|MultiEdit` | Only acts when `features/done.md` was edited. For each new FEAT, opens a PR (`HARNESS_AUTO_PR=true`) or emits a `suggest` line |
| `stop-notify.sh` | Stop | — | OS notification when Claude finishes a turn (osascript on macOS, notify-send on Linux). 30s per-project debounce |

## Coexistence with Superpowers

Superpowers handles **brainstorming → planning → subagent execution**. claude-harness handles **persistent state → feature tracking → session scaffolding**. They compose without conflict: Superpowers writes to `docs/superpowers/`, claude-harness writes to `progress/` and `features/`. See [docs/interop-with-superpowers.md](docs/interop-with-superpowers.md).

## License

MIT
