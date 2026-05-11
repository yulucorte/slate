# Changelog

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
