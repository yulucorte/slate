# Slate 1.10.0 — hallazgos de phlou-app (2026-08-14 → 2026-10-18)

## Intención

Slate existe para dar **trazabilidad y orden** al trabajo de agentes (features,
bugs, ideas, progreso) **gastando pocos tokens y pocos minutos de CI**. El uso
real en phlou-app desde 1.9.1 (2026-08-14) mostró que varias piezas hacen lo
contrario: ensucian `main`, obligan a PRs de solo-docs, bloquean commits
legítimos (y empujan a los agentes a *saltarse* el guardián), repiten IDs y
obligan a mover tarjetas a mano. 1.10.0 corrige eso sin añadir conceptos nuevos.

Fuente: informe de la sesión `phlou` del 2026-10-18 y sus memorias en
`~/.claude/projects/-Users-felipevillacorte-Desktop-Phlou-SaaS-phlou-app/memory/`
(`colision-de-ids-…`, `session-guardian-falso-positivo-worktree`,
`session-guardian-lock-fantasma-subagente`, `trampas-reinicio-subagente-…`).
phlou-app usa slate 1.9.1, así que todo sigue vigente.

## Metas

1. **BUG-004 — el cierre no ensucia la rama principal.** `hooks/session-end.sh`
   drena `current.md → history.md` en `CLAUDE_PROJECT_ROOT`, que en el patrón
   orquestador+worktrees es la carpeta principal en `main`. Ahí `current.md`
   trae contenido *mergeado* de ramas de trabajo, el hook lo cree trabajo vivo
   y deja `main` sucio (medido hoy: current −94, history +102).
   - Si la rama de esa carpeta es la rama por defecto (`main`/`master`, o la que
     apunta `origin/HEAD`) **y `current.md` no tiene cambios sin commitear**
     respecto a `HEAD` (su contenido vino de commits mergeados, no de esta
     sesión) → **no escribe nada**. Si en la rama por defecto `current.md` sí
     tiene cambios sin commitear o no está versionado, es trabajo de esta
     sesión (quien trabaja directo en `main`) y se drena como siempre. En
     cualquier otra rama, comportamiento actual.
   - `tracking-progress` dice explícitamente: el drenaje de `current.md` a
     `history.md` se hace **en la rama de trabajo, en el último commit antes de
     abrir el PR**, para que el cierre viaje con el PR de código (cero PRs de
     solo-docs, cero CI extra) y `main` reciba siempre `current.md` vacío.
2. **BUG-005 — el guardián juzga la carpeta donde corre git, no donde vive la
   sesión.** Reglas 1 (misma rama) y 2 (rama encima de trabajo vivo) calculan
   rama/HEAD en el `cwd` del payload (`session-guardian.sh:375`), ignorando
   `git -C <dir>` y un `cd <dir> &&` previo en el mismo comando. Falso positivo
   constante en worktrees; los agentes lo sortean con `"$(command -v git)"` o
   scripts, es decir, desactivando la protección.
   - `classify()` devuelve también el directorio efectivo de cada verbo de
     integración (`-C`/`--work-tree` relativo al `cd` previo, o el `cd` previo,
     o el `cwd`). Las reglas 1 y 2 se evalúan por cada directorio efectivo
     distinto. La regla 0 (tree-ops) ya respeta `-C`; se le añade el `cd` previo
     con el mismo mecanismo.
   - Solo cuenta `cd` como comando de un segmento (`cd X && git …`, `cd X; git …`).
     Nada de interpretar subshells ni variables (`cd "$W"` no se resuelve: se
     cae al `cwd`, comportamiento actual).
   - Si el directorio efectivo no es un repo git, o pertenece a OTRO repo
     (su `git-common-dir` difiere del de `cwd`), se usa `cwd` — comportamiento
     actual. Solo se relaja cuando el directorio efectivo es un worktree del
     mismo repo, demostrable.
3. **BUG-006 — los subagentes no deben tocar candados ni drenar estado.** La
   documentación de hooks de Claude Code dice que el payload trae `agent_id`
   cuando el hook se dispara dentro de un subagente. Hoy un subagente puede:
   recrear un candado con su id (heartbeat) que luego bloquea git 15 min;
   borrar el candado del padre al terminar (lock-cleanup); drenar `current.md`
   (session-end). Con `agent_id` presente: `session-end.sh` y
   `session-lock-cleanup.sh` salen sin hacer nada; `session-heartbeat.sh` solo
   refresca la hora (mtime) de un candado **existente** — nunca lo crea ni
   copia rama/HEAD/cwd/archivos del subagente (si comparte `session_id` con el
   padre, eso falsearía el candado del padre). `session-lock.sh` no se toca
   (SessionStart no se dispara en subagentes). El guardián sigue evaluando
   igual (la protección no se apaga en subagentes). Si `agent_id` no llega en
   alguna versión de Claude Code, el comportamiento es el actual: la guarda
   solo puede ayudar.
4. **BUG-007 — el resumen de historial al arrancar muestra fragmentos.**
   `history_tail` inyecta las últimas N *líneas* de `history.md`, que suelen ser
   una viñeta suelta. Se inyectan los últimos N **bloques** como encabezado
   (`## YYYY-MM-DD — <resumen>`) + sus primeras líneas de contenido: arranque
   (startup/clear) 2 bloques × (encabezado + 2 líneas); compact/resume 1
   bloque × (encabezado + 1 línea). Bloques sin contenido tras el filtro de
   ruido (p. ej. `— Session end` vacíos) se saltan.
5. **FEAT-008 — IDs sin choques, en una sola llamada.** Nuevo
   `scripts/next-id.sh FEAT|BUG`: calcula el máximo entre (a) los archivos vivos
   (`features/*.md` o `bugs/*.md`, sin archivos `*-archive-*`), (b) las reservas
   en `.git/slate-ids/<PREFIJO>/`, (c) los nombres de ramas locales y remotas
   que contengan `feat-NNN`/`bug-NNN` (sin `fetch`: usa lo que haya), reserva
   el siguiente con `reserve-id.sh` (reintenta si se lo quitan) e imprime el ID.
   - `session-start.sh` inyecta en el arranque la ruta **absoluta** al script
     (una línea), porque `$CLAUDE_PLUGIN_ROOT` no existe en el shell del agente.
   - Las skills (`managing-feature-list`, `breaking-down-features`,
     `tracking-bugs`) sustituyen el grep+ls+reserve de tres pasos por esa llamada.
6. **FEAT-009 — mover tarjetas con validación y cerrar con subtareas sacadas.**
   - Nuevo marcador de subtarea `- [-] FEAT-X.N: … → FEAT-YYY` (sacada a otra
     feature) o `- [-] FEAT-X.N: … (descartada: <motivo>)`. Una feature puede ir
     a done con todas sus subtareas en `[x]` o `[-]` con destino/motivo. Se
     documenta en skill, `docs/feature-format.md` y regla 2 de `AGENTS.md`
     (repo + template).
   - Nuevo `scripts/move-card.sh <ID> <destino>`: destinos `backlog`,
     `in-progress`, `done` para FEAT; `fixed` para BUG. Mueve el bloque entero,
     pone `Status` y `Updated` (hoy), y **se niega** si no se cumplen las reglas:
     backlog→done prohibido; a done requiere todas las subtareas `[x]`/`[-]`
     válidas y `Verified:` con fecha; a fixed requiere `Fix`, `Commit` y `Fixed:`
     no vacíos ni `none`. Nunca edita una tarjeta ya en done/fixed. Ruta absoluta
     inyectada por `session-start.sh` junto a la de `next-id.sh`.
7. **Higiene**: BUG-003 (arreglado en `c666d46`) pasa a `fixed.md`; los
   nuevos BUG/FEAT se registran y cierran con su commit; CHANGELOG; versión
   1.10.0 en `plugin.json` (sin bump no llega a uso real — ver BUG-001).

## No-metas

- Coordinar IDs entre máquinas o clones (requeriría servidor o `fetch`).
- Un chequeo pre-commit de "FEAT sin reserva" — `next-id.sh` quita la fricción
  que hacía saltarse la reserva; si vuelve a pasar, se reconsidera.
- Liveness por PID de proceso: detectar el proceso dueño de forma fiable es
  frágil y un error *apaga* la protección. `agent_id` resuelve el caso medido
  (subagentes); el TTL de 15 min sigue para sesiones caídas.
- Acumular cierres de varias sesiones en otra rama/PR.
- Cambiar el bucle Stop (era un hook propio de phlou, ya arreglado allí).

## Anti-metas (fallaría aunque "funcione")

- Que el guardián deje pasar un `checkout`/`reset --hard` real sobre la carpeta
  de un peer vivo. Cualquier relajación es solo por directorio efectivo
  demostrable; ante duda, comportamiento actual.
- Que `move-card.sh` o `next-id.sh` lean archivos enteros a contexto o impriman
  más que el ID / una línea de resultado.
- Romper cualquiera de los 30 tests existentes. Si un test codifica el
  comportamiento que este diseño corrige, se ajusta el test con comentario del
  porqué, nunca se borra la aserción.

## Restricciones

- Bash + python3 de sistema, sin dependencias nuevas. Mismo estilo que los
  hooks actuales: tolerantes a payload malformado, `exit 0` siempre en hooks.
- Cada arreglo con su test en `tests/` (estilo existente: repo temporal,
  `PASS:`/`FAIL:`), corrida completa `for f in tests/*.sh; do bash "$f"; done`.
- Comentarios en español como el resto del código.

## Decisiones tomadas por mí (Felipe delegó)

- Rama por defecto = `origin/HEAD` si existe, si no `main`/`master`.
- `[-]` como marcador (no `[~]`): convención markdown común para "no aplica".
- Builder check (subagente Opus, 2026-10-18) resolvió: drenaje en `main` con
  cambios sin commitear, heartbeat de subagente solo-mtime, bloques con
  primeras líneas en vez de solo encabezados, `-C` a otro repo → `cwd`.
- `move-card.sh` en python embebido (como los hooks) para no pelear con awk
  multilínea.
- Dos features + cuatro bugs, en una sola rama `fix/1.10.0-phlou-findings` y
  un solo PR.

## Lo que queda al constructor

Nombres internos, estructura de los tests, redacción exacta de mensajes.
