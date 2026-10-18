#!/usr/bin/env bash
# FEAT-010: scripts/move-card.sh mueve tarjetas validando las reglas.
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/move-card.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

R="$TMP/r"
mkdir -p "$R/docs/slate/features" "$R/docs/slate/bugs"
git -C "$R" init -q -b main .
F="$R/docs/slate/features"; B="$R/docs/slate/bugs"
printf '# Backlog\n\n## FEAT-001: uno\n- **Status**: backlog\n- **Created**: 2026-01-01\n- **Updated**: 2026-01-01\n\n### Subtasks\n- [ ] FEAT-001.1: a\n\n### Notes\nnota\n' > "$F/backlog.md"
cat > "$F/in-progress.md" <<'X'
# In progress

## FEAT-002: dos
- **Status**: in_progress
- **Created**: 2026-01-01
- **Updated**: 2026-01-01

### Subtasks
- [ ] FEAT-002.1: abierta
- [x] FEAT-002.2: hecha

## FEAT-003: tres
- **Status**: in_progress
- **Created**: 2026-01-01
- **Updated**: 2026-01-01
- **Verified**: 2026-10-18

### Subtasks
- [x] FEAT-003.1: hecha
- [-] FEAT-003.2: sacada → FEAT-009
- [-] FEAT-003.3: ya no aplica (descartada: otro enfoque)

## FEAT-004: cuatro
- **Status**: in_progress
- **Created**: 2026-01-01
- **Updated**: 2026-01-01
- **Verified**: 2026-10-18

### Subtasks
- [x] FEAT-004.1: hecha
- [-] FEAT-004.2: sin motivo
X
printf '# Done\n\n## FEAT-005: cinco\n- **Status**: done\n' > "$F/done.md"
printf '# Open\n\n## BUG-001: b1\n- **Status**: open\n- **Fix**: none\n- **Commit**: none\n\n## BUG-002: b2\n- **Status**: open\n- **Fix**: arreglado\n- **Commit**: abc1234\n- **Fixed**: 2026-10-18\n' > "$B/open.md"
printf '# Fixed\n' > "$B/fixed.md"

mv_() { (cd "$R" && bash "$SCRIPT" "$@" 2>"$TMP/err" </dev/null); }
snap() { cat "$F"/*.md "$B"/*.md | cksum; }
has() { grep -qF -- "$2" "$1"; }

# 1. backlog -> in-progress
mv_ FEAT-001 in-progress >/dev/null; rc=$?
if [ $rc -eq 0 ] && ! has "$F/backlog.md" "FEAT-001" && has "$F/in-progress.md" "## FEAT-001: uno" \
   && has "$F/in-progress.md" "- **Status**: in_progress" && has "$F/in-progress.md" "- **Updated**: $(date +%F)" \
   && has "$F/in-progress.md" "nota"; then
  pass "backlog -> in-progress mueve el bloque entero y actualiza Status/Updated"
else fail "backlog -> in-progress (rc=$rc)"; fi

# 2. backlog -> done prohibido (FEAT-001 ya no esta en backlog: usamos uno nuevo)
printf '\n## FEAT-006: seis\n- **Status**: backlog\n' >> "$F/backlog.md"
S0=$(snap); mv_ FEAT-006 done >/dev/null; rc=$?
[ $rc -eq 1 ] && [ "$S0" = "$(snap)" ] && pass "backlog -> done rechazado" || fail "backlog -> done (rc=$rc)"

# 3. subtarea abierta
S0=$(snap); mv_ FEAT-002 done >/dev/null; rc=$?
[ $rc -eq 1 ] && [ "$S0" = "$(snap)" ] && pass "done con subtarea [ ] rechazado sin tocar archivos" || fail "subtarea abierta (rc=$rc)"

# 4. [-] validas + Verified -> done
mv_ FEAT-003 done >/dev/null; rc=$?
if [ $rc -eq 0 ] && has "$F/done.md" "## FEAT-003: tres" && has "$F/done.md" "- **Status**: done" && ! has "$F/in-progress.md" "FEAT-003"; then
  pass "[x] + [-] validas con Verified -> done"
else fail "FEAT-003 a done (rc=$rc)"; fi

# 5. [-] sin destino ni motivo
S0=$(snap); mv_ FEAT-004 done >/dev/null; rc=$?
[ $rc -eq 1 ] && [ "$S0" = "$(snap)" ] && pass "[-] sin '-> FEAT-' ni '(descartada:' rechazado" || fail "[-] invalida (rc=$rc)"

# 5b. sin Verified
sed -i.bak 's/^- \[-\] FEAT-004.2: sin motivo/- [-] FEAT-004.2: x → FEAT-010/; /FEAT-004/,$ s/^- \*\*Verified\*\*.*$//' "$F/in-progress.md"; rm -f "$F/in-progress.md.bak"
S0=$(snap); mv_ FEAT-004 done >/dev/null; rc=$?
[ $rc -eq 1 ] && [ "$S0" = "$(snap)" ] && pass "sin Verified rechazado" || fail "sin Verified (rc=$rc)"

# 6. done es inmutable
S0=$(snap); mv_ FEAT-005 in-progress >/dev/null; rc=$?
[ $rc -eq 1 ] && [ "$S0" = "$(snap)" ] && pass "tarjeta en done.md no se mueve" || fail "done inmutable (rc=$rc)"

# 7. bugs
S0=$(snap); mv_ BUG-001 fixed >/dev/null; rc=$?
[ $rc -eq 1 ] && [ "$S0" = "$(snap)" ] && pass "bug con Fix: none rechazado" || fail "bug sin fix (rc=$rc)"
mv_ BUG-002 fixed >/dev/null; rc=$?
if [ $rc -eq 0 ] && has "$B/fixed.md" "## BUG-002: b2" && has "$B/fixed.md" "- **Status**: fixed" && ! has "$B/open.md" "BUG-002"; then
  pass "bug completo -> fixed"
else fail "BUG-002 a fixed (rc=$rc)"; fi

# 8. ID inexistente, uso incorrecto, linea de salida
mv_ FEAT-099 done >/dev/null; [ $? -eq 1 ] && pass "ID inexistente -> exit 1" || fail "ID inexistente"
mv_ FEAT-002 >/dev/null; [ $? -eq 2 ] && pass "sin destino -> exit 2" || fail "uso incorrecto"
mv_ FEAT-002 fixed >/dev/null; [ $? -eq 2 ] && pass "destino invalido para FEAT -> exit 2" || fail "destino invalido"
OUT=$(mv_ FEAT-006 in-progress)
[ "$OUT" = "FEAT-006: backlog.md -> in-progress.md" ] && pass "salida de una linea" || fail "salida: '$OUT'"

echo
if [ "$FAILED" -eq 0 ]; then echo "All move-card tests passed."; exit 0; fi
echo "move-card tests FAILED."
exit 1
