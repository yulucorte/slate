# Session guardian redesign — diseño

**Fecha**: 2026-07-19
**Feature**: FEAT-002 (sucede a FEAT-001)
**Cierra**: BUG-002
**Origen**: incidente real en un proyecto que usa Slate (una sesión paralela ramificó por encima del commit de otra y lo arrastró a producción al mergear su PR) + falso positivo del guardián observado en vivo el 2026-07-19.

## Problema

FEAT-001 dejó un guardián que detecta colisión SOLO por igualdad de NOMBRE de rama y SOLO en `SessionStart`; el guardián de commit/push compara la rama actual contra la rama que la sesión reclamó al arrancar. Eso deja cuatro puntos ciegos (BUG-002):

1. **Rama construida encima**: dos ramas con nombres distintos, una creada sobre el commit de la otra, pasan por debajo del radar. Es el caso que causó el incidente real: otra sesión ramificó sobre un commit vivo ajeno y al mergear su PR arrastró ese trabajo a producción.
2. **No distingue intención**: cada tarea legítima crea una rama nueva, así que el guardián tiene que ser permisivo; pero permisivo no distingue "cambié de rama a propósito" de "me cambiaron por debajo". El 2026-07-19 el guardián bloqueó un commit legítimo de la propia sesión que arreglaba BUG-001 (falso positivo).
3. **Stash compartido**: los worktrees comparten el mismo git-store y el mismo `git stash`; dos ramas en carpetas distintas igual se pisan en el stash.
4. **Solo chequea al arrancar**: la colisión se evalúa una vez, en `SessionStart`, nunca antes de cada escritura git.

## Decisiones de diseño

- **Filosofía "frena solo si está seguro"**: el guardián BLOQUEA (`deny`) solo ante un choque CONFIRMADO con otra sesión VIVA. Ante sospecha que no puede confirmar, AVISA y deja pasar (no vuelve a repetir el falso bloqueo de #2).
- **Reencuadre central**: el guardián compara la rama/tip ACTUAL de esta sesión contra los candados de OTRAS sesiones vivas, en CADA operación git sensible — no contra una foto vieja de su propio arranque. Esto convierte el candado propio en un espejo veraz de lo que esta sesión hace (no en una jaula que la atrapa), y de un solo golpe resuelve #2 (solo choca con vivos ajenos, no consigo mismo) y #4 (se evalúa antes de cada operación, no solo al arrancar).

## Formato del candado (extendido)

Antes: `{"branch": "...", "worktree": "...", "started_at": "..."}`
Ahora se agrega el tip (SHA de HEAD) para poder detectar la rama-encima:

```json
{"branch": "feat/x", "worktree": "", "head": "<sha>", "started_at": "2026-07-19T10:00:00Z"}
```

Compatibilidad: un candado viejo sin `head` se trata como `head` vacío; nunca rompe el parseo (los agujeros que dependen de `head` simplemente no disparan para candados sin tip, lo cual es seguro).

## Componentes

### 1. `hooks/session-lock.sh` (SessionStart) — cambio menor
Escribe también `head = git rev-parse HEAD` al crear el candado (al reclamar la rama o al aislarse en worktree). La detección de colisión al arranque sigue igual (por nombre de rama) — el caso rama-encima se materializa después del arranque y lo cubre el guardián.

### 2. `hooks/session-guardian.sh` (PreToolUse, matcher Bash) — rediseño central
Intercepta operaciones git sensibles: `commit`, `push`, `merge`, `rebase`, `cherry-pick`, `stash`. Para cada una:

1. Resuelve `SESSION_ID`, `cwd` (del payload), `GIT_COMMON_DIR`. Lee la rama y el tip ACTUALES en vivo (`git branch --show-current`, `git rev-parse HEAD`) en el `cwd` real (funciona incluso si la sesión trabaja en un worktree).
2. Lee TODOS los candados vivos (TTL 900s por mtime) EXCEPTO el propio.
3. **Regla misma-rama (confirmada)**: si algún candado vivo ajeno declara la MISMA rama actual → `deny` para commit/push/merge/rebase (dos sesiones en la misma rama se pisan índice y rama).
4. **Regla rama-encima (confirmada)** — para push/merge/rebase/cherry-pick: para cada candado vivo ajeno `L` con `L.head` no vacío, si `L.head` es ancestro de mi HEAD y `L.head != HEAD` y `L.head` NO está ya en la línea principal (`main`/`master`/`origin/HEAD`), entonces mi rama se apoya en trabajo vivo ajeno no publicado → integrarla lo arrastraría → `deny`. Si no hay línea principal detectable para confirmar, se degrada a AVISO (no bloquea) por la filosofía "frena solo si seguro".
5. **Regla stash compartido** — si hay ≥1 candado vivo ajeno: `git stash pop`/`git stash apply` SIN referencia explícita `stash@{n}` → `deny` (podría sacar el stash de otra sesión); `git stash drop`/`git stash clear` → `deny` (destructivo sobre el cajón compartido); `git stash`/`git stash push` → AVISO (el cajón es compartido, confirmá).
6. Si nada bloquea, sale limpio (`exit 0`) y deja pasar el comando.

Mecanismos de salida (contrato de PreToolUse confirmado contra la doc oficial de Claude Code):
- **Bloqueo**: `hookSpecificOutput` con `permissionDecision: "deny"` y `permissionDecisionReason` (mismo formato ya verificado en vivo en FEAT-001).
- **Aviso**: NO bloquea ni auto-aprueba. Emite `additionalContext` dentro de `hookSpecificOutput` (se inyecta al modelo) + `systemMessage` de nivel superior (visible a Felipe), SIN `permissionDecision`, de modo que el comando siga el flujo de permisos normal. Se evita a propósito `permissionDecision: "allow"`, porque saltaría el sistema de permisos del usuario.

`cwd` viene en el payload tanto de PreToolUse como de PostToolUse (confirmado), así que ambos hooks leen la rama/tip del directorio real de trabajo (soporta sesiones aisladas en worktree).

### 3. `hooks/session-heartbeat.sh` (PostToolUse) — cambio menor
Además de refrescar la mtime (`touch`, liveness), actualiza el `branch`+`head` del candado propio al estado real actual (mejor esfuerzo, usando el `cwd` del payload si está disponible). Así el espejo que leen las OTRAS sesiones para detectar rama-encima queda fresco tras cada tool (en particular, justo después de un commit). Escritura atómica (temp + `mv`) para no competir con lecturas.

### 4. `hooks/session-lock-cleanup.sh` (SessionEnd) — sin cambios
Sigue borrando solo el candado propio.

## Manejo de errores
Todo hook sale `exit 0` ante cualquier error inesperado (repo no-git, JSON malformado, git falla) — nunca traba una sesión por un bug del propio guardián. La única salida bloqueante es el `deny` intencional.

## Testing
Tests unitarios con git REAL (repos temporales, commits reales, ramas construidas encima reales, worktrees reales) + simulación de múltiples candados vivos escribiéndolos a mano en `$GIT_COMMON_DIR/slate-sessions/` (mismo patrón que los tests de FEAT-001). Casos nuevos:
- rama-encima: candado ajeno vivo con tip `C` en su rama; esta sesión en otra rama con HEAD descendiente de `C` no publicado en main → push/merge denegado; y el caso legítimo (ambas ramas desde main, sin descendencia) → permitido.
- falso positivo resuelto: sesión sola que cambia de rama y commitea → NO se bloquea (no hay candado ajeno vivo en esa rama).
- stash compartido: con candado ajeno vivo, `git stash pop` genérico → denegado; sin candado ajeno → permitido.
Se conservan verdes los tests de FEAT-001. El corredor es `scripts/self-test.sh`.

La integración con Claude Code (que el hook se dispara y el `deny` llega al modelo) NO cambia respecto de FEAT-001, donde ya se verificó en vivo con dos sesiones reales; por eso FEAT-002 se verifica con git real a nivel de lógica, sin repetir la corrida de dos procesos reales.

## Fuera de alcance
No se toca ninguna skill ni hook ajeno al guardián (`session-start.sh`, `session-end.sh`, `pre-compact.sh`, skills `slate:*`). El heartbeat basado en "el proceso existe" (en vez de solo mtime) se evaluó y se deja fuera: desde un hook no hay acceso fiable al PID de la sesión; el TTL de 900s sigue siendo el reaper.

## Rollback
Aditivo sobre FEAT-001. Revertir el commit de FEAT-002 devuelve el guardián al comportamiento 1.3.0. Los candados viven en `.git/slate-sessions/` (descartables, nunca se commitean).
