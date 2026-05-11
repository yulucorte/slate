#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init -q -b main

CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$PLUGIN_ROOT/scripts/install-into-project.sh" >/dev/null

# Config copied
if [ ! -f "$TMPDIR/.claude-harness/config.sh" ]; then
  echo "FAIL: .claude-harness/config.sh not copied"
  exit 1
fi
echo "PASS: config.sh copied"

# Hooks log initialized
if [ ! -f "$TMPDIR/progress/hooks.log" ]; then
  echo "FAIL: progress/hooks.log not created"
  exit 1
fi
echo "PASS: hooks.log created"

# Gitignore entries
for entry in 'progress/hooks.log' '.claude-harness/config.local.sh' 'progress/.in-progress.snapshot' 'progress/.done.snapshot'; do
  if ! grep -qF "$entry" "$TMPDIR/.gitignore" 2>/dev/null; then
    echo "FAIL: .gitignore missing '$entry'"
    cat "$TMPDIR/.gitignore" 2>/dev/null
    exit 1
  fi
done
echo "PASS: gitignore has all required entries"

# Hooks are executable
for hook in post-edit-format.sh pre-tool-safety.sh stop-notify.sh post-edit-in-progress-watcher.sh post-edit-done-watcher.sh; do
  if [ ! -x "$PLUGIN_ROOT/hooks/$hook" ]; then
    echo "FAIL: $hook not executable"
    exit 1
  fi
done
echo "PASS: all new hooks are executable"

# Snapshot bootstrap: snapshots should exist after install (empty for fresh template)
for snap in .in-progress.snapshot .done.snapshot; do
  if [ ! -f "$TMPDIR/progress/$snap" ]; then
    echo "FAIL: progress/$snap not pre-populated"
    exit 1
  fi
done
echo "PASS: snapshots pre-populated"

cd /
rm -rf "$TMPDIR"
echo "All install-v02 tests passed."
