# In progress

## FEAT-001: Session lock — guardián de sesiones paralelas
- **Status**: in_progress
- **Created**: 2026-07-19
- **Updated**: 2026-07-19
- **Spec**: docs/superpowers/specs/2026-07-19-session-lock-design.md
- **Plan**: docs/superpowers/plans/2026-07-19-session-lock.md
- **Branch**: feat/feat-001-session-lock
- **Verification**: integration-test

### Subtasks
- [x] FEAT-001.1: session-lock.sh claim path
- [x] FEAT-001.2: session-lock.sh stale-lock reaping test
- [x] FEAT-001.3: session-lock.sh colisión → aislamiento en worktree (+ fix symlinks macOS)
- [x] FEAT-001.4: session-heartbeat.sh
- [x] FEAT-001.5: session-guardian.sh
- [x] FEAT-001.6: session-lock-cleanup.sh
- [x] FEAT-001.7: cablear hooks en hooks.json
- [ ] FEAT-001.8: verificación real con dos sesiones de Claude Code

### Notes
Dos capas: candado de sesión (SessionStart/PostToolUse/SessionEnd, en `$(git rev-parse --git-common-dir)/slate-sessions/`) + guardián de commit (PreToolUse sobre Bash). TTL de heartbeat 900s (15 min). Worktree de aislamiento vive fuera del repo (`<repo>.slate-worktrees/<8-char-session-id>`), se deja en disco al cerrar sesión (decisión de Felipe: no auto-borrar). 13/13 tests unitarios en `scripts/self-test.sh` en verde. Falta la prueba de aceptación real (FEAT-001.8).
