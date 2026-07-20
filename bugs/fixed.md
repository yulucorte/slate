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
