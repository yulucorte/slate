---
name: verifying-features
description: Use when a feature in features/in-progress.md is about to move to done.md. Runs as an isolated subagent that validates completion criteria and writes a report to progress/subagents/verify-FEAT-XXX.md without modifying any feature file.
---

# Verifying Features

## Purpose
Subagent that validates a feature meets all completion criteria before it moves to `done.md`. Runs in an isolated context to avoid attention dilution in the main agent.

## When to invoke
- BEFORE any feature moves from `in-progress.md` to `done.md`.
- The main agent MUST spawn this as a subagent (e.g. via the `Agent` tool), not run it inline.

## Files this skill reads (read-only)
1. `features/in-progress.md` — the feature being verified.
2. `features/done.md` — to check for ID conflicts.
3. `progress/current.md` — to cross-reference what was actually done.

The skill MUST NOT write to any of these files. The only file it writes is its own report at `progress/subagents/verify-FEAT-XXX.md`.

## Checks performed

1. **Subtask completion**: source `scripts/lib/parse-features.sh` and call `check_complete features/in-progress.md FEAT-XXX`. The result MUST be `COMPLETE`.
2. **Verification field**: `Verified: <YYYY-MM-DD>` is present under the feature.
3. **ID integrity**: `FEAT-XXX` does NOT already appear in `done.md`.
4. **No orphaned subtasks**: every `FEAT-XXX.N` referenced in the body is checked `[x]`.
5. **Consistency**: the feature's title/description in `in-progress.md` is reflected in at least one entry of `progress/current.md`.

## Output format

Write to `progress/subagents/verify-FEAT-XXX.md`:

    # Verification: FEAT-XXX
    Date: YYYY-MM-DD HH:MM
    Result: PASS | FAIL

    ## Checks
    - [x] All subtasks completed
    - [x] Verified field present (method: unit-test)
    - [x] ID unique in done.md
    - [x] No orphaned subtasks
    - [x] Consistent with progress/current.md

    ## Recommendation
    APPROVE — safe to move to done.md
    — or —
    BLOCK — <one-line reason>

## Rules

- If ANY check fails, the recommendation MUST be `BLOCK` and the feature MUST NOT move to done.md.
- The verifier NEVER modifies feature files — only reads and writes its own report.
- The main agent reads the verification report and acts on it.
- If the verifier itself cannot run (e.g. missing files), it writes a report with `Result: FAIL` and a `BLOCK` recommendation explaining what was missing.
