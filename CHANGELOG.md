# Changelog

## 0.4.0 — 2026-05-13

### Added
- `consulting-project-map` skill — loaded at SessionStart when `docs/project-map.md` exists. Read-only: surfaces the project's vision, current phase, exit criteria, and ADR conventions without inventing or editing them.
- Template `docs/project-map.md` — single-source-of-truth Markdown for vision, current phase, exit criteria, future phases, and product areas. Installed once per project, idempotent.
- Template `docs/architecture-decisions/README.md` — documents the append-only ADR format (Status / Context / Decision / Consequences, `Supersedes:` for replacements).
- `pre-tool-safety.sh` rule **ADR_EDIT** — blocks Edit/Write/MultiEdit on `docs/architecture-decisions/ADR-*.md` files whose `Status: Accepted` line is present. Permits creating new ADRs (file does not yet exist) and the exact `Status: Accepted` → `Status: Superseded` transition (Edit tool, single-line replacement). Override with `HARNESS_ALLOW_ADR_EDIT=true`.
- `HARNESS_ALLOW_ADR_EDIT=false` default in `hooks/lib/defaults.sh` and the seeded `.claude-harness/config.sh` template.
- `session-start.sh` now injects `docs/project-map.md` (first 200 lines) into `additionalContext` under a `project_map` marker, alongside the `using-claude-harness` skill body. Nothing is added when the file is absent.
- Tests: `test-install-v04.sh` (template copy + idempotency), `test-hook-safety-adr.sh` (4 ADR cases + allow override), `test-session-start-project-map.sh` (presence/absence + JSON shape).

### Notes
- No agents were added. ADRs replace the "architect" role; humans write them, Claude reads them on demand.
- Only `project-map.md` is injected at SessionStart. ADRs are read on demand to keep context small.

## 0.3.0 — 2026-05-11

### Added
- `emit-status.sh` helper that surfaces hook events to stderr (visible to the user) in addition to `progress/hooks.log`.
- `scripts/harness/doctor.sh` — diagnostic script that prints concrete fix commands for failed checks.
- `harness-doctor` skill — invoke when the user asks "what's wrong with harness" or after install.
- `harness-open-pr` skill — manually trigger `pr-open.sh` when `HARNESS_AUTO_PR=false`.
- `harness-create-branch` skill — manually create the feature branch when `HARNESS_AUTO_BRANCH=false`.

### Changed
- `pre-tool-safety.sh`, `post-edit-in-progress-watcher.sh`, `post-edit-done-watcher.sh` now route status to the user via `emit-status.sh` instead of staying silent in the log.
- Watcher INFO messages (when AUTO_* is false) point users at the new skills.

## 0.2.0 — 2026-05-11

### Added
- Project hooks layer: `post-edit-format`, `post-edit-in-progress-watcher`, `post-edit-done-watcher`, `pre-tool-safety`, `stop-notify`.
- Shared library `hooks/lib/`: `defaults.sh`, `load-config.sh`, `log-hook-event.sh`, `acquire-lock.sh`, `read-feature.sh`.
- PR automation scripts: `pr-open.sh`, `pr-merge.sh`, `rollback-feature.sh`.
- Per-project config: `.claude-harness/config.sh`.
- Health check skill: `verify-harness-hooks`.
- Structured log: `progress/hooks.log` with rotation.

### Changed
- `install-into-project.sh` now seeds `.claude-harness/config.sh`, sets executable bits, populates `.gitignore`.
- `scaffolding-environment` skill detects v0.1.0 → v0.2.0 upgrades and asks before creating config.

### Compatibility
- All defaults preserve v0.1.0 behavior. New automations (`HARNESS_AUTO_BRANCH`, `HARNESS_AUTO_PR`) are opt-in.

## 0.1.0 — 2026-05-03

Initial release.
