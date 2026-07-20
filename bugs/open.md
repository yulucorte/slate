# Open bugs

<!-- Bugs found but not yet fixed. Status: open.
     Add via slate:tracking-bugs.
     Move to fixed.md once Fix, Commit, and Fixed: date are all set. -->

## BUG-002: El guardián de session-lock solo vigila el NOMBRE de rama al arrancar — no cubre rama construida encima, stash compartido ni merge cross-worktree
- **Status**: open
- **Severity**: high
- **Reported-by**: @felipevillacorte
- **Detected**: 2026-07-19
- **Where**: `hooks/session-lock.sh`, `hooks/session-guardian.sh`
- **Root cause**: El diseño de FEAT-001 detecta colisión solo por igualdad de NOMBRE de rama y solo en SessionStart; el guardián de commit/push compara la rama actual contra la rama reclamada al arrancar. Puntos ciegos: (1) dos ramas de nombres distintos construidas una sobre el commit de la otra (caso real: otro proceso ramificó `chore/slate-feat-110` encima de un commit propio y arrastró ese trabajo a producción al mergear su PR) pasan por debajo del radar; (2) cada tarea legítima crea rama nueva (feat-109 → feat-111), así que el guardián debe ser permisivo para no estorbar, y permisivo no distingue "cambié de rama a propósito" de "me cambiaron por debajo"; (3) los worktrees comparten el mismo git-store y el mismo `git stash` — ramas distintas en carpetas distintas igual chocan en el stash compartido; (4) no re-chequea colisiones antes de cada escritura git, solo al arrancar.
- **Fix**: none
- **Commit**: none

### Notes
- El incidente real que lo destapó: un proceso paralelo ramificó encima de un commit propio (nombre de rama distinto) y al mergear arrastró el backend a producción antes de tiempo. Reencauzado a mano, sin daño final.
- Ideas de corrección (NO implementadas, solo diagnóstico): vigilar la identidad de la rama (commit base), no el nombre; re-chequear candados vivos justo antes de commit/merge/push; proteger el stash compartido y bloquear merge de una rama cuyo tip es la rama viva de otra sesión; basar la vida del heartbeat en "el proceso existe", no solo en la mtime del archivo.
- Evidencia en vivo (2026-07-19): mientras se arreglaba BUG-001, esta sesión reclamó `main` al arrancar, creó la rama `fix/bug-001-plugin-version-bump` (flujo correcto que el propio proyecto exige) e intentó commitear → el guardián BLOQUEÓ el commit por "rama cambiada por debajo". Falso positivo real del punto ciego (2): el guardián no distingue un cambio de rama deliberado de uno hostil. Workaround usado: actualizar a mano el campo `branch` del candado propio. Un rediseño debería refrescar el candado en el propio cambio de rama, o distinguir el cambio iniciado por esta sesión.
- Relacionado con [[BUG-001]] (la protección ni siquiera corría en la sesión afectada).
