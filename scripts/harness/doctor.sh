#!/usr/bin/env bash
# claude-harness doctor: diagnoses install state and prints concrete fixes.
# Exits 0 if no critical issues, 1 if a critical check fails.

set -u

CLAUDE_PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
: "${PROJECT_ROOT:=$(pwd)}"

fails=0
warns=0

header() {
  echo "claude-harness doctor — $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Project: $PROJECT_ROOT"
  echo "Plugin:  $CLAUDE_PLUGIN_ROOT"
  echo "---"
}

ok()    { echo "  ✓ $1"; }
warn()  { echo "  ! $1"; [ -n "${2:-}" ] && echo "     Fix: $2"; warns=$((warns+1)); }
fail()  { echo "  ✗ $1"; [ -n "${2:-}" ] && echo "     Fix: $2"; fails=$((fails+1)); }

check_config() {
  echo
  echo "Project config"
  if [ ! -f "$PROJECT_ROOT/.claude-harness/config.sh" ]; then
    fail "missing $PROJECT_ROOT/.claude-harness/config.sh" \
         "run: bash $CLAUDE_PLUGIN_ROOT/scripts/install-into-project.sh"
    return
  fi
  if ! bash -n "$PROJECT_ROOT/.claude-harness/config.sh" 2>/dev/null; then
    fail "config.sh has bash syntax errors" \
         "review with: bash -n $PROJECT_ROOT/.claude-harness/config.sh"
    return
  fi
  ok "config.sh exists and parses"
}

check_state_dirs() {
  echo
  echo "State directories"
  for d in features progress; do
    if [ -d "$PROJECT_ROOT/$d" ]; then
      ok "$d/ exists"
    else
      fail "$d/ directory missing" \
           "run: bash $CLAUDE_PLUGIN_ROOT/scripts/install-into-project.sh"
    fi
  done
}

check_external_clis() {
  echo
  echo "External CLIs"

  # Load config to know what's needed
  if [ -f "$PROJECT_ROOT/.claude-harness/config.sh" ]; then
    # shellcheck disable=SC1090
    source "$PROJECT_ROOT/.claude-harness/config.sh" 2>/dev/null || true
  fi
  : "${HARNESS_AUTO_PR:=false}"
  : "${HARNESS_FORMATTER:=none}"

  # flock (always required by watcher hooks)
  if command -v flock >/dev/null 2>&1; then
    ok "flock present"
  else
    fail "flock not installed (watcher hooks need it)" \
         "macOS: brew install flock | Linux: apt-get install util-linux"
  fi

  # gh (conditional on AUTO_PR)
  if [ "$HARNESS_AUTO_PR" = "true" ]; then
    if ! command -v gh >/dev/null 2>&1; then
      fail "gh CLI not installed but HARNESS_AUTO_PR=true" \
           "macOS: brew install gh | Linux: see https://cli.github.com/"
    elif ! gh auth status >/dev/null 2>&1; then
      fail "gh CLI not authenticated" \
           "run: gh auth login"
    else
      ok "gh CLI installed and authenticated"
    fi
  else
    if command -v gh >/dev/null 2>&1; then
      ok "gh CLI present (optional — AUTO_PR=false)"
    else
      warn "gh CLI not installed (optional unless AUTO_PR=true)" \
           "skip unless you plan to use auto-PR"
    fi
  fi

  # formatter (conditional)
  case "$HARNESS_FORMATTER" in
    prettier) command -v prettier >/dev/null 2>&1 && ok "prettier present" \
                || warn "HARNESS_FORMATTER=prettier but binary missing" "npm i -g prettier" ;;
    gofmt)    command -v gofmt >/dev/null 2>&1 && ok "gofmt present" \
                || warn "HARNESS_FORMATTER=gofmt but binary missing" "install Go toolchain" ;;
    ruff)     command -v ruff >/dev/null 2>&1 && ok "ruff present" \
                || warn "HARNESS_FORMATTER=ruff but binary missing" "pip install ruff" ;;
    none|"")  ok "no formatter configured (HARNESS_FORMATTER=none)" ;;
    *)        warn "unknown HARNESS_FORMATTER=$HARNESS_FORMATTER" "set to: prettier|gofmt|ruff|none" ;;
  esac
}

check_hooks_registration() {
  echo
  echo "Plugin hooks"
  local hf="$CLAUDE_PLUGIN_ROOT/hooks/hooks.json"
  if [ ! -f "$hf" ]; then
    fail "hooks.json missing at $hf" "reinstall the plugin"
    return
  fi
  if ! grep -q '"hooks"' "$hf" 2>/dev/null; then
    fail "hooks.json doesn't contain a hooks array" "reinstall the plugin"
    return
  fi
  ok "hooks.json present"
}

check_logs() {
  echo
  echo "Log state"
  local log="$PROJECT_ROOT/progress/hooks.log"
  if [ -f "$log" ]; then
    local size; size=$(wc -c < "$log" 2>/dev/null | tr -d ' ')
    ok "hooks.log present (${size:-0} bytes)"
  else
    ok "hooks.log not yet created (no hooks have fired)"
  fi
}

summary() {
  echo
  echo "---"
  if [ "$fails" -eq 0 ] && [ "$warns" -eq 0 ]; then
    echo "Result: all checks passed."
    return 0
  fi
  echo "Result: $fails failed, $warns warnings."
  if [ "$fails" -gt 0 ]; then
    echo "Address the ✗ items above before relying on hook automation."
    return 1
  fi
  return 0
}

header
check_config
check_state_dirs
check_external_clis
check_hooks_registration
check_logs
summary
