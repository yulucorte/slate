---
name: harness-open-pr
description: Use when the user asks to open a PR for a claude-harness feature, says "open PR for FEAT-X", "create a pull request for the dark-mode feature", or wants to manually trigger the PR open script when HARNESS_AUTO_PR=false. Wraps scripts/harness/pr-open.sh.
---

# Open a PR for a harness feature

Manually trigger `pr-open.sh` for a completed feature. Used when `HARNESS_AUTO_PR=false` (the default) and the user wants to open the PR explicitly.

## When to invoke

- User says: "open PR for FEAT-X", "open the dark-mode PR", "create PR for the feature I just finished"
- After a feature lands in `features/done.md` and the user wants the PR opened
- After a watcher hook printed a `→ harness: FEAT-X ready for PR` suggestion

## Preconditions to verify

1. The feature exists in `features/done.md` (not `in-progress.md`). If not, ask the user whether they want to mark it done first.
2. The current git branch matches the feature's `Branch:` field. If not, surface the mismatch and ask whether to switch first.
3. `gh` CLI installed and authenticated. If unsure, invoke the `harness-doctor` skill.

## How to invoke

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/harness/pr-open.sh" "<FEAT-ID>"
```

The script handles idempotency (if a PR already exists for the branch, it reports it and exits 0).

## Reporting to the user

- Success: print the PR URL the script outputs.
- Failure: read the recent lines of `progress/hooks.log` for the error reason, present it, and suggest `harness-doctor` if the cause is unclear.
