# Use feedback log

## 2026-05-13 — Fase 0 (FEAT-009) cerrada

### Lo que aprendí esta sesión

- Tenía una rama paralela (`feat/branch-wip-limit`, PR #1) que no recordaba haber
  abierto. Trabajo de hace una semana, perdido en mi memoria. Esto es exactamente
  el problema que `progress/history.md` resuelve. Es razón concreta para creer en
  la utilidad del project-map y de la historia persistente.

- El self-test no detectó el auto-merge silencioso que duplicó el campo Branch:
  en `feature-format.md`. Falta cobertura de validación documental. Considerar
  un test que parsee schemas y verifique unicidad de campos.

- Decisión de diseño tomada: campo Branch: se asigna al pasar a in-progress,
  no upfront. Default `none` en backlog. Formato `feat/feat-NNN-<slug>`.
  Razón: coherencia con auto-suggest de breaking-down-features y WIP-limit de
  managing-feature-list.

### Cosas por validar en uso real

- ¿El SessionStart con additionalContext + history + features se siente útil o
  ruidoso?
- ¿Cuántas veces el watcher de in-progress sugiere branch y cuántas estoy de
  acuerdo con la sugerencia?
- ¿El pre-tool-safety con las 4 reglas hardcoded ha bloqueado algo legítimo
  alguna vez? (señalaría que necesito FEAT-012 file guard extensible)
