# Changelog

## 1.5.0 — 2026-07-20

Cuts `managing-feature-list` from ~84k tokens/invocation to <5k by (a) replacing
full-file reads with a bounded `grep` for the next ID, and (b) adding an official
by-entry-count archiving flow for the append-only files. Same ID fix applies to
`tracking-bugs`. No change to the `FEAT-XXX` / `BUG-XXX` format; IDs stay
immutable.

### Changed (`skills/`)
- `managing-feature-list` — next `FEAT-NNN` now comes from a bounded `grep` over
  the live files (`backlog`/`in-progress`/`done`), never a whole-file read. New
  "Archiving done.md" section; anti-pattern carve-out for the sanctioned bulk
  move.
- `breaking-down-features` — step 2 uses the same bounded `grep`.
- `tracking-bugs` — next `BUG-NNN` via bounded `grep`; new archiving section for
  `fixed.md`.
- `tracking-progress` — new archiving section for `history.md`; reconciled the
  "don't summarize history" anti-pattern (archiving is a bulk move of intact
  blocks, not a summary).
- `using-slate` — lists `*-archive-*.md` as canonical-but-never-loaded; forbids
  whole-file reads for ID computation.

### Added (`docs/`)
- `docs/archiving.md` — the single reference for rotation: 40-entry threshold,
  `*-archive-YYYYHn.md` naming, oldest-first invariant (keeps ID search correct),
  and the bulk-move-≠-edit rule.
- `docs/feature-format.md`, `docs/bug-format.md` — the "next ID" bullet is now the
  bounded `grep`; movement tables gain the archive row.

### Note
- Consumers must run `claude plugin update` (or start a fresh Claude Code
  session) to pull 1.5.0 into the versioned plugin cache — same activation step
  as any skill change (see BUG-001).

## 1.4.0 — 2026-07-19

Redesigns the session guardian to close the four blind spots of BUG-002 that let
a parallel session clobber another's work in real use (a branch built on top of
another live session's commits reached production on merge). Ships FEAT-002.

### Changed (`hooks/`)
- `session-guardian.sh` — now decides by comparing THIS session's current
  branch/tip against the locks of OTHER LIVE sessions on every sensitive git op
  (`commit`/`push`/`merge`/`rebase`/`cherry-pick`/`stash`), instead of against a
  startup snapshot of its own claim. It blocks (`deny`) only on a confirmed clash
  with a live peer, and otherwise warns without blocking (`additionalContext` +
  `systemMessage`, leaving the normal permission flow intact). New detections:
  (1) a branch built on top of a live peer's un-mainlined tip (branch-on-top),
  (2) a live peer on the same branch, (3) shared-stash hazards (`git stash
  pop`/`apply` without an explicit `stash@{n}`, and `drop`/`clear`, are blocked
  while a peer is live). A session acting alone is never blocked — this removes
  the 1.3.0 false positive that blocked a deliberate branch change by the session
  itself.
- `session-lock.sh` — records the branch tip (`head` SHA) in the lock so peers
  can detect a branch-on-top.
- `session-heartbeat.sh` — besides refreshing liveness, mirrors this session's
  current branch + tip into its lock (using the payload `cwd`, correct even in an
  isolated worktree) so a peer sees fresh state right after a commit.

### Note
- Consumers must run `claude plugin update` (or start a fresh Claude Code
  session) to pull 1.4.0 into the versioned plugin cache — same activation step
  as any hook change (see BUG-001).

## 1.3.0 — 2026-07-19

Ships FEAT-001 (session lock) to consumers. The hook scripts and `hooks.json`
wiring for parallel-session protection landed in the repo but the plugin version
was never bumped, so Claude Code kept serving the cached 1.2.0 copy (which lacks
the new hooks) and the protection never loaded in real, marketplace-installed
sessions. This release exists to trigger the cache re-copy. See BUG-001.

### Added (`hooks/`)
- `session-lock.sh` — SessionStart: writes a per-session lock under
  `$(git rev-parse --git-common-dir)/slate-sessions/`; if another live session
  already claims the current branch, auto-isolates into a new `git worktree`.
- `session-heartbeat.sh` — PostToolUse: refreshes the lock's heartbeat so a live
  session isn't reaped by the 15-minute stale TTL.
- `session-guardian.sh` — PreToolUse(Bash): blocks `git commit`/`git push` when
  the current branch differs from the one this session claimed at start.
- `session-lock-cleanup.sh` — SessionEnd: releases this session's lock.
- `hooks.json` now wires `PostToolUse` and `PreToolUse(Bash)` in addition to the
  existing `SessionStart`, `SessionEnd`, `PreCompact` (these two event types were
  removed in 1.0.0 and are reintroduced here only for the session guardian).

### Note
- Consumers must run `claude plugin update` (or start a fresh Claude Code
  session) to pull 1.3.0 into the versioned plugin cache. Editing plugin source
  without bumping the version has no effect — Claude Code keeps the cached copy.

## 1.2.0 — 2026-07-06

Adds bug traceability and idea capture, following the same markdown-only,
append-only-history pattern as `features/`.

### Added
- `bugs/open.md` / `bugs/fixed.md` — bug tracking with `BUG-XXX` IDs,
  independent numbering from `FEAT-XXX`. See `docs/bug-format.md`.
- `ideas/inbox.md` / `ideas/triaged.md` — zero-friction idea capture plus
  explicit triage (group by area, promote/archive/keep-pending). See
  `docs/idea-format.md`.
- Skills: `tracking-bugs`, `managing-ideas`.
- Commands: `/idea "<text>"`, `/ideas-triage`.
- `hooks/session-start.sh` now injects open-bug count + IDs and
  pending-idea count, same lightweight index principle as the existing
  in-progress features index.

## 1.1.0 — 2026-06-22

SessionStart hook now injects lightweight state instead of full dumps. Measured
against a real project (novateks-improductivos): ~21478 bytes (~5369 tok) →
~789 bytes (~197 tok) on startup, ~326 bytes (~81 tok) on compact/resume.

### Changed (`hooks/session-start.sh`)
- Stops injecting `features/backlog.md` (read on demand via managing-feature-list).
- in-progress injected as an INDEX (one line per FEAT: id + title + status),
  not full blocks.
- Stops `cat`-ing SKILL.md; injects a one-line header pointing at the
  `using-slate` skill (protocol loads via the Skill tool on demand).
- Branches on the SessionStart `source` (read from stdin JSON):
  startup|clear → header + in-progress index + current.md + last 2 history lines;
  compact|resume → in-progress index + last history line only, no header.
- history capped to the last line(s) instead of `tail -30`.

## 1.0.0 — 2026-05-25

Lean rewrite. The harness now does exactly three things: persistent session state, controlled feature movement, and SessionStart context injection.

### Removed (vs 0.5.0)
- All `PostToolUse`, `PreToolUse`, and `Stop` hooks (formatter, safety, checkpoint, watchers, notify).
- Skills: `consulting-project-map`, `harness-create-branch`, `harness-doctor`, `harness-open-pr`, `verify-harness-hooks`, `verifying-features`, `handing-off-session`, `scaffolding-environment`.
- `scripts/harness/` (doctor, pr-open, pr-merge, rollback).
- `scripts/lib/parse-features.sh`, `scripts/lib/checkpoint.sh`, all `hooks/lib/`.
- Config layer (`templates/.slate/`).
- Project map and ADR templates.
- v0.2/v0.4/v0.5 install-time migrations.

### Kept and simplified
- 3 hooks: `SessionStart`, `SessionEnd`, `PreCompact`.
- 4 skills: `using-slate`, `managing-feature-list`, `breaking-down-features`, `tracking-progress`.
- 1 install script that copies templates and exits.
