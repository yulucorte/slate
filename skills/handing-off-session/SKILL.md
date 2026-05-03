---
name: handing-off-session
description: Use when the user signals the end of a session, before /clear or /compact runs, or when the user says "we're done for today" or similar. Drains progress/current.md into history.md, ensures features/ is consistent, and writes a session summary.
---

# Handing off a session

## When to invoke

- User signals end of session.
- Before manual /compact.
- When SessionEnd hook fires (it calls this implicitly).

## Steps

1. Read `progress/current.md`.
2. For each entry, decide:
   - If task complete: move to `progress/history.md` under today's heading.
   - If task in flight (e.g. dispatched subagent never returned): rewrite the entry as `## CARRY-OVER` and leave it in current.md. Note the reason.
3. Append a final block to today's section in history.md:

    **Session summary**

    - **Tasks completed**: N
    - **Subagents dispatched**: N
    - **Features moved**: FEAT-XXX (backlog→in_progress), FEAT-YYY (in_progress→done)
    - **Open questions for next session**: bullet list, or none

4. Verify `features/in-progress.md` has no entries with all subtasks `[x]` but missing `Verified:` (those are stale).
5. Commit: `git add progress/ features/ && git commit -m "session: <date> handoff"`.

## Anti-patterns

- DO NOT leave dispatched subagents in current.md without marking them as CARRY-OVER. Future sessions will not know they're orphaned.
- DO NOT auto-verify a feature just because all subtasks are checked. Verification is an explicit human/test action.
