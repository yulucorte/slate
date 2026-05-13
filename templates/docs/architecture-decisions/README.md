# Architecture Decision Records

Append-only log of architectural decisions for this project. Each ADR captures
the context, the decision, and the consequences at the moment the decision was
taken. ADRs are **not** living documents — once `Accepted`, they are immutable.

## File naming

`ADR-NNN-<slug>.md` where `NNN` is a zero-padded sequential number and `<slug>`
is a short kebab-case summary.

Examples:
- `ADR-001-use-postgres.md`
- `ADR-002-monolith-over-microservices.md`
- `ADR-003-no-orm.md`

## Minimum structure

```markdown
# ADR-NNN: <Title>

Status: Proposed | Accepted | Superseded
Date: YYYY-MM-DD
Supersedes: ADR-XXX        # only if this ADR replaces a previous one

## Context
What forces are at play? What problem are we solving? What constraints do we
have (technical, organizational, regulatory)?

## Decision
What did we decide? Be concrete and unambiguous.

## Consequences
What changes after this decision? What becomes easier? What becomes harder?
What can we no longer do? What new risks did we accept?
```

## Lifecycle

1. **Proposed** — draft. Free to edit while gathering feedback.
2. **Accepted** — the decision is live. The file becomes **append-only**: the
   `pre-tool-safety` hook (rule `ADR_EDIT`) blocks edits to Accepted ADRs.
3. **Superseded** — a newer ADR replaces this one. The only edit allowed on an
   Accepted ADR is changing `Status: Accepted` to `Status: Superseded` (the
   safety hook permits this exact transition). Then create a new ADR with a
   `Supersedes: ADR-NNN` header.

## Why append-only

Architectural decisions are made under specific constraints at a specific time.
Rewriting a past ADR rewrites the historical reasoning and silently changes
what future contributors think the project committed to. If the decision
changes, write a new ADR. The old one stays as honest history.

## Bypassing the safety hook (use sparingly)

If you genuinely need to edit an Accepted ADR (typo fix, broken markdown), set
`HARNESS_ALLOW_ADR_EDIT=true` in `.claude-harness/config.local.sh` for the
duration of the edit, then unset it. Substantive changes should always be a new
ADR.
