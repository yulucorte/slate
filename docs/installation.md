# Installation

## As a Claude Code plugin (recommended)

```bash
# Using Claude Code marketplace
/plugin marketplace add <usuario>/claude-harness
/plugin install claude-harness@claude-harness
```

Or manually:

```bash
git clone https://github.com/<usuario>/claude-harness ~/.claude/plugins/claude-harness
```

## Initializing a project

```bash
cd ~/my-project
bash ~/.claude/plugins/claude-harness/scripts/install-into-project.sh
bash init.sh
```

Expected output from `init.sh`:

```
[init.sh] OK at 2026-05-03T10:00:00+00:00
```

## Verification

After running `init.sh`, verify:

```bash
ls progress/    # current.md  history.md  subagents/  transcripts/
ls features/    # README.md  backlog.md  in-progress.md  done.md
```

Open Claude Code in the project directory. The SessionStart hook will inject `using-claude-harness` context automatically.

## Uninstallation

claude-harness only touches `progress/`, `features/`, `init.sh`, and `AGENTS.md`. To remove:

```bash
rm -rf progress/ features/ init.sh AGENTS.md
```

The plugin itself can be removed from `~/.claude/plugins/`.
