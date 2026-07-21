# Idea Format Reference

## Inbox entry (docs/slate/ideas/inbox.md)

Deliberately minimal — capture must never interrupt flow.

    - YYYY-MM-DD HH:MM — <raw idea text, verbatim>

No area, priority, or status at capture time. `docs/slate/ideas/inbox.md` is a mutable
working queue: lines are removed once triaged (promoted or archived).
Lines left `kept-pending` stay in the queue untouched.

## Triaged entry (docs/slate/ideas/triaged.md)

Append-only. This file is the permanent triage record — `inbox.md` is not.

    ## YYYY-MM-DD — Triage session
    - <idea text> — **Area**: frontend|backend|db|ux|other — **Priority**: low|med|high — **Outcome**: promoted:FEAT-XXX | archived | kept-pending

## Outcomes

| Outcome | Effect on inbox.md | Effect on triaged.md |
|---|---|---|
| `promoted:FEAT-XXX` | line removed | logged with the resulting FEAT-XXX |
| `archived` | line removed | logged |
| `kept-pending` | line stays | logged (so the decision not to decide is still visible) |

## Example

    ## 2026-07-06 — Triage session
    - Add PDF export for reports — **Area**: backend — **Priority**: med — **Outcome**: promoted:FEAT-051
    - Dark mode toggle — **Area**: frontend — **Priority**: low — **Outcome**: kept-pending
    - Rewrite onboarding copy in Latin — **Area**: other — **Priority**: low — **Outcome**: archived
