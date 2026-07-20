/goal Construir en el plugin Slate un guardián de sesiones paralelas que evite que dos sesiones de Claude Code sobre el MISMO repo se pisen la rama, el índice de git y el stash. NO está cumplido hasta que funcione con una SEGUNDA SESIÓN REAL: arrancas una sesión en un repo con Slate, luego arrancas otra en el mismo repo, y la segunda detecta a la primera y se aísla sola en un worktree (no comparten rama). Invoca las skills de Superpowers: brainstorming + writing-plans para diseñarlo ANTES de codear, TDD para los scripts del hook, verification-before-completion para cerrar. Trabaja en rama feat/feat-NNN-session-lock, git add por ruta explícita, nunca -A, nunca commits directos a main; sigue las convenciones del propio Slate (su tracker de features/progress). Explica a Felipe en claro (no es técnico). NO toques skills ni hooks ajenos al guardián.

DISEÑO (ya decidido, no re-investigar):

Problema raíz — dos sesiones sobre la misma copia del repo comparten: la rama activa (una sola a la vez), el índice de git, y el `git stash` (una sesión se lleva el guardado de la otra). Resultado repetido: una sesión cambia de rama por debajo de la otra.

Solución — dos capas:

1) CANDADO DE SESIÓN (lo nuevo). Al arrancar, cada sesión escribe un archivo-candado con: session id, rama actual, pid, hora de inicio, y un LATIDO (heartbeat = timestamp que se refresca). Antes de arrancar, lee los candados existentes: si hay otro VIVO en la misma rama → esta sesión se enruta a un worktree aislado (default elegido por Felipe: auto-worktree, cero decisión manual). Si no hay → sigue normal.

2) GUARDIÁN DE COMMIT. Hook PreToolUse sobre `git commit`/`git push`: verifica que la rama actual == la rama que esta sesión reclamó en su candado. Si cambió por debajo → bloquea y avisa. Red de seguridad por si la capa 1 falla.

GOTCHA 1 (el que hay que acertar): los worktrees AÍSLAN la carpeta de trabajo, entonces un candado dentro de `progress/` NO se vería entre copias — cada worktree tiene su propio `progress/`. El candado DEBE vivir en la carpeta git compartida: `git rev-parse --git-common-dir`/slate-sessions/ . Esa carpeta es común a todas las copias (worktrees) del mismo repo, es machine-local, y al estar dentro de .git no se commitea. Ahí todas las sesiones se ven.

GOTCHA 2: sin TTL, una sesión que muere (cuelgue) deja el candado trabado para siempre y bloquea a todas las futuras. El LATIDO lo resuelve: si un candado lleva más de N minutos (ej. 15) sin refrescar su heartbeat, está muerto → se ignora/reap. Refrescar el heartbeat en cada tool use o por intervalo.

GOTCHA 3 (límite honesto): una SKILL solo aconseja (yo la leo), no obliga. Un HOOK sí obliga (lo corre la máquina). El plugin debe traer AMBOS: la skill `slate:using-slate` escribe/lee el candado al iniciar; los hooks `SessionStart` (detectar + enrutar) y `PreToolUse(git commit/push)` (guardián) lo hacen cumplir. Para prevención real, el hook es obligatorio, no basta la skill.

GOTCHA 4: debe ser GENÉRICO — cero rutas hardcodeadas de ningún repo consumidor. Todo repo que instale Slate lo hereda igual. Limpieza: un hook SessionEnd (si existe en la plataforma) borra el candado de esta sesión al terminar.

TESTING (en orden, adaptado a plugin — NO hay Railway/Playwright/web):
1. Lógica de los scripts del hook con TDD (bats o el runner que use Slate): dado 0/1/2 candados, con heartbeat fresco vs viejo → decide correcto (seguir / enrutar / ignorar-stale).
2. Verifica que el candado cae en `$(git rev-parse --git-common-dir)/slate-sessions/` y que DOS worktrees del mismo repo se ven mutuamente el candado (crea un worktree de prueba, escribe candado en uno, léelo desde el otro).
3. Simula candado stale: heartbeat viejo → la siguiente sesión lo ignora y arranca normal.
4. Verifica el guardián: cambia la rama por debajo, intenta commit → el hook bloquea.
5. PRUEBA REAL end-to-end: instala el plugin, abre una sesión de Claude Code en un repo de prueba (sesión A escribe candado), abre OTRA sesión en el mismo repo (sesión B) → B detecta a A y se enruta a worktree. Ese es el criterio de DONE.

ROLLBACK (sin tocar datos): es un plugin aditivo. Desactivar = quitar la entrada del hook en la config de hooks del plugin (o bandera de settings que lo apague). Nada que revertir en repos consumidores; los candados viven en .git y son descartables.

ACEPTACIÓN (DONE solo si TODO se cumple con dos sesiones reales):
- Segunda sesión en el mismo repo se aísla sola en worktree; nunca comparten rama activa.
- Candado stale (heartbeat viejo) NO bloquea a la nueva sesión.
- Commit con rama cambiada por debajo → bloqueado por el hook.
- El candado vive en git-common-dir y es visible entre worktrees del mismo repo.
- Cero rutas hardcodeadas; funciona en cualquier repo que instale Slate.
- Sin regresiones en las skills slate:* existentes.

CONTEXTO: el plugin es `slate-direct` (skills `slate:*`). Encuentra dónde ship skills y hooks del plugin en su repo. La plataforma es Claude Code (hooks: SessionStart, PreToolUse, SessionEnd; matchers y formato en la doc de Claude Code — usa la skill claude-code-guide o find-docs si dudas del contrato de hooks). Al terminar, actualiza el tracker de Slate y resume a Felipe en claro.
