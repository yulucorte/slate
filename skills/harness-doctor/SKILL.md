---
name: harness-doctor
description: Use when the user asks to diagnose claude-harness setup, says hooks aren't working, mentions "doctor", asks "what's wrong with harness", or after install to verify everything is ready. Runs scripts/harness/doctor.sh and explains the output with prioritized fix actions.
---

# claude-harness doctor

Diagnose the project's claude-harness install and tell the user exactly what to fix.

## When to invoke

- User says: "diagnose harness", "what's wrong with harness", "is harness set up correctly?", "harness doctor"
- After running `install-into-project.sh` to verify
- When the user reports a hook misbehaving
- Before the user enables `HARNESS_AUTO_PR=true` or `HARNESS_AUTO_BRANCH=true`

## How to invoke

Run the diagnostic script and present results:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/harness/doctor.sh"
```

The script prints each check with ✓ / ! / ✗ and includes a `Fix:` line for any failure. Exit code 0 = healthy, 1 = critical issues.

## Reporting to the user

1. If exit code 0: confirm the install is healthy in one line.
2. If exit code 1: list the ✗ items first (critical), then ! items (warnings), with the suggested Fix command for each. Group by category (config / CLIs / hooks / logs).
3. Offer to walk the user through running the first Fix command. Do NOT run installation commands (e.g. `brew install`, `gh auth login`, `npm install -g`) automatically — these need user consent.
4. After the user fixes something, offer to re-run the diagnostic.

## What to avoid

- Don't run `brew install`, `gh auth login`, or `pip install` without explicit user permission.
- Don't recommend disabling safety rules unless the user asks specifically.
- Don't modify `.claude-harness/config.sh` from this skill — point the user to the file and the variable to change.
