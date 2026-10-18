#!/usr/bin/env bash
# Calcula el siguiente FEAT-NNN / BUG-NNN libre, lo RESERVA (reserve-id.sh) e
# imprime SOLO el ID. Sustituye el grep + ls + reserve de tres pasos que los
# agentes se saltaban (colisiones de IDs medidas en phlou-app).
#
# El maximo se toma de: (a) los archivos vivos, (b) las reservas en
# .git/slate-ids/<PREFIJO>/, (c) los nombres de ramas locales y remotas que
# contengan feat-NNN / bug-NNN. Sin fetch: usa lo que haya. No protege entre
# maquinas o clones que no comparten .git.
#
# Uso: next-id.sh FEAT|BUG      -> imprime p. ej. FEAT-043 (exit 0)
#      uso incorrecto o entorno invalido -> exit 2 con mensaje en stderr
set -uo pipefail

PREFIX="${1:-}"
case "$PREFIX" in
  FEAT) FILES="backlog.md in-progress.md done.md"; DIR=features ;;
  BUG)  FILES="open.md fixed.md"; DIR=bugs ;;
  *) echo "next-id: uso: next-id.sh FEAT|BUG" >&2; exit 2 ;;
esac

TOP="$(git rev-parse --show-toplevel 2>/dev/null)"
GCD="$(git rev-parse --git-common-dir 2>/dev/null)"
if [ -z "$TOP" ] || [ -z "$GCD" ]; then
  echo "next-id: no estas dentro de un repo git" >&2; exit 2
fi
case "$GCD" in /*) : ;; *) GCD="$(pwd)/$GCD" ;; esac

HERE="$(cd "$(dirname "$0")" && pwd)"
LOWER="$(printf '%s' "$PREFIX" | tr 'A-Z' 'a-z')"

# Todos los numeros candidatos, uno por linea (en una sola tuberia, para que el
# maximo se calcule en esta shell y no en una subshell).
# ponytail: ramas solo cuentan con 1-3 digitos tras feat-/bug- al inicio o tras un no-alfanumerico (evita fechas tipo feat-2026-...); subir a {1,4} al pasar de FEAT-999.
nums() {
  for f in $FILES; do
    [ -f "$TOP/docs/slate/$DIR/$f" ] && grep -oE "$PREFIX-[0-9]+" "$TOP/docs/slate/$DIR/$f"
  done
  ls "$GCD/slate-ids/$PREFIX" 2>/dev/null | grep -E '^[0-9]+$'
  git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null \
    | grep -ioE "(^|[^a-z0-9])$LOWER-[0-9]{1,3}([^0-9]|$)" | grep -oE "[0-9]+"
}

max=0
while read -r n; do
  n="${n##*[!0-9]}"                 # solo los digitos finales
  n="${n#"${n%%[!0]*}"}"            # sin ceros a la izquierda ('008' no es octal)
  [ -n "$n" ] && [ "$((10#$n))" -gt "$max" ] && max=$((10#$n))
done < <(nums)

n=$((max + 1))
for _ in $(seq 1 50); do
  ID="$(printf '%s-%03d' "$PREFIX" "$n")"
  bash "$HERE/reserve-id.sh" "$ID" >/dev/null 2>&1
  case $? in
    0) echo "$ID"; exit 0 ;;
    1) n=$((n + 1)) ;;
    *) echo "next-id: reserve-id.sh fallo al reservar $ID" >&2; exit 2 ;;
  esac
done
echo "next-id: no se pudo reservar un ID tras 50 intentos" >&2
exit 2
