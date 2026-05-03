#!/usr/bin/env bash
# Commit progress/ and features/ if they have changes. Silent on failure.

cd "${1:-$(pwd)}" || exit 0

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

git add progress/ features/ 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "${2:-auto: harness checkpoint}" --no-verify --quiet 2>/dev/null || true
fi
