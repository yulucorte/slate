#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
export PROJECT_ROOT="$TMPDIR"
mkdir -p "$TMPDIR/progress"
export HARNESS_LOG_MAX_BYTES=200
export HARNESS_LOG_ROTATIONS=2

LOG="$PROJECT_ROOT/progress/hooks.log"
SCRIPT="$PLUGIN_ROOT/hooks/lib/log-hook-event.sh"

# Test 1: basic format
"$SCRIPT" test-hook SUCCESS key1=val1 key2=val2
line=$(cat "$LOG")
if ! echo "$line" | grep -qE '^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\] test-hook SUCCESS key1=val1 key2=val2$'; then
  echo "FAIL format: got '$line'"
  exit 1
fi
echo "PASS: log format"

# Test 2: append, not overwrite
"$SCRIPT" test-hook SKIP reason=test
lines=$(wc -l < "$LOG" | tr -d ' ')
if [ "$lines" != "2" ]; then
  echo "FAIL append: expected 2 lines, got $lines"
  exit 1
fi
echo "PASS: append mode"

# Test 3: rotation triggers when log exceeds max bytes
for i in 1 2 3 4 5 6 7 8 9 10; do
  "$SCRIPT" test-hook INFO iteration="$i" padding=xxxxxxxxxxxxxxxxxxxxxxxxxx
done
if [ ! -f "$LOG.1" ]; then
  echo "FAIL rotation: $LOG.1 does not exist"
  ls -la "$TMPDIR/progress"
  exit 1
fi
echo "PASS: rotation creates .1"

# Test 4: oldest rotation deleted when count exceeds HARNESS_LOG_ROTATIONS
for i in 1 2 3 4 5 6 7 8 9 10; do
  "$SCRIPT" test-hook INFO iteration="$i" padding=xxxxxxxxxxxxxxxxxxxxxxxxxx
done
# With HARNESS_LOG_ROTATIONS=2 we should have at most: hooks.log + hooks.log.1 + hooks.log.2.gz
if [ -f "$LOG.3" ] || [ -f "$LOG.3.gz" ]; then
  echo "FAIL retention: too many rotations exist"
  ls -la "$TMPDIR/progress"
  exit 1
fi
echo "PASS: rotation retention"

# Test 5: oldest is gzipped
if [ ! -f "$LOG.2.gz" ]; then
  echo "FAIL gzip: $LOG.2.gz expected"
  ls -la "$TMPDIR/progress"
  exit 1
fi
echo "PASS: oldest rotation gzipped"

rm -rf "$TMPDIR"
echo "All log-hook-event tests passed."
