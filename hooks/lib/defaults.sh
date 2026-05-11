#!/usr/bin/env bash
# Baked-in defaults for claude-harness project hooks.
# Sourced FIRST, before any user config. Never edit at runtime — override via
# .claude-harness/config.sh (project) or .claude-harness/config.local.sh (user).

: "${HARNESS_FORMATTER:=none}"
: "${HARNESS_NOTIFY:=true}"
: "${HARNESS_AUTO_BRANCH:=false}"
: "${HARNESS_AUTO_PR:=false}"
: "${HARNESS_SAFETY_RULES:=strict}"
: "${HARNESS_GITHUB_BASE:=main}"

: "${HARNESS_ALLOW_RM_HOME:=false}"
: "${HARNESS_ALLOW_FORCE_PUSH_MAIN:=false}"
: "${HARNESS_ALLOW_RESET_HARD:=false}"
: "${HARNESS_ALLOW_CONFIG_EDIT:=false}"

: "${HARNESS_LOG_MAX_BYTES:=5242880}"
: "${HARNESS_LOG_ROTATIONS:=3}"
