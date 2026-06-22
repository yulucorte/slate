# Changelog

## 1.1.0 — 2026-06-22

SessionStart hook now injects lightweight state instead of full dumps. Measured
against a real project (novateks-improductivos): ~21478 bytes (~5369 tok) →
~789 bytes (~197 tok) on startup, ~326 bytes (~81 tok) on compact/resume.

### Changed (`hooks/session-start.sh`)
- Stops injecting `features/backlog.md` (read on demand via managing-feature-list).
- in-progress injected as an INDEX (one line per FEAT: id + title + status),
  not full blocks.
- Stops `cat`-ing SKILL.md; injects a one-line header pointing at the
  `using-slate` skill (protocol loads via the Skill tool on demand).
- Branches on the SessionStart `source` (read from stdin JSON):
  startup|clear → header + in-progress index + current.md + last 2 history lines;
  compact|resume → in-progress index + last history line only, no header.
- history capped to the last line(s) instead of `tail -30`.

## 1.0.0 — 2026-05-25

Lean rewrite. The harness now does exactly three things: persistent session state, controlled feature movement, and SessionStart context injection.

### Removed (vs 0.5.0)
- All `PostToolUse`, `PreToolUse`, and `Stop` hooks (formatter, safety, checkpoint, watchers, notify).
- Skills: `consulting-project-map`, `harness-create-branch`, `harness-doctor`, `harness-open-pr`, `verify-harness-hooks`, `verifying-features`, `handing-off-session`, `scaffolding-environment`.
- `scripts/harness/` (doctor, pr-open, pr-merge, rollback).
- `scripts/lib/parse-features.sh`, `scripts/lib/checkpoint.sh`, all `hooks/lib/`.
- Config layer (`templates/.slate/`).
- Project map and ADR templates.
- v0.2/v0.4/v0.5 install-time migrations.

### Kept and simplified
- 3 hooks: `SessionStart`, `SessionEnd`, `PreCompact`.
- 4 skills: `using-slate`, `managing-feature-list`, `breaking-down-features`, `tracking-progress`.
- 1 install script that copies templates and exits.
