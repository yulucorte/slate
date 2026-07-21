---
name: managing-ideas
description: Use when the user wants to jot down a future idea mid-session ("anota esta idea...", "se me ocurrió que...", or /idea), or when running /ideas-triage to group, prioritize, and promote/archive accumulated ideas. Maintains docs/slate/ideas/inbox.md and docs/slate/ideas/triaged.md.
---

# Managing ideas

Two triggers, one skill — same shape as `managing-feature-list` covering
multiple lifecycle stages.

## Capture (low friction — no judgment calls)

Trigger: the user says something like "anota esta idea...", "se me ocurrió
que...", or runs `/idea "<text>"`.

Action: append one line to `docs/slate/ideas/inbox.md`:

    - YYYY-MM-DD HH:MM — <raw idea text, verbatim>

Do not categorize, prioritize, or ask clarifying questions at capture time.
The whole point is zero interruption to the current flow.

## Triage (explicit, on demand)

Trigger: the user runs `/ideas-triage`.

Steps:

1. Read `docs/slate/ideas/inbox.md` in full (it's meant to stay short between triage
   passes).
2. Group the lines by area: frontend, backend, db, ux, other. Propose a
   priority (low/med/high) per group based on your judgment of impact/effort.
3. Present the grouped list to the user and ask, per idea (or per group if
   they're fine batching): promote, archive, or keep pending.
4. For each `promote`: invoke `breaking-down-features` to create the
   `FEAT-XXX` entry, then log the idea in `docs/slate/ideas/triaged.md` with
   `Outcome: promoted:FEAT-XXX`, and remove that line from `docs/slate/ideas/inbox.md`.
5. For each `archive`: log with `Outcome: archived`, remove the line from
   `docs/slate/ideas/inbox.md`.
6. For each `keep pending`: log with `Outcome: kept-pending`, but leave the
   line in `docs/slate/ideas/inbox.md` untouched — it comes up again next triage.

See `docs/idea-format.md` for the exact entry formats.

## Anti-patterns

- DO NOT categorize or prioritize at capture time — that's triage's job.
- DO NOT edit or delete existing entries in `docs/slate/ideas/triaged.md`. It is
  append-only.
- DO NOT silently drop a `kept-pending` idea from `inbox.md` — only
  `promoted` and `archived` outcomes remove the line.
- DO NOT invent a `FEAT-XXX` ID yourself when promoting — always go through
  `breaking-down-features` so ID assignment stays centralized.
