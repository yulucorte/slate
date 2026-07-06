# Design: Bug Traceability + Idea Capture for Slate

## Problem

Slate tracks features (`features/backlog.md` → `in-progress.md` → `done.md`) but has no
equivalent for two things Felipe actually needs across his projects:

1. **Bugs and their fixes** are found ad hoc, fixed, and then forgotten — no record of
   what broke, why, or which commit fixed it. No way to answer "why did X break" later.
2. **Future ideas** that come up mid-session have nowhere lightweight to land. They either
   get forgotten or force a premature full feature write-up. There's also no later step to
   group/prioritize a pile of loose ideas by area (frontend/backend/DB/UX) or pick one to
   attack.

## Goals

- Add bug traceability with the same markdown-only, append-only-history philosophy as
  `features/`.
- Add zero-friction idea capture that doesn't interrupt flow, plus an explicit triage step
  for later grouping/prioritization/promotion to features.
- Keep the "3 hooks, N skills, justify every addition" discipline: 2 new skills, not 4.

## Non-goals

- No JSON/YAML/SQLite. Markdown only, consistent with existing Slate philosophy.
- No automatic idea categorization at capture time. Categorization happens only at triage.
- No forced promotion of ideas to features — triage can also archive or leave pending.

## 1. Bug tracking

### New files (per project, via install script)

- `bugs/open.md` — mutable, currently-open bugs.
- `bugs/fixed.md` — append-only. Editing existing entries is FORBIDDEN, same rule as
  `features/done.md`.

### Schema (`docs/bug-format.md`, plugin-side reference doc — mirrors `feature-format.md`)

    ## BUG-XXX: <Title>
    - **Status**: open | fixed
    - **Severity**: low | medium | high | critical
    - **Reported-by**: <name/@handle>
    - **Detected**: YYYY-MM-DD
    - **Where**: <file/module/screen>
    - **Root cause**: <free text; "unknown" until diagnosed>
    - **Fix**: <free text describing the fix>
    - **Commit**: <sha or branch>          (none until fixed)
    - **Related feature**: FEAT-XXX         (optional)
    - **Fixed**: YYYY-MM-DD                 (only when Status: fixed)

### ID rules

- `BUG-XXX`, zero-padded to 3 digits, independent numbering from `FEAT-XXX`.
- Immutable once assigned. Scan both `bugs/*.md` files for `^## BUG-NNN`, take `max+1`.

### Movement rules

| From | To | Required |
|---|---|---|
| `open.md` | `fixed.md` | `Fix`, `Commit`, and `Fixed:` date all set |
| Any | Edit `fixed.md` | **FORBIDDEN** — bugs don't reopen; file a new `BUG-XXX` if it recurs, optionally noting `Related feature`/free-text reference to the earlier bug in Notes |

### New skill: `tracking-bugs`

Mirrors `managing-feature-list`. Covers the whole lifecycle in one skill (report → diagnose
→ fix → close), same way `managing-feature-list` covers backlog→in-progress→done.

Triggers: user reports a bug ("esto no funciona", "encontré un bug"), a fix is about to be
committed, or user asks "qué bugs hay abiertos".

## 2. Idea capture

### New files (per project)

- `ideas/inbox.md` — mutable working queue. Lines can be removed once triaged
  (promoted or archived).
- `ideas/triaged.md` — append-only permanent record of triage decisions. This is the
  file that carries history; `inbox.md` is scratch space, not the record of truth.

### Inbox entry format (deliberately minimal — must not interrupt flow)

    - YYYY-MM-DD HH:MM — <raw idea text, verbatim>

No area/priority/status at capture time. Capture is a dumb append.

### Triaged entry format

    ## YYYY-MM-DD — Triage session
    - <idea text> — **Area**: frontend|backend|db|ux|other — **Priority**: low|med|high — **Outcome**: promoted:FEAT-XXX | archived | kept-pending

`kept-pending` entries are logged here but their line is NOT removed from `inbox.md` — they
stay in the working queue for the next triage pass.

### New skill: `managing-ideas`

One skill, two triggers (consistent with how `managing-feature-list` covers multiple
lifecycle stages):

- **Capture trigger**: user says things like "anota esta idea...", "se me ocurrió que...",
  or runs `/idea "<text>"`. Action: append one line to `ideas/inbox.md`. No judgment calls.
- **Triage trigger**: user runs `/ideas-triage`. Action: read `ideas/inbox.md`, group
  entries by area, propose a priority per group, ask the user which to promote (invokes
  `breaking-down-features` for promoted ones), which to archive, which to leave pending.
  Append the outcomes to `ideas/triaged.md`; remove promoted/archived lines from
  `inbox.md`; leave kept-pending lines untouched.

### New commands

- `commands/idea.md` — `/idea "<text>"` invokes the capture path explicitly.
- `commands/ideas-triage.md` — `/ideas-triage` invokes the triage path explicitly.

Natural language ("anota esta idea...") triggers the same skill without the command, per
Felipe's request for both paths to work.

## 3. SessionStart hook update

`hooks/session-start.sh` currently injects an INDEX (not full dumps) of in-progress
features plus recent history — chosen deliberately to keep injection lightweight (see
commit `4c57836`, ~5369→197 tokens). Bugs/ideas follow the same principle: counts and IDs
only, never full entry bodies.

Add, in both the `startup|clear` and `compact|resume` branches:

    ## Bugs abiertos: <count> (<BUG-IDs joined by comma>)
    ## Ideas pendientes: <count> (correr /ideas-triage)

Computed with the same `awk`-scan-for-headers approach already used for the features
index. Skip the block entirely if `bugs/` or `ideas/` doesn't exist (older projects that
installed Slate before this feature shipped).

## 4. Install script + templates

`scripts/install-into-project.sh` and `templates/` gain:

- `templates/bugs/open.md`, `templates/bugs/fixed.md` (empty skeletons, same header style
  as `templates/features/*.md`).
- `templates/ideas/inbox.md`, `templates/ideas/triaged.md` (empty skeletons).
- `mkdir -p bugs ideas` alongside the existing `mkdir -p progress/subagents features ...`.
- Idempotent copy-if-missing, same as existing entries.

`templates/AGENTS.md` gains two rows in the state-files table and two rules (bug closure
requires `Fix`+`Commit`+`Fixed:`; idea promotion goes through `breaking-down-features`).

`README.md` gains `bugs/` and `ideas/` rows in the "What it creates" table and a short
mention in the Flow section.

## Testing / verification

- `tests/test-install.sh` extended to assert `bugs/`, `ideas/`, and their template files
  exist after running the install script into a scratch directory.
- Manual verification: run install script into a throwaway dir, confirm idempotency
  (running twice doesn't overwrite), confirm `session-start.sh` doesn't error when
  `bugs/`/`ideas/` are absent (back-compat with projects installed before this change).

## Open questions

None — all decisions confirmed during brainstorming (2026-07-06).
