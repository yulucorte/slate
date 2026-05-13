# claude-harness project configuration
# This file controls which hooks are active and how they behave.
# Per-user overrides go in .claude-harness/config.local.sh (gitignored).

# Formatter to run on edited files
# Values: prettier | gofmt | ruff | none
HARNESS_FORMATTER=none

# OS notification when Claude finishes responding
HARNESS_NOTIFY=true

# Automatic branch creation when a feature enters in-progress.md.
# Default false: claude-harness only suggests the command. Set true to let
# the post-edit-in-progress-watcher hook run `git switch -c` automatically.
HARNESS_AUTO_BRANCH=false

# Automatic PR open when a feature enters done.md.
# Default false: a notification is sent and you run `gh pr create` manually.
HARNESS_AUTO_PR=false

# Safety rule mode
# Values: strict | permissive (permissive logs matches but does not block)
HARNESS_SAFETY_RULES=strict

# Base branch for automatically opened PRs
HARNESS_GITHUB_BASE=main

# Per-rule safety overrides (only honored when HARNESS_SAFETY_RULES=strict)
# Set any to "true" to disable that specific rule.
HARNESS_ALLOW_RM_HOME=false
HARNESS_ALLOW_FORCE_PUSH_MAIN=false
HARNESS_ALLOW_RESET_HARD=false
HARNESS_ALLOW_CONFIG_EDIT=false
HARNESS_ALLOW_ADR_EDIT=false

# Log rotation
HARNESS_LOG_MAX_BYTES=5242880        # 5 MB
HARNESS_LOG_ROTATIONS=3
