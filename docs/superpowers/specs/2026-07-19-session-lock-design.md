# Session lock — diseño

**Fecha**: 2026-07-19
**Feature**: FEAT-001
**Origen**: brief de Felipe en `goalslate.md` (diseño ya decidido por el usuario). Este documento lo formaliza, resuelve el único punto abierto (limpieza de worktrees) y fija el contrato exacto de hooks verificado contra la documentación oficial de Claude Code.

## Problema

Dos sesiones de Claude Code abiertas sobre la MISMA copia de un repo comparten tres cosas de git: la rama activa, el índice (staging area) y el stash. Si ambas sesiones trabajan en paralelo, una puede cambiar de rama, hacer stash, o commitear por debajo de la otra sin que esta se entere. Esto ya causó pérdidas de contexto en el uso real de Slate.

## Arquitectura — dos capas

1. **Candado de sesión** (SessionStart): detección y auto-aislamiento en un worktree. Es la prevención primaria.
2. **Guardián de commit** (PreToolUse sobre `git commit`/`git push`): red de seguridad si la capa 1 falla (por ejemplo, el candado se corrompió, o alguien cambió de rama a mano).

Ambas capas son HOOKS (los ejecuta la máquina), no skills (que solo aconsejan). Ver Gotcha 3 del brief — este es el motivo por el que el enforcement no puede vivir solo en `using-slate`.

## Componentes nuevos

### 1. `hooks/session-lock.sh` (evento `SessionStart`)

Se registra como una segunda entrada bajo el mismo matcher `startup|resume|clear|compact` que ya usa `session-start.sh` (no se toca ese script existente).

Pasos:
1. `LOCK_DIR="$(git rev-parse --git-common-dir)/slate-sessions"` — carpeta compartida entre TODOS los worktrees del mismo repo, porque vive dentro de `.git` y `--git-common-dir` resuelve al `.git` real incluso desde un worktree (Gotcha 1). `mkdir -p` si no existe. Si el cwd no es un repo git, salir en silencio (exit 0) — igual que el resto de hooks de Slate.
2. Recorrer `$LOCK_DIR/*.lock` (JSON, uno por sesión). Para cada uno: si `now - mtime(archivo) > 900s` (15 min, Gotcha 2) → es un candado muerto, se ignora (no se borra activamente para evitar carreras; el reaper natural es "ignorar lo viejo", no "borrar lo viejo").
3. De los candados vivos, ¿alguno declara la misma rama que esta sesión está por usar (`git branch --show-current` en el cwd actual)?
   - **No** → esta sesión reclama la rama: escribe `$LOCK_DIR/<session_id>.lock` con `{"branch": "<rama>", "worktree": "", "started_at": "<iso8601>"}`. Sigue normal.
   - **Sí** → colisión. Crea un worktree aislado:
     - Rama nueva: `slate-session/<primeros 8 chars de session_id>` (git worktree ya prohíbe usar la misma rama en dos worktrees a la vez — esto refuerza "nunca comparten rama activa" con una garantía del propio git, no solo de nuestro script).
     - Ubicación: `"$(dirname "$PROJECT_ROOT")/$(basename "$PROJECT_ROOT").slate-worktrees/<session_id corto>"` — siempre AFUERA del repo (hermano de la carpeta del proyecto), derivado en tiempo real del path real, nunca hardcodeado (Gotcha 4).
     - `git worktree add "$WT_PATH" -b "$BRANCH"` desde la punta de la rama que colisionó.
     - Escribe el candado de ESTA sesión con `{"branch": "<rama nueva>", "worktree": "<WT_PATH>", "started_at": ...}`.
4. Salida: JSON con `additionalContext`. Si hubo colisión, el mensaje le dice explícitamente al agente: "Otra sesión activa en la rama X. Trabajá desde `<WT_PATH>` — `cd` ahí antes de cualquier comando git — hasta que termines." Si no hubo colisión, no agrega nada (silencioso, para no ensuciar el contexto en el caso común).

### 2. `hooks/session-heartbeat.sh` (evento `PostToolUse`, sin matcher = todas las tools)

Un solo `touch "$LOCK_DIR/<session_id>.lock"` si el archivo existe. Si no existe (proyecto sin Slate, o esta sesión nunca reclamó candado), sale al instante. No escribe additionalContext ni bloquea nada — es puramente pasivo, confirmado por el contrato de PostToolUse (no puede bloquear, solo observar).

Costo por llamada: un `stat`/`touch`, despreciable.

### 3. `hooks/session-guardian.sh` (evento `PreToolUse`, matcher `Bash`)

Lee `tool_input.command` del JSON de entrada. Si NO matchea un patrón de `git commit` o `git push` (regex simple sobre el comando), sale de inmediato (`exit 0`, sin output) — no interfiere con ningún otro comando bash.

Si matchea:
1. Lee el candado de esta sesión (`$LOCK_DIR/<session_id>.lock`) para saber qué rama reclamó.
2. Compara contra la rama real (`git branch --show-current` en el `cwd` del payload).
3. Si coinciden → sale limpio, no bloquea.
4. Si NO coinciden → responde:
   ```json
   {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
     "permissionDecisionReason": "La rama activa (<real>) no coincide con la que esta sesión reclamó (<candado>). Alguien cambió de rama por debajo. Commit bloqueado."}}
   ```
   Formato confirmado contra la documentación actual de Claude Code (no el `decision: block` viejo, no exit code 2).

### 4. `hooks/session-lock-cleanup.sh` (evento `SessionEnd`)

Borra únicamente `$LOCK_DIR/<session_id>.lock` (libera la rama reclamada por esta sesión). NO toca el worktree ni la rama `slate-session/*` — quedan en disco para que Felipe los revise, fusione o borre a mano (decisión de Felipe: "dejarla"). Se registra como entrada adicional en el mismo evento `SessionEnd` donde ya vive `session-end.sh`, sin modificar ese script.

## Formato del candado

```json
{"branch": "main", "worktree": "", "started_at": "2026-07-19T10:00:00Z"}
```
- Heartbeat = mtime del archivo (no un campo dentro del JSON) — más simple, y `touch` no requiere reescribir/parsear JSON en cada tool use.
- Nombre de archivo = `<session_id>.lock` (session_id viene del payload de cada hook, confirmado presente en SessionStart/PreToolUse/PostToolUse).

## Manejo de errores

- Cualquier hook sale `exit 0` ante error inesperado (repo no-git, JSON malformado, `git worktree add` falla) — nunca bloquea una sesión por un bug del guardián mismo. Except: el guardián SÍ puede bloquear intencionalmente vía `permissionDecision: deny`, eso no es un error.
- Si `git worktree add` falla (por ejemplo, disco lleno, o ya existe una carpeta con ese nombre), el hook cae a modo "sin aislar" pero avisa fuerte en `additionalContext`: "No pude aislar la sesión — colisión de rama, cuidado."

## Testing

1. **TDD con bats** sobre los 3 scripts activos (lock, heartbeat, guardian): casos con 0/1/2 candados en `$LOCK_DIR`, heartbeat fresco vs. viejo (manipulando mtime con `touch -d`), colisión de rama sí/no.
2. **Worktrees reales**: crear un repo de prueba temporal, agregar un segundo worktree de verdad, escribir un candado desde un lado y leerlo desde el otro — confirma que `--git-common-dir` realmente comparte la carpeta entre worktrees.
3. **Guardián real**: cambiar de rama por debajo del candado reclamado, intentar `git commit`, confirmar bloqueo real (no simulado).
4. **End-to-end con dos sesiones reales de Claude Code** sobre el mismo repo — criterio de aceptación final, lo corre Felipe con mi guía porque requiere dos ventanas de terminal reales.

## Rollback

Plugin aditivo. Para desactivar: quitar las 4 entradas nuevas de `hooks/hooks.json` (o una bandera en settings que las apague). Los candados viven dentro de `.git/slate-sessions/` — descartables, nunca se commitean, no hay nada que revertir en los repos que instalan Slate.

## Fuera de alcance

No se toca ninguna skill ni hook existente de Slate (`session-start.sh`, `session-end.sh`, `pre-compact.sh`, ni las skills `slate:*`). No se agrega enforcement sobre `git stash` en esta iteración — el candado + guardián ya resuelven el caso principal reportado (pisada de rama); stash queda para una iteración futura si se repite el problema.
