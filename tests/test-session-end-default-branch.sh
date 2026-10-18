#!/usr/bin/env bash
# BUG-004: session-end.sh no debe ensuciar la rama por defecto cuando
# current.md viene de commits mergeados (sin cambios sin commitear).
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

mkrepo() {
  local d="$1" branch="$2"
  mkdir -p "$d/docs/slate/progress"
  git -C "$d" init -q -b "$branch" .
  git -C "$d" config user.email t@t.co; git -C "$d" config user.name t
  printf '# Current work\n\n### FEAT-1 en vuelo\n' > "$d/docs/slate/progress/current.md"
  printf '# Session history\n' > "$d/docs/slate/progress/history.md"
  git -C "$d" add -A
  git -C "$d" commit -q -m init
}

run_end() { CLAUDE_PROJECT_ROOT="$1" bash "$PLUGIN_ROOT/hooks/session-end.sh" </dev/null >/dev/null 2>&1; }

# 1. main + current.md commiteado y limpio -> no se ensucia
R1="$TMP/r1"; mkrepo "$R1" main
run_end "$R1"
if [ -z "$(git -C "$R1" status --porcelain)" ]; then
  pass "main con current.md commiteado no se ensucia"
else
  fail "main con current.md commiteado quedo sucio: $(git -C "$R1" status --porcelain)"
fi

# 2. main + current.md modificado sin commitear -> se drena
R2="$TMP/r2"; mkrepo "$R2" main
printf '### FEAT-2 en vuelo\n' >> "$R2/docs/slate/progress/current.md"
run_end "$R2"
if grep -q 'FEAT-2' "$R2/docs/slate/progress/history.md"; then
  pass "main con trabajo sin commitear si se drena"
else
  fail "main con trabajo sin commitear NO se drenó"
fi

# 3. rama de trabajo -> drena como siempre
R3="$TMP/r3"; mkrepo "$R3" feat/x
run_end "$R3"
if grep -q 'FEAT-1' "$R3/docs/slate/progress/history.md"; then
  pass "rama de trabajo drena como siempre"
else
  fail "rama de trabajo no drenó"
fi

# 4. origin/HEAD -> develop, sesion en develop con current.md limpio
R4="$TMP/r4"; mkrepo "$R4" develop
git -C "$R4" update-ref refs/remotes/origin/develop HEAD
git -C "$R4" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
run_end "$R4"
if [ -z "$(git -C "$R4" status --porcelain)" ]; then
  pass "develop (origin/HEAD) con current.md limpio no se ensucia"
else
  fail "develop quedo sucio: $(git -C "$R4" status --porcelain)"
fi

echo
if [ "$FAILED" -eq 0 ]; then echo "All default-branch session-end tests passed."; exit 0; fi
echo "default-branch session-end tests FAILED."
exit 1
