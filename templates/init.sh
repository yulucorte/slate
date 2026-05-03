#!/usr/bin/env bash
# This file was installed by claude-harness. Edit it to add project-specific setup.
set -euo pipefail

echo "[init.sh] Starting environment check..."

# 1. Create required directories (idempotent)
mkdir -p progress/subagents progress/transcripts features

# 2. Create missing state files without overwriting existing ones
_create_if_missing() {
  local file="$1"
  local header="$2"
  if [ ! -s "$file" ]; then
    echo "$header" > "$file"
    echo "[init.sh] created $file"
  else
    echo "[init.sh] exists  $file"
  fi
}

_create_if_missing "progress/current.md" "# Current work

_(none in flight)_

<!-- This file is auto-managed by claude-harness:tracking-progress.
     Entries here represent IN-FLIGHT work for the current session.
     At session end, completed entries are moved to history.md;
     orphaned entries become CARRY-OVER. -->"

_create_if_missing "progress/history.md" "# Session history

<!-- Append-only changelog. Never edit existing entries.
     Format: ## YYYY-MM-DD — <session summary>
     Each session adds entries under its heading. -->"

_create_if_missing "features/backlog.md" "# Backlog

<!-- Features wanted but not started. Status: backlog.
     Add via claude-harness:breaking-down-features.
     Move to in-progress.md when work begins. -->"

_create_if_missing "features/in-progress.md" "# In progress

<!-- Features being actively built. Status: in_progress.
     A feature stays here until ALL subtasks are [x] AND Verified is set,
     at which point claude-harness:managing-feature-list moves it to done.md. -->"

_create_if_missing "features/done.md" "# Done

<!-- Completed and verified features. Status: done.
     FORBIDDEN to edit existing entries.
     For changes, create a new feature with \`Supersedes: FEAT-XXX\`. -->"

# 3. Detect project tooling and run setup
if [ -f package.json ] && command -v node >/dev/null 2>&1; then
  echo "[init.sh] node project detected, running npm install..."
  npm install --silent 2>/dev/null || echo "[init.sh] npm install failed (non-fatal)"
fi

if [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  echo "[init.sh] python project detected, set up venv manually"
fi

if [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1; then
  echo "[init.sh] rust project detected, running cargo check..."
  cargo check --quiet 2>/dev/null || echo "[init.sh] cargo check failed (non-fatal)"
fi

if [ -f go.mod ] && command -v go >/dev/null 2>&1; then
  echo "[init.sh] go project detected, running go mod download..."
  go mod download 2>/dev/null || echo "[init.sh] go mod download failed (non-fatal)"
fi

# 4. Smoke test (non-blocking)
if [ -f package.json ] && command -v npm >/dev/null 2>&1; then
  echo "[init.sh] running npm test (60s timeout)..."
  timeout 60 npm test --silent 2>/dev/null || echo "[init.sh] smoke test failed or timed out (non-fatal)"
elif command -v pytest >/dev/null 2>&1 && { [ -f pyproject.toml ] || [ -f setup.py ]; }; then
  echo "[init.sh] running pytest (60s timeout)..."
  timeout 60 pytest -q 2>/dev/null || echo "[init.sh] smoke test failed or timed out (non-fatal)"
elif [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1; then
  echo "[init.sh] running cargo test (60s timeout)..."
  timeout 60 cargo test --quiet 2>/dev/null || echo "[init.sh] smoke test failed or timed out (non-fatal)"
fi

echo "[init.sh] OK at $(date -Iseconds 2>/dev/null || date)"
