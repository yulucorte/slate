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
