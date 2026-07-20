# In progress

## FEAT-002: Session guardian redesign — cubrir los puntos ciegos de BUG-002
- **Status**: in-progress
- **Created**: 2026-07-19
- **Updated**: 2026-07-19
- **Spec**: docs/superpowers/specs/2026-07-19-session-guardian-redesign-design.md
- **Plan**: inline en el spec (implementación directa por subtareas)
- **Branch**: feat/feat-002-session-guardian-redesign
- **Verification**: unit (git real: commits/ramas/worktrees reales + candados vivos simulados)
- **Verified**: pending
- **Bug**: BUG-002

### Subtasks
- [ ] FEAT-002.1: session-lock.sh registra el tip (head SHA) en el candado
- [ ] FEAT-002.2: session-guardian.sh — reencuadre a candados vivos ajenos (arregla falso positivo #2 + re-chequeo continuo #4)
- [ ] FEAT-002.3: session-guardian.sh — detección rama-encima por ancestro de tip (agujero #1)
- [ ] FEAT-002.4: session-guardian.sh — protección del stash compartido (agujero #3)
- [ ] FEAT-002.5: session-heartbeat.sh mantiene branch+head del candado fresco (usa cwd del payload)
- [ ] FEAT-002.6: tests con git real (rama-encima, falso positivo resuelto, stash) verdes en self-test
- [ ] FEAT-002.7: bump plugin 1.3.0→1.4.0 + CHANGELOG (lección BUG-001)
- [ ] FEAT-002.8: cerrar BUG-002 en el tracker (open→fixed)

### Notes
Sucede a FEAT-001; cierra BUG-002. Reencuadre central: el guardián compara la rama/tip ACTUAL de esta sesión contra los candados de OTRAS sesiones vivas en cada operación git sensible (commit/push/merge/rebase/cherry-pick/stash), no contra una foto del arranque; el candado propio pasa a ser un espejo veraz (lo refresca el heartbeat), no una jaula. Filosofía "frena solo si está seguro": bloquea (deny) solo ante choque confirmado con sesión viva; en la duda avisa (additionalContext + systemMessage) y deja pasar. Nada de skills ni hooks ajenos al guardián.
