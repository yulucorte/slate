# Changelog

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

## v0.1.0 (unreleased)

Initial release.
