---
name: tracking-progress
description: Use when dispatching a subagent, when receiving a subagent report, when starting or finishing a task, or when the user asks "where are we". Maintains docs/slate/progress/current.md (live state), docs/slate/progress/history.md (append-only), and docs/slate/progress/subagents/*.md (per-subagent reports).
---

# Tracking progress

## When to invoke (triggers)

- Before any `Task` tool call that dispatches a subagent.
- After any subagent returns (regardless of status).
- When marking a TodoWrite item complete.
- When the user asks for status, recap, or "what's been done".

## What to write

### Before dispatching subagent

Append to `docs/slate/progress/current.md`:

    ### <timestamp ISO-8601> — Dispatched <subagent-type>
    - **Task**: <one-line task summary>
    - **Feature ref**: FEAT-XXX (if applicable)
    - **Plan ref**: docs/superpowers/plans/<file>.md#task-N
    - **Status**: dispatched

### After subagent returns

1. Write the FULL subagent report to `docs/slate/progress/subagents/<task-slug>-<status>.md`. Filename example: `docs/slate/progress/subagents/feat-001-2-jwt-DONE.md`.
2. Update the corresponding entry in `current.md`:

    ### <timestamp> — <subagent-type> returned
    - **Status**: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
    - **Report**: docs/slate/progress/subagents/<task-slug>-<status>.md
    - **Concerns** (if any): <brief>

### At task complete

Move the entry block from `current.md` to `docs/slate/progress/history.md` under a heading `## YYYY-MM-DD — <session-summary>` (create the heading once per session, append entries to it).

## Archiving history.md

`history.md` is append-only and grows without bound. When it exceeds **40
session blocks** (`## YYYY-MM-DD — <summary>` headings), move the **oldest**
blocks in bulk — leaving the ~20 most recent — into
`docs/slate/progress/history-archive-YYYYHn.md` (`H1` = Jan–Jun, `H2` = Jul–Dec, by today's
date). Blocks move **intact**, oldest-first. This is NOT summarizing (see the
anti-pattern below): a bulk move preserves every word, it just relocates it.
Full reference in `docs/archiving.md`. `session-start.sh` only tails the live
`history.md`, so archiving never affects the injected recap.

## Format rules

- Timestamps: ISO-8601 with timezone (`date -Iseconds`).
- Filenames in `docs/slate/progress/subagents/`: lowercase, hyphenated, end with status in caps.
- Never delete from `history.md`. If something is wrong, append a correction with `## CORRECTION` heading.

## Anti-patterns
- DO NOT summarize or rewrite old history.md entries to keep the file short. If the file is large, ARCHIVE it (bulk move of intact blocks, see above) — do not compress or paraphrase, and do not lean on git log as a substitute for the record.
- DO NOT skip writing the subagent report file because "I already updated current.md". Both are required.
- DO NOT use relative timestamps ("yesterday", "earlier"). Always absolute.
