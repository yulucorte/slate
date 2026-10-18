# Slate 1.10.0 (hallazgos de phlou) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corregir los 4 bugs y añadir las 2 herramientas del spec para que slate deje de ensuciar `main`, de bloquear commits legítimos en worktrees, de repetir IDs y de obligar a mover tarjetas a mano.

**Architecture:** Cambios acotados en los hooks bash+python existentes (`hooks/`), dos scripts nuevos en `scripts/` (`next-id.sh`, `move-card.sh`) cuya ruta absoluta inyecta `session-start.sh`, y texto de skills/plantillas. Un test nuevo por tarea en `tests/`, estilo existente.

**Tech Stack:** bash, python3 de sistema (sin dependencias), git.

**Spec:** `docs/superpowers/specs/2026-10-18-phlou-findings-1.10-design.md`

## Global Constraints

- Sin dependencias nuevas. Hooks: tolerantes a payload malformado (isinstance + degradar), siempre `exit 0`.
- Comentarios en español, mismo tono que el código vecino.
- Tests: `tests/test-*.sh`, repo temporal con `mktemp -d`, líneas `PASS:`/`FAIL:`, salida `exit 1` al primer fallo o al final si hubo fallos (copiar el patrón `pass()/fail()` de `tests/test-hygiene-1.8.0.sh`).
- Suite completa en verde al final de cada tarea: `for f in tests/*.sh; do bash "$f" >/dev/null 2>&1 || echo "FAIL $f"; done` no imprime nada.
- Ningún test existente pierde aserciones. Si uno codifica el comportamiento corregido, se ajusta con comentario del porqué.
- IDs ya reservados en `.git/slate-ids/`: BUG-004, BUG-005, BUG-006, BUG-007, FEAT-008, FEAT-010. (FEAT-009 NO se usa: lo ocupa la rama histórica `backup/pre-merge-FEAT-009`.)
- Rama de trabajo: `fix/1.10.0-phlou-findings` (ya creada). Un commit por tarea, mensajes Conventional Commits en español como el historial (`fix: …`, `feat: …`), terminando con las líneas de atribución que dé la sesión.

## Review Focus

1. Guardián con comando compuesto `cd <wt> && git commit` donde `<wt>` es un worktree del mismo repo en otra rama y un peer vivo está en `main` en la carpeta principal → debe PERMITIR. (Task 3)
2. Guardián con `git -C /otro/repo commit` (repo distinto) → mismo veredicto que hoy con `cwd` (no relajar). (Task 3)
3. `session-end.sh` en `main` con `current.md` versionado y sin cambios → no escribe; en `main` con `current.md` modificado sin commitear → drena. (Task 1)
4. `move-card.sh FEAT-X done` con una subtarea `[-]` sin `→ FEAT-` ni `(descartada:` → se niega con mensaje y no toca ningún archivo. (Task 6)
5. `next-id.sh FEAT` cuando existe una rama `feat/feat-042-x` y los archivos solo llegan a FEAT-040 → devuelve FEAT-043. (Task 5)

---

### Task 1: BUG-004 — session-end no drena en la rama por defecto con current.md limpio

**Files:**
- Modify: `hooks/session-end.sh` (tras `has_work`, antes del bloque que escribe)
- Modify: `skills/tracking-progress/SKILL.md` (sección `### At task complete`)
- Test: `tests/test-session-end-default-branch.sh`

**Interfaces:**
- Produces: nada consumido por otras tareas.

- [ ] **Step 1: Write the failing test** — repo temporal en rama `main` (`git init -b main`), `current.md` con `### FEAT-1 en vuelo` y `history.md`, ambos COMMITEADOS. Casos:
  - `main` + current.md limpio vs HEAD → tras `CLAUDE_PROJECT_ROOT=$R bash hooks/session-end.sh`, `git -C $R status --porcelain` vacío. PASS "main con current.md commiteado no se ensucia".
  - `main` + current.md modificado sin commitear (añadir `### FEAT-2 en vuelo`) → history.md contiene `FEAT-2`. PASS "main con trabajo sin commitear si se drena".
  - rama `feat/x` + current.md commiteado con trabajo → history.md contiene `FEAT-1` (comportamiento actual). PASS "rama de trabajo drena como siempre".
  - `origin/HEAD` apuntando a `develop` (crear `refs/remotes/origin/develop` y `git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop`), sesión en `develop` con current.md limpio → no se ensucia.
- [ ] **Step 2: Run** `bash tests/test-session-end-default-branch.sh` → FAIL en el caso 1.
- [ ] **Step 3: Implement** en `session-end.sh`: rama por defecto = destino de `git symbolic-ref --short refs/remotes/origin/HEAD` sin el prefijo `origin/`; si no existe, `main` o `master`. Si `git -C "$PROJECT_ROOT" branch --show-current` es esa rama Y `git -C "$PROJECT_ROOT" diff --quiet HEAD -- docs/slate/progress/current.md` sale 0 Y el archivo está versionado (`git ls-files --error-unmatch`) → `exit 0`. Fuera de un repo git: comportamiento actual. Comentario explicando el incidente de phlou (current −94 / history +102 en main).
- [ ] **Step 4:** en `tracking-progress/SKILL.md`, `### At task complete`: añadir que el drenaje `current.md → history.md` se hace en la rama de trabajo como parte del último commit antes de abrir el PR, para que el cierre viaje en el PR de código (sin PR de solo-docs ni CI extra) y `main` reciba `current.md` vacío; y que en la rama por defecto el hook de cierre no drena lo ya commiteado.
- [ ] **Step 5: Run** test nuevo + suite completa → verde (el caso P4 de `test-hygiene-1.8.0.sh` sigue pasando porque allí current.md no está versionado).
- [ ] **Step 6: Commit** `fix: session-end no ensucia la rama por defecto (BUG-004)`.

### Task 2: BUG-006 — los subagentes no tocan candados ni drenan estado

**Files:**
- Modify: `hooks/session-end.sh`, `hooks/session-lock-cleanup.sh`, `hooks/session-heartbeat.sh`
- Test: `tests/test-subagent-hooks.sh`

**Interfaces:**
- Consumes: payload JSON con campo opcional `agent_id` (string no vacío = hook dentro de subagente).

- [ ] **Step 1: Write the failing test** — repo temporal (rama `feat/x`, para no chocar con Task 1) con `.git/slate-sessions/S1.lock` (`{"branch":"feat/x","head":"…","cwd":"<repo>","files":[]}`) y mtime antiguo (`touch -t` hace 10 min) y current.md con trabajo:
  - `session-end.sh` con `{"session_id":"S1","agent_id":"a1"}` en stdin → current.md intacto, history.md intacto.
  - `session-lock-cleanup.sh` con el mismo payload → `S1.lock` sigue existiendo.
  - `session-heartbeat.sh` con `{"session_id":"S1","agent_id":"a1","cwd":"<worktree W del mismo repo, en otra rama>","tool_name":"Write","tool_input":{"file_path":"x"}}` → mtime del lock actualizado, contenido JSON idéntico byte a byte (prueba que no copió rama/cwd/archivos del subagente).
  - Todas las invocaciones de hooks en tests llevan stdin explícito (`<<<` o `</dev/null`).
  - `session-heartbeat.sh` con `{"session_id":"S2","agent_id":"a2","cwd":"<repo>"}` → NO se crea `S2.lock`.
  - Control: los mismos hooks SIN `agent_id` mantienen comportamiento actual (cleanup borra S1.lock; heartbeat sin lock lo recrea).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** — en los dos hooks bash, leer `agent_id` del stdin con el mismo `python3 -c` que ya extrae `session_id` (session-end hoy no lee stdin: añadirlo con la guarda `[ ! -t 0 ]` de `session-lock-cleanup.sh:22`, y añadir `</dev/null` a las 3 llamadas sin redirección de `tests/test-hygiene-1.8.0.sh` ~142,165,183) y `exit 0` si no está vacío. En heartbeat (python): si `agent_id` es str no vacía → si el lock de `sid` existe, `os.utime(lock)` y salir; si no existe, salir. Comentario citando la doc de hooks (`agent_id` presente solo dentro de subagentes) y la memoria de phlou (candado de subagente bloqueó git 15 min; subagente drenó current.md).
- [ ] **Step 4: Run** test nuevo + suite → verde.
- [ ] **Step 5: Commit** `fix: los hooks ignoran subagentes al cerrar y en el latido (BUG-006)`.

### Task 3: BUG-005 — reglas 0/1/2 del guardián usan el directorio efectivo del git

**Files:**
- Modify: `hooks/session-guardian.sh` (`classify()` ~líneas 124-243; reglas 1/2 ~375-523; `resolve_target` ~407)
- Test: `tests/test-guardian-effective-dir.sh`

**Interfaces:**
- Produces (interno): `classify(command) -> (verbs, stash, tree_hits, integ_dirs)` donde `integ_dirs` es un `set` de rutas crudas (str o `None` = cwd) de las invocaciones con verbo `commit|push|merge|rebase|cherry-pick`; `tree_hits` pasa a llevar el directorio efectivo (incluye el `cd` previo).

- [ ] **Step 1: Write the failing test** — setup como `tests/test-guardian-false-positives.sh` (copiar su helper de repo + lock de peer). Repo principal `R` en `main`, worktree `W` (`git worktree add ../W -b feat/w`), peer vivo `P.lock` con `branch:"main"`, `cwd:R`, mtime ahora. Payload de esta sesión con `cwd:R`:
  - `cd W && git commit -m x` → sin `deny`. PASS "cd a worktree propio no choca con peer en main".
  - `git -C W commit -m x` → sin `deny`.
  - `git commit -m x` (sin cd ni -C) → `deny` (regla 1, comportamiento actual).
  - `cd W && git checkout main` con peer `cwd:W` → `deny` (regla 0 ve el cd).
  - `git -C /tmp/<otro-repo-git> commit -m x` → `deny` igual que sin -C (otro repo → cwd).
  - `cd "$W" && git commit -m x` (variable sin expandir) → `deny` (no se resuelve, cae a cwd).
  - SEGURIDAD, peer vivo con `cwd:R` (misma carpeta que esta sesión): `cd W || git checkout main`, `cd W | git checkout main`, `cd W & git checkout main` → los tres `deny` (git corre en R).
  - Test existente `tests/test-guardian-tree-ops.sh` #11 (`git -C $OTHER checkout otra` permitido) sigue pasando.
- [ ] **Step 2: Run** → FAIL en los dos primeros y en el cuarto.
- [ ] **Step 3: Implement** — en `classify()`, partir el comando CONSERVANDO separadores: `re.split(r"(&&|\|\||[;&|\n])", command)`. Mantener `cur_dir` (None al empezar). Un segmento cuyo comando (tras asignaciones/prefijos ya saltados) es `cd` con un único argumento literal sin `$` actualiza `cur_dir` (relativo al anterior o al cwd) SOLO si el separador que lo sigue es `&&`, `;` o `\n`; tras `|`, `||`, `&` o fin, no cambia nada. Directorio efectivo crudo de cada invocación git = `-C`/`--work-tree` resuelto contra `cur_dir` (o tal cual si `cur_dir` es None), o `cur_dir`, o `None`. Añadirlo a `tree_hits` y, para verbos de integración, a `integ_dirs`. Actualizar también el desempaquetado de la rama no-bash (~línea 247) a 4 valores.
- [ ] **Step 4: Implement** — función `effective_dir(raw) -> str` SOLO para reglas 1 y 2: devuelve `raw` resuelto solo si es repo git con el mismo `--git-common-dir` (realpath) que `gcd`; si no, `cwd`. Reglas 1 y 2: iterar sobre `{effective_dir(d) for d in integ_dirs}` (o `{cwd}` si vacío) calculando `actual_branch`/`actual_head` con `git(..., in_dir=d)` y `merge-base` con `in_dir=d`. Un deny por regla basta (mantener `break`). Regla 0: `resolve_target(raw)` NO cambia; solo recibe el `raw` ya resuelto contra `cur_dir`.
- [ ] **Step 5: Run** test nuevo + toda la suite (especialmente `test-guardian-*.sh`, `test-session-guardian.sh`) → verde.
- [ ] **Step 6: Commit** `fix: el guardián juzga la carpeta donde corre git, no la de la sesión (BUG-005)`.

### Task 4: BUG-007 — el arranque muestra bloques de historial, no líneas sueltas

**Files:**
- Modify: `hooks/session-start.sh` (`history_tail` y sus dos llamadas)
- Test: `tests/test-session-start-history-blocks.sh`

**Interfaces:**
- Produces (interno): `history_blocks N L` imprime los últimos `N` bloques no vacíos de `history_clean`, cada uno = su línea `## …` + sus primeras `L` líneas de contenido. Reemplaza a `history_tail`.

- [ ] **Step 1: Write the failing test** — history.md con: `## 2026-10-01 — cierre A` + 3 viñetas (`- A1`,`- A2`,`- A3`), `## 2026-10-02 10:00:00 — Session end` vacío (solo plantilla), `## 2026-10-03 — cierre B` + `- B1`,`- B2`,`- B3`.
  - startup → contiene `cierre A`, `- A1`, `- A2`, `cierre B`, `- B1`, `- B2`; NO contiene `A3`, `B3`, `Session end`.
  - `{"source":"compact"}` → contiene `cierre B` y `- B1`; NO `B2` ni `cierre A`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** `history_blocks` con awk sobre `history_clean`: agrupar por líneas `^## `, descartar bloques sin líneas de contenido, quedarse con los últimos N, imprimir encabezado + primeras L. startup/clear: `history_blocks 2 2`; compact/resume: `history_blocks 1 1`. El conteo de bloques (`HIST_COUNT`) no cambia.
- [ ] **Step 4: Run** test nuevo + suite (los casos 1, 2 y 4c de `test-hygiene-1.8.0.sh` deben seguir pasando: sus viñetas buscadas están en las 2 primeras líneas del bloque) → verde.
- [ ] **Step 5: Commit** `fix: el arranque resume bloques de historial, no fragmentos (BUG-007)`.

### Task 5: FEAT-008 — `next-id.sh`: siguiente ID libre en una llamada

**Files:**
- Create: `scripts/next-id.sh`
- Modify: `hooks/session-start.sh` (línea de herramientas), `skills/managing-feature-list/SKILL.md` (## ID assignment), `skills/breaking-down-features/SKILL.md` (paso de reserva), `skills/tracking-bugs/SKILL.md` (paso 1 y ## ID assignment), `docs/feature-format.md` (## ID rules)
- Test: `tests/test-next-id.sh`

**Interfaces:**
- Produces: `bash <ruta-absoluta>/scripts/next-id.sh FEAT|BUG` → imprime en stdout SOLO el ID reservado (`FEAT-043`), exit 0. Uso incorrecto → exit 2 con mensaje en stderr. Lo usan las skills y Task 7.
- Consumes: `scripts/reserve-id.sh <ID>` (exit 0 = reservado, 1 = ya reservado).

- [ ] **Step 1: Write the failing test**:
  - repo vacío con `docs/slate/features/` sin IDs → `FEAT-001`.
  - backlog con `FEAT-040` → `FEAT-041`; segunda llamada → `FEAT-042` (la reserva cuenta).
  - rama `feat/feat-050-x` (local) → siguiente `FEAT-051`; ref remota `refs/remotes/origin/bug/bug-020-y` con bugs/open.md en BUG-003 → `next-id.sh BUG` = `BUG-021`. Ramas con `FEAT-` en mayúsculas también cuentan.
  - `FEAT` y `BUG` independientes.
  - archivo `done-archive-2026H1.md` con FEAT-999 → ignorado.
  - `next-id.sh` sin argumento o `next-id.sh XYZ` → exit 2.
  - stdout es exactamente una línea.
- [ ] **Step 2: Run** → FAIL (script no existe).
- [ ] **Step 3: Implement** `scripts/next-id.sh`: prefijo FEAT → `docs/slate/features/{backlog,in-progress,done}.md`; BUG → `docs/slate/bugs/{open,fixed}.md` (rutas relativas a `git rev-parse --show-toplevel`). Máximo de: grep en esos archivos, `ls .git-common-dir/slate-ids/<PREFIJO>/`, `git for-each-ref --format='%(refname:short)' refs/heads refs/remotes` filtrado con `grep -ioE '<prefijo>-[0-9]+'`. Números con cero a la izquierda: parsear en base 10 (`10#$n` en bash; `008` es octal inválido). Candidato = max+1 con `%03d`; bucle llamando a `reserve-id.sh` (mismo directorio que el script): exit 0 → imprimir y salir; exit 1 → siguiente número (máx. 50 intentos); exit 2 → propagar error (exit 2) sin reintentar. Sin `fetch`.
- [ ] **Step 4:** `session-start.sh`: añadir al contexto (startup Y compact) una línea `IDs/tarjetas: bash <PLUGIN_ROOT>/scripts/next-id.sh FEAT|BUG · bash <PLUGIN_ROOT>/scripts/move-card.sh <ID> <destino>` con `PLUGIN_ROOT` absoluto ya calculado en el hook. (move-card llega en Task 6; la línea se escribe ya completa.) Ajustar `test-session-start-wrapped-output.sh` solo si una aserción de longitud/forma lo exige.
- [ ] **Step 5:** skills y `docs/feature-format.md`: sustituir el bloque grep+ls+reserve por "ejecuta `next-id.sh FEAT` (ruta en el contexto de arranque) y usa el ID que imprime"; conservar en una frase el porqué (reserva compartida por worktrees; mira ramas locales/remotas; no protege entre máquinas sin fetch) y el fallback manual con `reserve-id.sh` si el script no está.
- [ ] **Step 6: Run** test nuevo + suite (`test-skill-frontmatter.sh` incluido) → verde.
- [ ] **Step 7: Commit** `feat: next-id.sh reserva el siguiente ID en una llamada (FEAT-008)`.

### Task 6: FEAT-010 — `move-card.sh` con validación y subtareas `[-]`

**Files:**
- Create: `scripts/move-card.sh`
- Modify: `skills/managing-feature-list/SKILL.md` (tabla de movimiento, ## When subtasks complete), `skills/tracking-bugs/SKILL.md` (paso 3 Fix), `docs/feature-format.md` (subtareas), `AGENTS.md` y `templates/AGENTS.md` (regla 2)
- Test: `tests/test-move-card.sh`

**Interfaces:**
- Produces: `bash <ruta>/scripts/move-card.sh <ID> <destino>`; destinos FEAT: `backlog|in-progress|done`; BUG: `fixed`. Éxito: una línea `FEAT-012: in-progress.md -> done.md`, exit 0. Rechazo: motivo en stderr, exit 1, ningún archivo modificado. Uso incorrecto: exit 2.

- [ ] **Step 1: Write the failing test** (repo temporal con `docs/slate/features/{backlog,in-progress,done}.md` y `docs/slate/bugs/{open,fixed}.md` con cabecera `# …`):
  - FEAT-001 en backlog → `in-progress`: bloque sale de backlog.md, aparece al final de in-progress.md, `- **Status**: in_progress`, `- **Updated**: <date +%F>` (formato real de `docs/feature-format.md`; bugs: `- **Status**: fixed`).
  - FEAT-001 backlog → `done` → exit 1 (prohibido saltar in-progress).
  - FEAT-002 en in-progress con una `[ ]` → `done` → exit 1, archivos idénticos (`cmp` contra copia previa).
  - FEAT-002 con `[x]` + `[-] … → FEAT-009` y sin `Verified` → exit 1; con `- **Verified**: 2026-10-18` → exit 0, `Status: done`, bloque al final de done.md.
  - `[-]` sin `→ FEAT-` ni `(descartada:` → exit 1.
  - FEAT ya en done.md → cualquier destino → exit 1 (done es inmutable).
  - BUG-001 en open.md con `Fix: none` → `fixed` → exit 1; con Fix, `Commit: abc1234`, `Fixed: 2026-10-18` → exit 0, `Status: fixed`, en fixed.md.
  - ID inexistente → exit 1. Bloque = desde `## <ID>:` hasta el siguiente `## ` o fin de archivo (incluye `### Subtasks`/`### Notes`).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** `scripts/move-card.sh` como envoltorio bash + `python3 -` (heredoc, mismo estilo que los hooks). Localiza el bloque en los archivos del prefijo, valida, escribe destino y origen de forma atómica (escribir `.tmp` + `os.replace`, destino primero). Reglas válidas de `[-]`: la línea contiene `→ FEAT-` o `-> FEAT-` o `(descartada:`.
- [ ] **Step 4:** documentación: tabla de movimiento y regla 2 de AGENTS.md (repo y template) → "ALL subtasks `[x]` (or `[-]` moved `→ FEAT-YYY` / `(descartada: <motivo>)`) AND `Verified`"; skills indican usar `move-card.sh` (ruta en el contexto de arranque) en vez de mover a mano; `docs/feature-format.md` documenta `[-]`.
- [ ] **Step 5: Run** test nuevo + suite → verde.
- [ ] **Step 6: Commit** `feat: move-card.sh mueve tarjetas validando las reglas (FEAT-010)`.

### Task 7: Trazabilidad, versión y cierre

**Files:**
- Modify: `docs/slate/bugs/open.md`, `docs/slate/bugs/fixed.md`, `docs/slate/features/in-progress.md`, `docs/slate/features/done.md`, `docs/slate/progress/history.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: `move-card.sh` (Task 6) para TODOS los movimientos de tarjetas — es su prueba en uso real.

- [ ] **Step 1:** BUG-003: rellenar `- **Commit**: c666d46` y AÑADIR la línea `- **Fixed**: 2026-08-14` (hoy no existe) en open.md y `move-card.sh BUG-003 fixed`.
- [ ] **Step 2:** registrar BUG-004…007 en open.md (formato de `docs/bug-format.md`, Reported-by `@felipevillacorte`, Detected 2026-10-18, Root cause/Fix del spec, Commit = hash del commit de su tarea, `Fixed: 2026-10-18`, Notes: "Reportado por la sesión phlou (phlou-app) el 2026-10-18") y moverlos con `move-card.sh <ID> fixed`.
- [ ] **Step 3:** registrar FEAT-008 y FEAT-010 en in-progress.md (Spec/Plan de este trabajo, Branch `fix/1.10.0-phlou-findings`, subtareas `[x]` = pasos del plan, `Verified: 2026-10-18`, `Verification: integration-test`) y moverlas con `move-card.sh <ID> done`.
- [ ] **Step 4:** `CHANGELOG.md`: entrada `## 1.10.0 — 2026-10-18` arriba, mismo estilo que 1.9.1 (qué estaba roto, cómo se medía, qué cambia; nota de que phlou-app necesita actualizar el plugin). `plugin.json` → `1.10.0`.
- [ ] **Step 5:** `history.md`: bloque `## 2026-10-18 — slate 1.10.0: hallazgos de phlou` con lo hecho, en esta rama (aplica la regla de Task 1).
- [ ] **Step 6: Run** suite completa → todo verde; `bash scripts/self-test.sh` → verde.
- [ ] **Step 7: Commit** `chore: 1.10.0 — trazabilidad de BUG-003..007, FEAT-008/010`.
