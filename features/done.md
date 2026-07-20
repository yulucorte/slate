# Done

<!-- FORBIDDEN to edit existing entries. Create a successor with Supersedes: FEAT-XXX. -->

## FEAT-001: Session lock — guardián de sesiones paralelas
- **Status**: done
- **Created**: 2026-07-19
- **Updated**: 2026-07-19
- **Spec**: docs/superpowers/specs/2026-07-19-session-lock-design.md
- **Plan**: docs/superpowers/plans/2026-07-19-session-lock.md
- **Branch**: feat/feat-001-session-lock
- **Verification**: integration-test
- **Verified**: 2026-07-19

### Subtasks
- [x] FEAT-001.1: session-lock.sh claim path
- [x] FEAT-001.2: session-lock.sh stale-lock reaping test
- [x] FEAT-001.3: session-lock.sh colisión → aislamiento en worktree (+ fix symlinks macOS)
- [x] FEAT-001.4: session-heartbeat.sh
- [x] FEAT-001.5: session-guardian.sh
- [x] FEAT-001.6: session-lock-cleanup.sh
- [x] FEAT-001.7: cablear hooks en hooks.json
- [x] FEAT-001.8: verificación real con dos sesiones de Claude Code

### Notes
Dos capas: candado de sesión (SessionStart/PostToolUse/SessionEnd, en `$(git rev-parse --git-common-dir)/slate-sessions/`, resuelto con `pwd -P` para sobrevivir symlinks tipo /var→/private/var de macOS) + guardián de commit (PreToolUse sobre Bash). TTL de heartbeat 900s (15 min). Worktree de aislamiento vive fuera del repo (`<repo>.slate-worktrees/<8-char-session-id>`), se deja en disco al cerrar sesión (decisión de Felipe: no auto-borrar).

Verificado 2026-07-19 con DOS sesiones reales de `claude` (no simuladas): sesión A reclama la rama `main`; sesión B, arrancada en paralelo sobre el mismo repo, es detectada, aislada en worktree separado (`slate-session/<id>`), y el aviso realmente llega al modelo (confirmado leyendo el transcript .jsonl, no solo la respuesta de la sesión). Sesión aparte: guardián bloquea un `git commit` real cuando la rama activa cambió por debajo — confirmado con el campo `permission_denials` del output y con que el commit nunca aparece en `git log`.

Bug real encontrado y corregido durante la verificación real: el formato plano `{"additionalContext": ...}` (usado también por el `session-start.sh` preexistente) se ejecuta sin error pero Claude Code lo descarta silenciosamente cuando compiten varios hooks de SessionStart de distintos plugins — solo sobrevive el formato envuelto `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ...}}`. `session-lock.sh` ya usa el formato correcto. `session-start.sh` no se tocó (fuera del alcance del guardián) pero podría tener el mismo problema en la práctica — reportado a Felipe, no corregido por decisión de alcance.

13/13 tests unitarios en `scripts/self-test.sh` en verde (incluye 6 archivos de test nuevos para este guardián). Cero rutas hardcodeadas (verificado por grep). Sin regresiones en skills/hooks preexistentes.
