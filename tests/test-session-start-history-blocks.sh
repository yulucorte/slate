#!/usr/bin/env bash
# BUG-007: el resumen de historial al arrancar muestra bloques (encabezado +
# primeras lineas), no las ultimas N lineas sueltas.
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

P="$TMP/p"
mkdir -p "$P/docs/slate/progress" "$P/docs/slate/features"
printf '# In progress\n' > "$P/docs/slate/features/in-progress.md"
printf '# Current work\n\n_(none in flight)_\n' > "$P/docs/slate/progress/current.md"
cat > "$P/docs/slate/progress/history.md" <<'EOF'
# Session history

## 2026-10-01 — cierre A
- A1
- A2
- A3

## 2026-10-02 10:00:00 — Session end
# Current work

_(none in flight)_

<!-- This file is auto-managed by slate:tracking-progress.
     Entries here represent IN-FLIGHT work for the current session.
     At session end, completed entries are moved to history.md;
     orphaned entries become CARRY-OVER. -->

## 2026-10-03 — cierre B
- B1
- B2
- B3
EOF

start() { printf '{"source":"%s"}' "$1" | (cd "$P" && CLAUDE_PROJECT_ROOT="$P" bash "$PLUGIN_ROOT/hooks/session-start.sh" 2>/dev/null); }
has()  { printf '%s' "$1" | grep -qF -- "$2"; }

OUT=$(start startup)
for w in "cierre A" "- A1" "- A2" "cierre B" "- B1" "- B2"; do
  has "$OUT" "$w" && pass "startup contiene '$w'" || fail "startup no contiene '$w'"
done
for w in "A3" "B3" "Session end"; do
  has "$OUT" "$w" && fail "startup NO debe contener '$w'" || pass "startup no contiene '$w'"
done

OUT=$(start compact)
for w in "cierre B" "- B1"; do
  has "$OUT" "$w" && pass "compact contiene '$w'" || fail "compact no contiene '$w'"
done
for w in "B2" "cierre A"; do
  has "$OUT" "$w" && fail "compact NO debe contener '$w'" || pass "compact no contiene '$w'"
done

echo
if [ "$FAILED" -eq 0 ]; then echo "All history-block tests passed."; exit 0; fi
echo "history-block tests FAILED."
exit 1
