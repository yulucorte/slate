# Design: cheap ID assignment + append-only archiving for slate

**Date**: 2026-07-20
**Status**: approved (design), pending implementation plan
**Plugin version target**: 1.4.0 → 1.5.0

## Problem

`managing-feature-list` is the most token-expensive operation in a mature
slate project. Its ID-assignment instruction says literally: *"Read all three
files, find the highest `FEAT-NNN`, assign `FEAT-NNN+1`."* That forces a full
read of `features/backlog.md`, `features/in-progress.md` and `features/done.md`
every time a feature is created, moved, or completed.

In a mature project `done.md` accumulates 2,000+ lines (~70k tokens) because it
stores the full card of every completed FEAT. The skill reads it whole just to
obtain a single datum: the highest FEAT number. Measured cost: **~84,000 tokens
per invocation**, in a skill invoked several times per session.

### Root cause

`done.md` carries two responsibilities in one file: (a) the complete
append-only historical record, and (b) the source for computing the next ID.
The plugin rule also forbids rewriting or splitting `done.md` by hand
(*"DO NOT delete or rewrite a feature in done.md"*), so the user cannot mitigate
it without violating the skill contract. The same pattern affects
`tracking-progress` with `progress/history.md`, and `tracking-bugs` with
`bugs/fixed.md` — all append-only, all grow without bound, all read whole.

Note: the plugin's own `session-start.sh` hook already applies an
"index, not dump" philosophy (it `grep`/`awk`s the live files for a lightweight
index). The skills simply never adopted it for ID assignment.

## Decisions (confirmed with user)

1. **ID mechanism**: bounded pattern search (`grep`), no new file, no sync
   invariant to maintain.
2. **Archiving trigger**: by entry count (threshold ~40), moving the oldest
   entries in bulk.

## Design

### Part A — ID assignment by bounded search

Replace every "read all files, find highest N" instruction with a command that
returns **only the maximum number**, not file content:

    grep -hoE 'FEAT-[0-9]+' features/backlog.md features/in-progress.md features/done.md 2>/dev/null \
      | grep -oE '[0-9]+' | sort -n | tail -1

- Output: one number (tens of tokens) instead of ~84k.
- Next ID = that number + 1, zero-padded to 3 digits (`FEAT-043`).
- If output is empty (no features yet), next ID = `FEAT-001`.
- Matching `FEAT-007` inside a subtask (`FEAT-007.3`) or a cross-reference
  (`Supersedes: FEAT-007`) is harmless: those numbers are always ≤ the real max.
- Same command for bugs with `BUG-` over `bugs/open.md bugs/fixed.md`.

**Correctness invariant (documented):** the ID scan reads only the *live* files
(backlog/in-progress/done, or open/fixed for bugs). It never needs the archive
files because archiving moves only the **oldest** (lowest-numbered) entries, and
IDs are monotonically increasing — so the highest number always stays in a live
file.

Files touched by Part A:
- `skills/managing-feature-list/SKILL.md` — rewrite the "ID assignment" section.
- `skills/breaking-down-features/SKILL.md` — step 2 becomes the grep command.
- `skills/tracking-bugs/SKILL.md` — the ID-assignment step becomes the grep.
- `docs/feature-format.md` — the "To find the next available ID" bullet.
- `docs/bug-format.md` — the "To find the next available ID" bullet.

### Part B — official archiving of append-only files

Define a blessed rotation flow for append-only files. When a file exceeds
**40 entries**, move the oldest entries in bulk (leaving the ~20 most recent) to
a period archive:

| Live file | Archive file |
|---|---|
| `features/done.md` | `features/done-archive-YYYYHn.md` |
| `bugs/fixed.md` | `bugs/fixed-archive-YYYYHn.md` |
| `progress/history.md` | `progress/history-archive-YYYYHn.md` |

- `YYYYHn`: `H1` = Jan–Jun, `H2` = Jul–Dec, based on the archiving date. Entries
  moved in a given run append to the current half-year archive (created lazily
  on first use — no template needed).
- **A bulk move of intact entries is NOT editing a card.** The existing
  anti-pattern *"DO NOT delete or rewrite a feature in done.md"* stays in force;
  each affected skill gets an explicit carve-out: "moving whole entries to the
  period archive is the one sanctioned exception."
- No skill loads archive files in normal operation. The ID scan (Part A) does
  not include them; `using-slate` documents them as "never loaded"; the
  `session-start.sh` hook already only tails `history.md` (not archives) and
  indexes `in-progress.md`, so it is unaffected.
- **Trigger point**: the archive check runs inside `managing-feature-list` when
  it is about to append a completed feature to `done.md` (and analogously in
  `tracking-bugs` for `fixed.md`, `tracking-progress` for `history.md`). If the
  live file is over threshold, perform the bulk move as part of that operation.

Files touched by Part B:
- `skills/managing-feature-list/SKILL.md` — add archiving section + anti-pattern
  carve-out.
- `skills/tracking-bugs/SKILL.md` — add archiving for `fixed.md`.
- `skills/tracking-progress/SKILL.md` — add archiving for `history.md`;
  reconcile the existing *"DO NOT summarize old history.md entries"* anti-pattern
  (archiving moves entries intact, it does not summarize — clarify the two are
  different).
- `skills/using-slate/SKILL.md` — list archive files as canonical-but-never-loaded.
- `docs/archiving.md` — **new** — the single reference: threshold, naming,
  oldest-first invariant, why it preserves ID correctness, and the
  bulk-move-≠-edit rule.

### Part C — deploy

- `.claude-plugin/plugin.json`: bump `version` 1.4.0 → 1.5.0. Without the bump,
  changes to skills do not reach real use (Claude Code caches skills per plugin
  version).
- `templates/AGENTS.md`: add a one-line note that `*-archive-*.md` files exist,
  are append-only history, and are never loaded in normal operation.

## Acceptance criteria

- Creating/moving/completing a feature in a project with a 2,000+ line
  `done.md` costs **< 5,000 tokens** (target: hundreds), down from ~84k.
- No historical information is lost (entries move intact, never deleted or
  summarized).
- The `FEAT-XXX` / `BUG-XXX` format is unchanged; IDs remain immutable and
  correct after archiving.
- `using-slate`, `breaking-down-features`, `tracking-bugs` keep working with
  rotated files.

## Out of scope

- No JSON/YAML/SQLite alternatives (Markdown stays the contract).
- No automated cron/hook that rotates files behind the user's back — rotation
  happens inline within the skill operation that would grow the file.
- No renumbering or reformatting of existing entries.
