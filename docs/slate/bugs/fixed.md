# Fixed bugs

<!-- FORBIDDEN to edit existing entries. If a bug recurs, file a new
     BUG-XXX and reference the earlier one in Notes. -->

## BUG-001: La copia en caché del plugin no trae los hooks de session-lock — la protección no corre
- **Status**: fixed
- **Severity**: high
- **Reported-by**: @felipevillacorte
- **Detected**: 2026-07-19
- **Fixed**: 2026-07-19
- **Where**: `.claude-plugin/plugin.json` (version), caché versionada `~/.claude/plugins/cache/slate-direct/slate/<version>/`
- **Root cause**: FEAT-001 (session-lock) agregó `hooks.json` + scripts `session-*` al repo, pero NO se subió el número de versión del plugin (siguió en `1.2.0`). Claude Code cachea los plugins de marketplace por número de versión y NO vuelve a copiar el source si el número no cambia (confirmado con doc oficial de Claude Code). La caché `1.2.0/`, congelada del 2026-07-06, solo tiene los 3 hooks viejos (session-start, session-end, pre-compact), sin la protección. Las sesiones instaladas por marketplace cargaban esa copia vieja, así que la protección nunca se activó en uso real. La verificación de FEAT-001 pasó porque usó `claude --plugin-dir` (carga el código vivo del path, sin caché) — probó justo la ruta que evita este bug.
- **Fix**: Subir la versión del plugin `1.2.0` → `1.3.0` en `.claude-plugin/plugin.json` + entrada en `CHANGELOG.md`. El cambio de número fuerza a Claude Code a re-copiar el source (con los hooks nuevos) a la caché `1.3.0/`. Requiere que el consumidor corra `claude plugin update` o arranque una sesión nueva para que la nueva versión entre en la caché; no hay comando de "refresh" sin bump de versión.
- **Commit**: 3d1b0d0 (rama `fix/bug-001-plugin-version-bump`)

### Notes
- Evidencia del diagnóstico: caché `1.2.0/hooks/` = 3 scripts viejos; repo dev `hooks/` = 5 eventos con session-lock/guardian/heartbeat/cleanup. `grep -rl <session-id> .git/slate-sessions/` → la sesión afectada nunca tuvo candado (la capa 2 no tenía nada que comparar).
- El fix de código está mergeado, pero la ACTIVACIÓN depende de un paso operativo del consumidor (`claude plugin update` / sesión nueva). No cierra los puntos ciegos de diseño: ver [[BUG-002]].

## BUG-002: El guardián de session-lock solo vigila el NOMBRE de rama al arrancar — no cubre rama construida encima, stash compartido ni merge cross-worktree
- **Status**: fixed
- **Severity**: high
- **Reported-by**: @felipevillacorte
- **Detected**: 2026-07-19
- **Fixed**: 2026-07-19
- **Where**: `hooks/session-guardian.sh`, `hooks/session-lock.sh`, `hooks/session-heartbeat.sh`
- **Root cause**: El diseño de FEAT-001 detectaba colisión solo por igualdad de NOMBRE de rama y solo en SessionStart; el guardián de commit/push comparaba la rama actual contra la rama reclamada al arrancar. Puntos ciegos: (1) dos ramas de nombres distintos, una construida sobre el commit de la otra (caso real: otro proceso ramificó encima de un commit propio y arrastró ese trabajo a producción al mergear su PR) pasaban por debajo del radar; (2) cada tarea legítima crea rama nueva, así que el guardián debía ser permisivo, y permisivo no distinguía "cambié de rama a propósito" de "me cambiaron por debajo"; (3) los worktrees comparten el mismo git-store y el mismo `git stash`; (4) no re-chequeaba colisiones antes de cada escritura git, solo al arrancar.
- **Fix**: Rediseño del guardián (FEAT-002, plugin 1.4.0). El guardián compara la rama/tip ACTUAL de esta sesión contra los candados de OTRAS sesiones vivas en cada operación git sensible (commit/push/merge/rebase/cherry-pick/stash), no contra la foto del arranque. Bloquea (deny) solo ante choque confirmado con un peer vivo; en la duda avisa (additionalContext + systemMessage) y deja pasar. Cierra los 4 agujeros: (1) rama-encima por ancestro del tip vivo ajeno no publicado en la línea principal (session-lock guarda el head SHA y el heartbeat lo mantiene fresco usando el cwd del payload); (2) el falso positivo desaparece porque una sesión sola nunca se bloquea; (3) stash compartido: `git stash pop`/`apply` sin referencia `stash@{n}` explícita y `drop`/`clear` se bloquean con un peer vivo; (4) re-chequeo en cada operación, no solo al arrancar. Tests con git real (repos/commits/ramas/worktrees reales + candados vivos simulados): 13/13 en `scripts/self-test.sh`.
- **Commit**: 894fa70 (rama `feat/feat-002-session-guardian-redesign`)

### Notes
- El incidente real que lo destapó: un proceso paralelo ramificó encima de un commit propio (nombre de rama distinto) y al mergear arrastró el backend a producción antes de tiempo. El nuevo guardián lo bloquea al detectar que el HEAD a integrar (push/merge/rebase) desciende del tip vivo de otra sesión que aún no está en la línea principal.
- Falso positivo de 1.3.0 (bloqueó un commit legítimo de la propia sesión tras un cambio de rama deliberado, observado en vivo el 2026-07-19) resuelto: el guardián ya no compara contra el candado propio del arranque; solo choca con peers vivos ajenos.
- Activación: requiere `claude plugin update` (o sesión nueva) para que la caché sirva 1.4.0 — mismo paso operativo que cualquier cambio de hooks. Ver [[BUG-001]].
- Relacionado con [[BUG-001]] (en la sesión afectada la protección ni siquiera corría) y con [[FEAT-002]].

## BUG-003: `session-start.sh` emite el formato plano — Claude Code descarta TODO el estado de arranque
- **Status**: fixed
- **Severity**: critical
- **Reported-by**: @felipevillacorte
- **Detected**: 2026-08-14
- **Where**: `hooks/session-start.sh:233` (emisión del `additionalContext`)
- **Root cause**: El hook emitía `{"additionalContext": ...}` (formato plano). Claude Code lo ejecuta sin error pero lo DESCARTA en silencio cuando varios plugins cablean `SessionStart` a la vez; solo sobrevive el formato envuelto `{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ...}}`. La competencia es el caso normal, no el raro: Superpowers 6.3.0 cablea `SessionStart` con matcher `startup|clear|compact`, y slate se declara en `plugin.json` como *"Lightweight companion to Superpowers"*. Consecuencia: nada de lo que slate inyecta al arrancar llegaba al agente — índice de in-progress, estado en vuelo, historial reciente, bugs abiertos, conteo de ideas, versión del plugin, contador de `history.md`, truncado de `current.md`. Las cinco capacidades que 1.9.0 añadió dentro de este hook nunca llegaron a uso real. Mismo modo de fallo que `pre-compact.sh` (corre, no falla, nadie lee), que 1.8.0 borró exactamente por ese test. `session-lock.sh:156` ya emitía el formato correcto desde FEAT-001, donde el bug quedó DOCUMENTADO en las notas de `done.md` pero sin corregir aquí por decisión de alcance — 26 días abierto sin que nadie lo notara, porque el síntoma es silencio.
- **Fix**: Emitir el formato envuelto en `session-start.sh`, copiando el de `session-lock.sh:156`. Test de regresión `tests/test-session-start-wrapped-output.sh` (4 aserciones, incluida una que falla si el formato plano reaparece en el fuente). Los dos tests preexistentes que decodificaban la salida (`test-session-start-current-truncate.sh`, `test-session-start-version-history-count.sh`) leían la clave plana y pasaban en verde contra un formato que nunca llegaba a producción: actualizados al envelope. Requiere bump de versión para llegar a uso real (ver BUG-001).
- **Commit**: c666d46
- **Fixed**: 2026-08-14
- **Related feature**: FEAT-001

### Notes
Medición que lo confirmó (no simulada): sesión real de Claude Code con slate + Superpowers instalados, leyendo el transcript `.jsonl` — el bloque de Superpowers (envuelto) aparece como `type=attachment`; el de slate (plano) no aparece nunca, solo como resultado de herramienta cuando el agente leyó el fuente a mano. El hook sí corre y sí produce 1189 bytes: falla la entrega, no la ejecución. Mismo método de verificación que usó FEAT-001 (transcript crudo, no la respuesta del modelo).

Encontrado como subproducto de un debate de diseño sobre otra cosa (relevo Superpowers→Slate), no buscándolo.

## BUG-004: `session-end.sh` ensucia la rama por defecto al drenar un `current.md` ya mergeado
- **Status**: fixed
- **Severity**: high
- **Reported-by**: @felipevillacorte
- **Detected**: 2026-10-18
- **Where**: `hooks/session-end.sh`
- **Root cause**: En el patrón orquestador+worktrees, `CLAUDE_PROJECT_ROOT` es la carpeta principal en `main`, donde `current.md` trae contenido mergeado de ramas de trabajo. El hook lo tomaba por trabajo vivo y lo drenaba a `history.md`, dejando `main` sucio (medido en phlou-app: current −94 / history +102).
- **Fix**: En la rama por defecto (`origin/HEAD`, o `main`/`master`), un `current.md` versionado y sin cambios respecto a `HEAD` no se drena. Con cambios sin commitear o sin versionar sí. `tracking-progress` indica drenar en la rama de trabajo, en el último commit antes del PR. Test: `tests/test-session-end-default-branch.sh`.
- **Commit**: b4bb508
- **Fixed**: 2026-10-18

### Notes
Reportado por la sesión phlou (phlou-app) el 2026-10-18.

## BUG-005: El guardián juzga el `cwd` de la sesión y no la carpeta donde corre git (falso positivo en worktrees)
- **Status**: fixed
- **Severity**: high
- **Reported-by**: @felipevillacorte
- **Detected**: 2026-10-18
- **Where**: `hooks/session-guardian.sh` (reglas 0/1/2, `classify()`)
- **Root cause**: Las reglas 1 y 2 calculaban rama/HEAD en el `cwd` del payload, ignorando `git -C <dir>` y un `cd <dir> &&` previo. Falso positivo constante en worktrees; los agentes lo sorteaban desactivando la protección (`"$(command -v git)"`, scripts).
- **Fix**: `classify()` devuelve el directorio efectivo de cada verbo de integración; las reglas 1/2 lo usan solo si es un worktree del mismo repo (mismo `git-common-dir`). El seguimiento de `cd` se desactiva si el comando no se parte limpio (subshells, comillas partidas, etc.) y la regla 0 evalúa cwd y destino del `cd` (a prueba de fallos). Test: `tests/test-guardian-effective-dir.sh`.
- **Commit**: dd47ade, d1d8498
- **Fixed**: 2026-10-18

### Notes
Reportado por la sesión phlou (phlou-app) el 2026-10-18.

## BUG-006: Los subagentes recrean/borran candados y drenan `current.md`
- **Status**: fixed
- **Severity**: high
- **Reported-by**: @felipevillacorte
- **Detected**: 2026-10-18
- **Where**: `hooks/session-end.sh`, `hooks/session-lock-cleanup.sh`, `hooks/session-heartbeat.sh`
- **Root cause**: Los hooks no distinguían un subagente de la sesión principal. Un subagente podía recrear un candado con su id (que luego bloqueaba git 15 min), borrar el candado del padre al terminar, o drenar `current.md`.
- **Fix**: Con `agent_id` en el payload: `session-end.sh` y `session-lock-cleanup.sh` salen sin hacer nada; `session-heartbeat.sh` solo refresca el mtime de un candado existente. Test: `tests/test-subagent-hooks.sh`.
- **Commit**: 7448794
- **Fixed**: 2026-10-18

### Notes
Reportado por la sesión phlou (phlou-app) el 2026-10-18.

## BUG-007: El resumen de historial al arrancar muestra fragmentos sueltos
- **Status**: fixed
- **Severity**: medium
- **Reported-by**: @felipevillacorte
- **Detected**: 2026-10-18
- **Where**: `hooks/session-start.sh` (`history_tail`)
- **Root cause**: `history_tail` inyectaba las últimas N líneas de `history.md`, que solían ser una viñeta suelta sin contexto.
- **Fix**: `history_blocks N L` inyecta los últimos N bloques con contenido (encabezado `## …` + primeras L líneas). Test: `tests/test-session-start-history-blocks.sh`.
- **Commit**: bb45a7d
- **Fixed**: 2026-10-18

### Notes
Reportado por la sesión phlou (phlou-app) el 2026-10-18.
