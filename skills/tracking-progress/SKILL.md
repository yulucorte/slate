---
name: tracking-progress
description: Use when dispatching a subagent, when receiving a subagent report, when starting or finishing a task, or when the user asks "where are we". Maintains progress/current.md (live state), progress/history.md (append-only), and progress/subagents/*.md (per-subagent reports).
---

# Tracking progress

## When to invoke (triggers)

- Before any `Task` tool call that dispatches a subagent.
- After any subagent returns (regardless of status).
- When marking a TodoWrite item complete.
- When the user asks for status, recap, or "what's been done".

## What to write

### Before dispatching subagent

Append to `progress/current.md`:

    ### <timestamp ISO-8601> — Dispatched <subagent-type>
    - **Task**: <one-line task summary>
    - **Feature ref**: FEAT-XXX (if applicable)
    - **Plan ref**: docs/superpowers/plans/<file>.md#task-N
    - **Status**: dispatched

### After subagent returns

1. Write the FULL subagent report to `progress/subagents/<task-slug>-<status>.md`. Filename example: `progress/subagents/feat-001-2-jwt-DONE.md`.
2. Update the corresponding entry in `current.md`:

    ### <timestamp> — <subagent-type> returned
    - **Status**: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
    - **Report**: progress/subagents/<task-slug>-<status>.md
    - **Concerns** (if any): <brief>

### At task complete

Move the entry block from `current.md` to `progress/history.md` under a heading `## YYYY-MM-DD — <session-summary>` (create the heading once per session, append entries to it).

## Format rules

- Timestamps: ISO-8601 with timezone (`date -Iseconds`).
- Filenames in `progress/subagents/`: lowercase, hyphenated, end with status in caps.
- Never delete from `history.md`. If something is wrong, append a correction with `## CORRECTION` heading.

## Anti-patterns

- DO NOT summarize old history.md entries to keep the file short. Use git log for that.
- DO NOT skip writing the subagent report file because "I already updated current.md". Both are required.
- DO NOT use relative timestamps ("yesterday", "earlier"). Always absolute.
