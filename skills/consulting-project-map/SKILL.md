---
name: consulting-project-map
description: Use at SessionStart when the project has docs/project-map.md. Loads the project's vision, current phase, and exit criteria as read-only context so suggestions stay aligned with the macro arc and respect any Accepted ADRs.
---

# Consulting the project map

This skill is loaded by `session-start.sh` whenever `docs/project-map.md` exists
in the project. It is **read-only**: the skill never writes the project map,
and Claude must never edit it without being asked.

## What the project map gives you

`docs/project-map.md` answers questions that `features/*.md` cannot:

- **Vision** — what problem the project solves and for whom.
- **Current phase** — MVP, v1, scaling, maintenance. Determines what tradeoffs
  are acceptable (e.g. "throwaway code is fine in MVP" vs. "no breaking
  changes in maintenance").
- **Exit criteria** — measurable conditions for considering the phase done.
- **Future phases** — high-level direction so suggestions today don't paint
  the project into a corner tomorrow.
- **Product areas** — the 3–7 modules that frame the system.

The first 200 lines of this file are injected into the SessionStart additional
context under the `project_map` key.

## What the ADRs give you

`docs/architecture-decisions/ADR-NNN-*.md` are the immutable architectural
commitments of the project. The SessionStart hook does **not** load them
preemptively (they would blow context). Read them **on demand** when:

- You're about to propose a design decision that overlaps an existing area.
- The user references "the ADR on X" or asks why something is the way it is.
- You see a constraint in the project map that suggests an ADR exists.

`Accepted` ADRs are append-only. The `pre-tool-safety` hook rule `ADR_EDIT`
blocks edits to them. If a decision changes, write a **new** ADR with
`Supersedes: ADR-NNN`.

## How to use this context

- Treat the **current phase** as a constraint. Don't suggest scaling work
  during MVP; don't suggest MVP shortcuts during maintenance.
- Treat **Accepted ADRs** as the project's contract with itself. Propose
  changes only by suggesting a new ADR — never edit an old one.
- When a user request conflicts with the project map (e.g. requesting v2-scope
  work while phase says MVP), surface the conflict before proceeding.

## Anti-patterns

- DO NOT edit `docs/project-map.md` automatically. It is a human-curated
  document; changing the phase is a deliberate decision.
- DO NOT write ADRs on the user's behalf. ADRs are decisions, not summaries.
  Offer to draft one if the user asks, but the user owns the content.
- DO NOT inject all ADRs into every session. Read them on demand.
- DO NOT treat the project map as authoritative when it disagrees with the
  code — the map can be stale. Surface the discrepancy and ask.
