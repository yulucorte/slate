#!/usr/bin/env bash
# BUG-006: dentro de un subagente (payload con agent_id) los hooks de cierre y
# latido no tocan candados ni drenan estado.
set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILED=1; }

R="$TMP/r"
mkdir -p "$R/docs/slate/progress"
git -C "$R" init -q -b feat/x .
git -C "$R" config user.email t@t.co; git -C "$R" config user.name t
printf '# Current work\n\n### FEAT-1 en vuelo\n' > "$R/docs/slate/progress/current.md"
printf '# Session history\n' > "$R/docs/slate/progress/history.md"
git -C "$R" add -A; git -C "$R" commit -q -m init
git -C "$R" worktree add -q "$TMP/W" -b feat/w

LOCKDIR="$R/.git/slate-sessions"
mkdir -p "$LOCKDIR"
mklock() {
  printf '{"branch":"feat/x","head":"abc","cwd":"%s","files":[]}' "$R" > "$LOCKDIR/S1.lock"
  touch -t "$(date -v-10M '+%Y%m%d%H%M' 2>/dev/null || date -d '10 minutes ago' '+%Y%m%d%H%M')" "$LOCKDIR/S1.lock"
}
mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }

# --- session-end.sh con agent_id: current.md / history.md intactos ----------
mklock
C0=$(cat "$R/docs/slate/progress/current.md"); H0=$(cat "$R/docs/slate/progress/history.md")
CLAUDE_PROJECT_ROOT="$R" bash "$PLUGIN_ROOT/hooks/session-end.sh" <<< '{"session_id":"S1","agent_id":"a1"}' >/dev/null 2>&1
if [ "$C0" = "$(cat "$R/docs/slate/progress/current.md")" ] && [ "$H0" = "$(cat "$R/docs/slate/progress/history.md")" ]; then
  pass "session-end con agent_id no drena"
else
  fail "session-end con agent_id drenó estado"
fi

# --- session-lock-cleanup.sh con agent_id: el candado sobrevive -------------
CLAUDE_PROJECT_ROOT="$R" bash "$PLUGIN_ROOT/hooks/session-lock-cleanup.sh" <<< '{"session_id":"S1","agent_id":"a1"}' >/dev/null 2>&1
if [ -f "$LOCKDIR/S1.lock" ]; then
  pass "lock-cleanup con agent_id no borra el candado"
else
  fail "lock-cleanup con agent_id borró el candado del padre"
fi

# --- heartbeat con agent_id: solo mtime, contenido idéntico -----------------
mklock
BEFORE=$(cat "$LOCKDIR/S1.lock"); M0=$(mtime "$LOCKDIR/S1.lock")
CLAUDE_PROJECT_ROOT="$R" bash "$PLUGIN_ROOT/hooks/session-heartbeat.sh" \
  <<< "{\"session_id\":\"S1\",\"agent_id\":\"a1\",\"cwd\":\"$TMP/W\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"x\"}}" >/dev/null 2>&1
M1=$(mtime "$LOCKDIR/S1.lock")
if [ "$M1" -gt "$M0" ]; then pass "heartbeat con agent_id refresca el mtime"; else fail "heartbeat con agent_id no refrescó el mtime"; fi
if [ "$BEFORE" = "$(cat "$LOCKDIR/S1.lock")" ]; then
  pass "heartbeat con agent_id no cambia el contenido del candado"
else
  fail "heartbeat con agent_id modificó el candado: $(cat "$LOCKDIR/S1.lock")"
fi

# --- heartbeat con agent_id y sin candado: no lo crea -----------------------
CLAUDE_PROJECT_ROOT="$R" bash "$PLUGIN_ROOT/hooks/session-heartbeat.sh" \
  <<< "{\"session_id\":\"S2\",\"agent_id\":\"a2\",\"cwd\":\"$R\"}" >/dev/null 2>&1
if [ ! -e "$LOCKDIR/S2.lock" ]; then pass "heartbeat con agent_id no crea candado"; else fail "heartbeat con agent_id creó S2.lock"; fi

# --- Control: sin agent_id el comportamiento actual se mantiene -------------
CLAUDE_PROJECT_ROOT="$R" bash "$PLUGIN_ROOT/hooks/session-heartbeat.sh" \
  <<< "{\"session_id\":\"S3\",\"cwd\":\"$R\"}" >/dev/null 2>&1
if [ -f "$LOCKDIR/S3.lock" ]; then pass "control: heartbeat sin agent_id recrea el candado"; else fail "control: heartbeat sin agent_id no recreó"; fi

CLAUDE_PROJECT_ROOT="$R" bash "$PLUGIN_ROOT/hooks/session-lock-cleanup.sh" <<< '{"session_id":"S1"}' >/dev/null 2>&1
if [ ! -e "$LOCKDIR/S1.lock" ]; then pass "control: cleanup sin agent_id borra el candado"; else fail "control: cleanup sin agent_id no borró"; fi

echo
if [ "$FAILED" -eq 0 ]; then echo "All subagent hook tests passed."; exit 0; fi
echo "subagent hook tests FAILED."
exit 1
