#!/usr/bin/env bash
# FEAT-008: scripts/next-id.sh calcula y reserva el siguiente ID libre.
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/next-id.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

mkrepo() {
  local d="$1"
  mkdir -p "$d/docs/slate/features" "$d/docs/slate/bugs"
  git -C "$d" init -q -b main .
  git -C "$d" config user.email t@t.co; git -C "$d" config user.name t
  git -C "$d" commit -q --allow-empty -m init
}
nid() { (cd "$1" && bash "$SCRIPT" "$2" 2>/dev/null </dev/null); }
check() { [ "$2" = "$3" ] && pass "$1" || fail "$1 (obtenido '$2', esperado '$3')"; }

# 1. repo sin IDs
R1="$TMP/r1"; mkrepo "$R1"
check "repo vacio -> FEAT-001" "$(nid "$R1" FEAT)" "FEAT-001"

# 2. backlog con FEAT-040; la reserva cuenta
R2="$TMP/r2"; mkrepo "$R2"
printf '# Backlog\n\n## FEAT-040: x\n' > "$R2/docs/slate/features/backlog.md"
check "FEAT-040 en backlog -> FEAT-041" "$(nid "$R2" FEAT)" "FEAT-041"
check "segunda llamada -> FEAT-042" "$(nid "$R2" FEAT)" "FEAT-042"
check "FEAT y BUG independientes" "$(nid "$R2" BUG)" "BUG-001"

# 3. ramas locales/remotas (mayusculas tambien)
R3="$TMP/r3"; mkrepo "$R3"
printf '## BUG-003: y\n' > "$R3/docs/slate/bugs/open.md"
printf '## FEAT-040: x\n' > "$R3/docs/slate/features/done.md"
git -C "$R3" branch feat/feat-050-x
git -C "$R3" branch fix/FEAT-052-upper
git -C "$R3" update-ref refs/remotes/origin/bug/bug-020-y HEAD
check "rama local feat-050/FEAT-052 -> FEAT-053" "$(nid "$R3" FEAT)" "FEAT-053"
check "rama remota bug-020 -> BUG-021" "$(nid "$R3" BUG)" "BUG-021"

# 4. archivos de archivo se ignoran
R4="$TMP/r4"; mkrepo "$R4"
printf '## FEAT-999: viejo\n' > "$R4/docs/slate/features/done-archive-2026H1.md"
check "done-archive ignorado -> FEAT-001" "$(nid "$R4" FEAT)" "FEAT-001"

# 5. ceros a la izquierda no son octal
R5="$TMP/r5"; mkrepo "$R5"
printf '## FEAT-008: x\n## FEAT-009: y\n' > "$R5/docs/slate/features/backlog.md"
check "FEAT-009 (no octal) -> FEAT-010" "$(nid "$R5" FEAT)" "FEAT-010"

# 6. uso incorrecto
(cd "$R1" && bash "$SCRIPT" </dev/null >/dev/null 2>&1); [ $? -eq 2 ] && pass "sin argumento -> exit 2" || fail "sin argumento no dio exit 2"
(cd "$R1" && bash "$SCRIPT" XYZ </dev/null >/dev/null 2>&1); [ $? -eq 2 ] && pass "prefijo invalido -> exit 2" || fail "prefijo invalido no dio exit 2"

# 7. stdout = una sola linea
LINES=$( (cd "$R1" && bash "$SCRIPT" FEAT 2>/dev/null </dev/null) | wc -l | tr -d ' ')
check "stdout es una sola linea" "$LINES" "1"

echo
if [ "$FAILED" -eq 0 ]; then echo "All next-id tests passed."; exit 0; fi
echo "next-id tests FAILED."
exit 1
