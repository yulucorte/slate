#!/usr/bin/env bash
set -e
trap 'echo "FAIL at line $LINENO"' ERR

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$PLUGIN_ROOT/hooks/lib/defaults.sh"

expect_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" != "$actual" ]; then
    echo "FAIL $name: expected '$expected', got '$actual'"
    exit 1
  fi
  echo "PASS: $name=$actual"
}

expect_eq "HARNESS_FORMATTER" "none" "$HARNESS_FORMATTER"
expect_eq "HARNESS_NOTIFY" "true" "$HARNESS_NOTIFY"
expect_eq "HARNESS_AUTO_BRANCH" "false" "$HARNESS_AUTO_BRANCH"
expect_eq "HARNESS_AUTO_PR" "false" "$HARNESS_AUTO_PR"
expect_eq "HARNESS_SAFETY_RULES" "strict" "$HARNESS_SAFETY_RULES"
expect_eq "HARNESS_GITHUB_BASE" "main" "$HARNESS_GITHUB_BASE"
expect_eq "HARNESS_ALLOW_RM_HOME" "false" "$HARNESS_ALLOW_RM_HOME"
expect_eq "HARNESS_ALLOW_FORCE_PUSH_MAIN" "false" "$HARNESS_ALLOW_FORCE_PUSH_MAIN"
expect_eq "HARNESS_ALLOW_RESET_HARD" "false" "$HARNESS_ALLOW_RESET_HARD"
expect_eq "HARNESS_ALLOW_CONFIG_EDIT" "false" "$HARNESS_ALLOW_CONFIG_EDIT"
expect_eq "HARNESS_ALLOW_ADR_EDIT" "false" "$HARNESS_ALLOW_ADR_EDIT"
expect_eq "HARNESS_LOG_MAX_BYTES" "5242880" "$HARNESS_LOG_MAX_BYTES"
expect_eq "HARNESS_LOG_ROTATIONS" "3" "$HARNESS_LOG_ROTATIONS"

echo "All defaults tests passed."
