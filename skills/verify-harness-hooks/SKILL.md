---
name: verify-harness-hooks
description: Run a health check on claude-harness project hooks. Verifies hooks.json registrations, script executability, config syntax, required CLIs (gh, formatter), log state, and feature format. Use when a hook fails silently, after upgrading, or to audit a fresh install.
---

# Verify claude-harness hooks

This skill produces a table of green/yellow/red checks for the project's hooks installation.

## When to invoke

- After running `install-into-project.sh`
- When a hook seems to misbehave or silently skip
- After upgrading claude-harness
- Before enabling `HARNESS_AUTO_PR=true` or `HARNESS_AUTO_BRANCH=true`

> **Want fix commands, not just a status table?** Invoke the `harness-doctor` skill instead — it runs the same checks plus prints `Fix:` lines.

## What to check

Run each check below. Report status per check with green (✓), yellow (warning), or red (✗). Include the remediation command for any non-green check.

### Checks

1. **hooks.json registrations**
   - `${CLAUDE_PLUGIN_ROOT}/hooks/hooks.json` exists and parses as JSON.
   - All 9 expected hooks registered: session-start, session-end, pre-compact, post-edit-checkpoint, post-edit-format, post-edit-in-progress-watcher, post-edit-done-watcher, pre-tool-safety, stop-notify.

2. **Hook scripts present + executable**
   - Verify each of the 9 hook scripts at `${CLAUDE_PLUGIN_ROOT}/hooks/` exists and has the executable bit set. Same for `${CLAUDE_PLUGIN_ROOT}/hooks/lib/*.sh` and `${CLAUDE_PLUGIN_ROOT}/scripts/harness/*.sh`.

3. **Project config**
   - `.claude-harness/config.sh` exists at project root.
   - `bash -n .claude-harness/config.sh` returns 0 (no syntax errors).
   - If syntax error: show the error and recommend `git restore` or fix manually.

4. **External CLIs (conditional)**
   - If `HARNESS_AUTO_PR=true`: `gh` installed AND `gh auth status` healthy. Otherwise: yellow if not installed.
   - If `HARNESS_FORMATTER=prettier|gofmt|ruff`: corresponding binary in PATH. Otherwise: yellow.
   - `flock` installed (always required for the watcher hooks). If missing: red, remediation: `brew install flock` (macOS) or check that `util-linux` is installed (Linux).

5. **Log state**
   - `progress/hooks.log` exists and is writable. Report size and rotation count.
   - If size approaching `HARNESS_LOG_MAX_BYTES`: yellow with rotation note.

6. **Feature format validity**
   - For each FEAT-XXX in `backlog.md`, `in-progress.md`, `done.md`: verify `Branch:` field exists. List any feature missing the field as yellow (it would break the watchers).

7. **Active safety overrides** (informational, always green)
   - List any `HARNESS_ALLOW_*=true` and `HARNESS_SAFETY_RULES` value so the user sees what's currently allowed.

## Output format

Print a markdown table:

| Check | Status | Detail / Remediation |
|---|---|---|
| hooks.json parses | ✓ | — |
| 9 hooks registered | ✓ | — |
| Hook scripts executable | ✗ | run: `chmod +x $CLAUDE_PLUGIN_ROOT/hooks/*.sh` |
| ... | ... | ... |

End with a one-line summary: `Result: 11/11 checks passed` or similar.

## Implementation notes

- Use `Bash` tool to inspect file presence and `bash -n` for syntax checks.
- Use `Read` tool on hooks.json for parsing.
- Do not modify any files — this is a read-only check.
