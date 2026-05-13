# State of claude-harness

> Snapshot taken on 2026-05-13 against branch `main` at commit `8a79b1a`.
> Purpose: let any future Claude instance understand this plugin in 5 minutes.
> Reading order: this file → `docs/feature-format.md` → `hooks/hooks.json` → `skills/*/SKILL.md`.

---

## 1. TL;DR

- claude-harness is a Claude Code plugin (v0.3.0, MIT) that adds Markdown-only state/progress/feature tracking on top of Superpowers.
- It ships **10 skills**, **9 hooks** (across 6 events), **7 hook-lib helpers**, **4 harness scripts** (doctor/pr-open/pr-merge/rollback) and **2 generic scripts** (install/self-test).
- All 20 test suites pass via `bash scripts/self-test.sh`.
- No Superpowers hard dependency: skills reference Superpowers by name as guidance only — nothing in code requires Superpowers to be loaded.
- Tags `v0.1.0` (`8a0b191`), `v0.2.0` (`8407de5`), `v0.3.0` (`2af20ad`) exist locally as of this snapshot; `main` is 50 commits ahead of `origin/main` and pending push.
- A non-fast-forward merge (commit `483e660`) integrated PR #1 (`feat/branch-wip-limit`, 10 commits, dated 2026-05-04) into this line. PR #1 added the Branch field model (decided at in-progress transition, default `none` in backlog), the WIP-limit rule (≤1 feature in in-progress), the branch auto-suggest protocol, and a branch-mismatch check in `session-start.sh`. The merge preserved the three tag SHAs.

---

## 2. Architecture (ASCII)

```
                ┌────────────────────────────────────────────────┐
                │  Claude Code session in a user project          │
                └────────────────────────────────────────────────┘
                                       │
                                       │ loads at startup
                                       ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                  PLUGIN (claude-harness)                                  │
│                                                                           │
│  .claude-plugin/plugin.json   ──── declares plugin v0.3.0                 │
│  hooks/hooks.json             ──── 6 events → 9 scripts                   │
│                                                                           │
│  hooks/                            skills/                                │
│   ├ session-start.sh                ├ using-claude-harness  (meta)        │
│   ├ session-end.sh                  ├ tracking-progress                   │
│   ├ pre-compact.sh                  ├ managing-feature-list               │
│   ├ pre-tool-safety.sh              ├ scaffolding-environment             │
│   ├ post-edit-checkpoint.sh         ├ handing-off-session                 │
│   ├ post-edit-format.sh             ├ breaking-down-features              │
│   ├ post-edit-in-progress-watcher   ├ harness-doctor          (v0.3.0)    │
│   ├ post-edit-done-watcher          ├ harness-open-pr         (v0.3.0)    │
│   ├ stop-notify.sh                  ├ harness-create-branch   (v0.3.0)    │
│   └ lib/  (7 helpers: defaults,     └ verify-harness-hooks    (v0.2.0)    │
│            load-config, log,                                              │
│            emit-status, acquire-lock,                                     │
│            hash-path, read-feature)                                       │
│                                                                           │
│  scripts/                                                                 │
│   ├ install-into-project.sh   ──── seeds templates/ into user project     │
│   ├ self-test.sh              ──── runs tests/test-*.sh                   │
│   ├ harness/                                                              │
│   │   ├ doctor.sh                                                         │
│   │   ├ pr-open.sh                                                        │
│   │   ├ pr-merge.sh                                                       │
│   │   └ rollback-feature.sh                                               │
│   └ lib/  (parse-features.sh, checkpoint.sh)                              │
│                                                                           │
│  templates/                       (copied into user project, idempotent) │
│   ├ init.sh                                                               │
│   ├ AGENTS.md                                                             │
│   ├ .claude-harness/config.sh                                             │
│   ├ progress/{current.md, history.md, .gitignore}                         │
│   └ features/{README.md, backlog.md, in-progress.md, done.md}             │
│                                                                           │
│  docs/                                                                    │
│   ├ STATE-OF-HARNESS.md       (this file)                                 │
│   ├ feature-format.md         (schema; documents Branch: field)           │
│   ├ contributing.md           (self-test, diagram regeneration)           │
│   ├ installation.md, workflow.md, interop-with-superpowers.md             │
│   ├ assets/  (claude-harness-overview.excalidraw + .json source)          │
│   └ superpowers/{specs,plans,plans/archive}/                              │
└──────────────────────────────────────────────────────────────────────────┘
                                       │
                                       │ install-into-project.sh
                                       ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                   USER PROJECT (target)                                   │
│                                                                           │
│  init.sh, AGENTS.md, .claude-harness/config.sh                            │
│                                                                           │
│  progress/                          features/                             │
│   ├ current.md     (live)            ├ backlog.md      (live)             │
│   ├ history.md     (append-only)     ├ in-progress.md  (live)             │
│   ├ hooks.log      (rotating)        ├ done.md         (immutable rows)   │
│   ├ subagents/*.md                   └ README.md                          │
│   ├ transcripts/*.snap                                                    │
│   ├ .in-progress.snapshot  (hook state, gitignored)                       │
│   └ .done.snapshot         (hook state, gitignored)                       │
└──────────────────────────────────────────────────────────────────────────┘
```

A higher-fidelity rendering of the same picture lives in [docs/assets/claude-harness-overview.excalidraw](assets/claude-harness-overview.excalidraw) (open with <https://excalidraw.com>). See [docs/contributing.md](contributing.md#regenerating-the-architecture-diagram) for how to regenerate it.

---

## 3. Skills (10)

| Skill | Trigger (per SKILL.md `description`) | Reads | Writes | Invokes |
|---|---|---|---|---|
| [using-claude-harness](../skills/using-claude-harness/SKILL.md) | Session start in a project with `progress/` or `features/` | hook-injected context | — | tracking-progress, managing-feature-list, handing-off-session |
| [tracking-progress](../skills/tracking-progress/SKILL.md) | Before/after subagent dispatch; TodoWrite completion; "where are we" | `progress/current.md` | `progress/current.md`, `progress/subagents/*.md`, `progress/history.md` | — |
| [managing-feature-list](../skills/managing-feature-list/SKILL.md) | Defining scope, marking complete, moving features, "what's left" | all `features/*.md` | `features/{backlog,in-progress,done}.md` | — (enforces WIP ≤ 1 and branch-cleanup gate; skips the merge prompt when `HARNESS_AUTO_PR=true`) |
| [scaffolding-environment](../skills/scaffolding-environment/SKILL.md) | Project lacks `progress/`/`features/`; user says "set up harness" | filesystem | — (delegates to install script) | runs `scripts/install-into-project.sh` |
| [handing-off-session](../skills/handing-off-session/SKILL.md) | End of session; before `/clear` or `/compact`; "we're done for today" | `progress/current.md`, `features/in-progress.md` | `progress/current.md`, `progress/history.md`; `git commit` | — |
| [breaking-down-features](../skills/breaking-down-features/SKILL.md) | After Superpowers plan approved; new scope described | `docs/superpowers/plans/`, all `features/*.md` | `features/backlog.md` (default) or `in-progress.md` | runs the branch auto-suggest protocol (slug derivation + user confirmation) before writing `Branch:` |
| [harness-doctor](../skills/harness-doctor/SKILL.md) | "diagnose harness", "what's wrong with harness", after install | runs `scripts/harness/doctor.sh` | — | reports back to user, may suggest `harness-doctor` re-run |
| [harness-open-pr](../skills/harness-open-pr/SKILL.md) | "open PR for FEAT-X" when `HARNESS_AUTO_PR=false` | `features/done.md` | runs `scripts/harness/pr-open.sh` | may invoke harness-doctor on failure |
| [harness-create-branch](../skills/harness-create-branch/SKILL.md) | "create branch for FEAT-X" when `HARNESS_AUTO_BRANCH=false` | `features/in-progress.md` via `hooks/lib/read-feature.sh` | runs `git switch -c $BRANCH` | — |
| [verify-harness-hooks](../skills/verify-harness-hooks/SKILL.md) | After install, after upgrade, before enabling AUTO_*; hook misbehaving | `hooks/hooks.json`, scripts, `.claude-harness/config.sh`, `progress/hooks.log` | — (read-only) | recommends harness-doctor for fixes |

Notes:
- All 10 skills are now listed in the README "What it adds" table ([README.md:32-43](../README.md#L32-L43)).
- `using-claude-harness` is the meta-skill injected by `session-start.sh`; it is not user-invocable directly.

---

## 4. Hooks (9 across 6 events)

Source of truth: [hooks/hooks.json](../hooks/hooks.json).

| Event | Matcher | Script | What it does | Reads | Writes | Exit semantics |
|---|---|---|---|---|---|---|
| SessionStart | `startup\|resume\|clear\|compact` | [session-start.sh](../hooks/session-start.sh) | If project initialized, runs `init.sh`, then emits a JSON `additionalContext` blob with the using-claude-harness skill, last 30 lines of history, current.md, first 10 active features. Also injects a `## Branch warning` section when the current git branch differs from the active feature's `Branch:` value | `progress/`, `features/`, `init.sh`, plugin SKILL.md, current git branch | appends to `progress/history.md` | always 0 |
| SessionEnd | — | [session-end.sh](../hooks/session-end.sh) | Appends non-empty `current.md` to `history.md`, resets `current.md`, auto-commits `progress/` + `features/` | `progress/current.md` | `progress/current.md` (reset), `progress/history.md`, `git commit --allow-empty` | always 0 |
| PreCompact | `auto\|manual` | [pre-compact.sh](../hooks/pre-compact.sh) | Snapshots `$CLAUDE_TRANSCRIPT_PATH` into `progress/transcripts/<epoch>.snap`, logs compaction event | `$CLAUDE_TRANSCRIPT_PATH` | `progress/transcripts/*.snap`, `progress/history.md` | always 0 |
| PreToolUse | — (all tools) | [pre-tool-safety.sh](../hooks/pre-tool-safety.sh) | Blocks `rm -rf $HOME`, `git push --force` to main/master, `git reset --hard`, edits to `.claude-harness/config.sh` (4 rules: RM_HOME, FORCE_PUSH_MAIN, RESET_HARD, CONFIG_EDIT). Each rule overrideable via `HARNESS_ALLOW_*=true` or mode `HARNESS_SAFETY_RULES=permissive` | stdin JSON (tool_name, command, file_path), `.claude-harness/config.sh` | `progress/hooks.log` + stderr via `emit-status.sh` | **2 on block** (stderr fed back to Claude), 0 on pass |
| PostToolUse | `Edit\|Write\|MultiEdit` | [post-edit-checkpoint.sh](../hooks/post-edit-checkpoint.sh) | If edited path matches `*progress/*` or `*features/*`, `git add` + `git commit -m "chore(harness): autosave <path>"` | edited file path (arg 1) | `git commit` | always 0 |
| PostToolUse | `Edit\|Write\|MultiEdit` | [post-edit-format.sh](../hooks/post-edit-format.sh) | Reads `file_path` from stdin JSON, skips `features/`/`progress/`/`.claude-harness/`, runs `HARNESS_FORMATTER` (prettier/gofmt/ruff/none) on supported extensions | stdin JSON, config | runs formatter; logs SKIP/SUCCESS/ERROR | always 0 |
| PostToolUse | `Edit\|Write\|MultiEdit` | [post-edit-in-progress-watcher.sh](../hooks/post-edit-in-progress-watcher.sh) | Only fires for `features/in-progress.md`. Diffs against `progress/.in-progress.snapshot`; for each new `FEAT-NNN` either runs `git switch -c $branch` (`HARNESS_AUTO_BRANCH=true`) or emits a `suggest` line. Uses a `/tmp` flock keyed by project hash | `features/in-progress.md`, `.in-progress.snapshot`, config | `.in-progress.snapshot` (atomic move), git state, `progress/hooks.log`, stderr | always 0 |
| PostToolUse | `Edit\|Write\|MultiEdit` | [post-edit-done-watcher.sh](../hooks/post-edit-done-watcher.sh) | Only fires for `features/done.md`. Same snapshot/diff pattern; for each new FEAT either runs `scripts/harness/pr-open.sh` (`HARNESS_AUTO_PR=true`) or emits a `suggest` line. Skips when current git branch ≠ feature `Branch:` | `features/done.md`, `.done.snapshot`, config | `.done.snapshot`, `progress/hooks.log`, stderr, optionally a PR | always 0 |
| Stop | — | [stop-notify.sh](../hooks/stop-notify.sh) | OS notification (osascript on macOS, notify-send on Linux). 30s debounce per-project (via `/tmp/claude-harness-last-notify-<hash>`). Counts queued events between fires | `/tmp` state files | OS notification, `progress/hooks.log` | always 0 |

Notes:
- The 4 PostToolUse scripts run in registration order on every Edit/Write/MultiEdit. Watchers gate themselves on the edited path.
- All 9 hooks are now listed in the README "What it adds" table ([README.md:46-58](../README.md#L46-L58)).
- All hooks are `set -u` only (not `set -e`) — failures inside helpers do not abort the hook. Exit 2 happens **only** in `pre-tool-safety.sh` and is intentional (Claude Code blocks the tool call).

### Hook lib helpers ([hooks/lib/](../hooks/lib/))

| File | Purpose |
|---|---|
| `defaults.sh` | Sets baked-in defaults (`HARNESS_FORMATTER=none`, `HARNESS_NOTIFY=true`, `HARNESS_AUTO_BRANCH=false`, `HARNESS_AUTO_PR=false`, `HARNESS_SAFETY_RULES=strict`, `HARNESS_GITHUB_BASE=main`, 4 per-rule allows, log rotation) |
| `load-config.sh` | Sources `defaults.sh`, then `.claude-harness/config.sh`, then `.claude-harness/config.local.sh`. Logs ERROR + warns to stderr if `config.sh` has a `bash -n` syntax error and falls back to defaults |
| `log-hook-event.sh` | `log-hook-event.sh <hook-name> <event-type> [k=v]...` → appends to `progress/hooks.log`. Rotates at `HARNESS_LOG_MAX_BYTES`, keeps `HARNESS_LOG_ROTATIONS`, oldest is gzipped |
| `emit-status.sh` (v0.3.0) | `emit-status.sh <ok\|block\|suggest\|warn\|*> <hook> <msg> [k=v]...` → prints `✓/✗/→/!/• harness: <msg>` to stderr **and** logs via `log-hook-event.sh` with `STATUS_*` level |
| `acquire-lock.sh` | `flock -w <timeout> <fd>` wrapper for project-scoped locks |
| `hash-path.sh` | 8-char hash of an input string. Tries `shasum` → `sha1sum` → `cksum` (portability fallback). Used to namespace `/tmp` files per-project |
| `read-feature.sh` | `read-feature.sh <md-file> <FEAT-NNN>` → emits `key=value` lines (title, branch, plan, verification, verified, notes). Exit 1 if not found, 2 if Branch field missing |

---

## 5. Contract: files in user project

| Path | Role | Plugin's relation | Notes |
|---|---|---|---|
| `init.sh` | Project bootstrap script | Installed once; user-editable | Idempotent. Auto-detects npm/python/cargo/go and runs a 60s smoke test |
| `AGENTS.md` | Protocol declaration | Installed once | If existing, scaffolding-environment instructs Claude to append rather than overwrite |
| `.claude-harness/config.sh` | Project hook config | Installed once; protected by `pre-tool-safety.sh::CONFIG_EDIT` rule | Edits trigger a block unless `HARNESS_ALLOW_CONFIG_EDIT=true` |
| `.claude-harness/config.local.sh` | Per-user override | Never installed; user creates; gitignored | Sourced after `config.sh` |
| `progress/current.md` | Live state (in-flight work) | **Actively edited** by tracking-progress | Reset by `session-end.sh` |
| `progress/history.md` | **Append-only** changelog | Appended by tracking-progress, session-end, pre-compact, pr-open, pr-merge, rollback-feature | Anti-pattern: editing past entries |
| `progress/subagents/*.md` | Full subagent reports | Written by tracking-progress | Filename convention: `<task-slug>-<STATUS>.md` |
| `progress/transcripts/*.snap` | Pre-compact transcripts | Written by pre-compact.sh when `$CLAUDE_TRANSCRIPT_PATH` is set | — |
| `progress/hooks.log` | Structured hook event log | Written by every hook via `log-hook-event.sh` | Rotates at 5 MB (3 rotations, oldest gzipped). Gitignored by install |
| `progress/.in-progress.snapshot` | Watcher state | Written by post-edit-in-progress-watcher | Gitignored; pre-populated at install so existing features don't fire as "new" |
| `progress/.done.snapshot` | Watcher state | Written by post-edit-done-watcher | Same as above |
| `features/README.md` | Reference | Read-only | — |
| `features/backlog.md` | Desired features | **Actively edited** by managing-feature-list, breaking-down-features | — |
| `features/in-progress.md` | Active features | **Actively edited** | Movement here triggers post-edit-in-progress-watcher |
| `features/done.md` | Completed features | **FORBIDDEN to edit existing entries** (override: `Supersedes:` successor). Append-only via managing-feature-list | Movement here triggers post-edit-done-watcher |
| `.gitignore` | Project gitignore | Appended idempotently with 5 entries (`hooks.log`, `hooks.log.*`, two snapshots, `config.local.sh`) | — |

The `Branch:` field of a feature is documented in [docs/feature-format.md](feature-format.md#the-branch-field): mandatory when AUTO_* is enabled (or when the manual `harness-*` skills are used), `none` is the explicit opt-out, otherwise optional.

---

## 6. Scripts and their behavior

| Script | Args | Idempotency | Side effects |
|---|---|---|---|
| [scripts/install-into-project.sh](../scripts/install-into-project.sh) | `[target]` (default `$(pwd)`) | Uses `safe_copy` (skip if exists). `chmod +x` is `\|\| true`. Snapshot pre-population skipped if snapshot exists | Creates progress/, features/, .claude-harness/, appends to .gitignore, sets executable bits on plugin hook scripts, auto-detects formatter from `package.json`/`go.mod`/`pyproject.toml` and writes `HARNESS_FORMATTER=...` to config.sh |
| [scripts/self-test.sh](../scripts/self-test.sh) | none | Read-only against plugin | Runs every `tests/test-*.sh`; exits 1 if any FAIL |
| [scripts/lib/parse-features.sh](../scripts/lib/parse-features.sh) | (source only) | n/a | Exposes `list_feature_ids`, `next_feature_id`, `feature_status`, `count_subtasks`. POSIX-ish awk/grep/sed |
| [scripts/lib/checkpoint.sh](../scripts/lib/checkpoint.sh) | `[dir] [msg]` | `git diff --cached --quiet` short-circuits when nothing staged | `git add progress/ features/`, `git commit --no-verify` (only if staged diff exists) |
| [scripts/harness/doctor.sh](../scripts/harness/doctor.sh) | none | Read-only | Prints ✓/!/✗ for config, state dirs, flock/gh/formatter, hooks.json, log. Exits 1 if any ✗ |
| [scripts/harness/pr-open.sh](../scripts/harness/pr-open.sh) | `<FEAT-NNN>` | Checks `gh pr list --head $branch` first, exits 0 if PR exists | Calls `gh pr create --base $HARNESS_GITHUB_BASE --head <branch>`. Refuses if `gh` missing/unauthed, fork (no WRITE perm), or feature lacks Branch. Appends URL to `progress/history.md` |
| [scripts/harness/pr-merge.sh](../scripts/harness/pr-merge.sh) | `<FEAT-NNN>` | n/a | `gh pr merge --squash --delete-branch` once preconditions pass (PR OPEN, reviewDecision ∈ {null, APPROVED}). Inserts `- **Merged**: <sha>` line into `done.md`, appends to history |
| [scripts/harness/rollback-feature.sh](../scripts/harness/rollback-feature.sh) | `<FEAT-NNN>` | n/a | Moves the FEAT block from `done.md` back into `in-progress.md`. If `gh` + `python3` + PR exist, appends reviewer comments to the feature's `### Notes` section. Logs WARNING if python3 missing |

### System dependencies

| Tool | Required by | Required? |
|---|---|---|
| `bash` ≥ 4 | `pre-tool-safety.sh` uses `${!var}` indirect expansion | Hard |
| `git` | every commit hook + watchers + PR scripts | Hard |
| `awk`, `grep`, `sed`, `comm`, `sort`, `cut`, `tr`, `wc`, `date`, `mkdir`, `cp`, `cat` | most hooks | Hard |
| `flock` | `post-edit-in-progress-watcher.sh`, `post-edit-done-watcher.sh` | Hard for watchers (doctor checks) |
| `shasum` OR `sha1sum` OR `cksum` | `hash-path.sh` (any one works) | Hard |
| `python3` | `session-start.sh` (JSON encoding, has sed fallback); `rollback-feature.sh` (PR comments, logs WARNING if missing) | Soft |
| `gh` | PR scripts (`pr-open`, `pr-merge`, `rollback-feature`) | Soft (`HARNESS_AUTO_PR=true` makes it hard) |
| `prettier` / `gofmt` / `ruff` | `post-edit-format.sh` | Soft, gated by `HARNESS_FORMATTER` |
| `osascript` (Darwin) / `notify-send` (Linux) | `stop-notify.sh` | Soft |
| `gzip` | `log-hook-event.sh` rotation | Soft (rotation falls back silently) |

---

## 7. Test status

`bash scripts/self-test.sh` at HEAD: **20 pass, 0 fail.**

| Suite | Status | Coverage |
|---|---|---|
| [test-checkpoint.sh](../tests/test-checkpoint.sh) | PASS | `scripts/lib/checkpoint.sh`: commit on diff, no-op on clean tree |
| [test-doctor.sh](../tests/test-doctor.sh) | PASS | doctor exit code and Fix lines |
| [test-emit-status.sh](../tests/test-emit-status.sh) | PASS | glyph mapping, stderr + log lines |
| [test-hook-done-watcher.sh](../tests/test-hook-done-watcher.sh) | PASS | new-feature detection, branch-mismatch skip, AUTO_PR branching |
| [test-hook-format.sh](../tests/test-hook-format.sh) | PASS | skip rules, formatter dispatch |
| [test-hook-in-progress-watcher.sh](../tests/test-hook-in-progress-watcher.sh) | PASS | snapshot diff, AUTO_BRANCH branching, suggest path |
| [test-hook-notify.sh](../tests/test-hook-notify.sh) | PASS | 30s debounce |
| [test-hook-safety.sh](../tests/test-hook-safety.sh) | PASS | 4 rules + permissive mode + per-rule allow |
| [test-install.sh](../tests/test-install.sh) | PASS | v0.1.0 install + idempotency |
| [test-install-v02.sh](../tests/test-install-v02.sh) | PASS | v0.2.0 config seeding, gitignore, snapshots |
| [test-lib-acquire-lock.sh](../tests/test-lib-acquire-lock.sh) | PASS | flock + timeout |
| [test-lib-defaults.sh](../tests/test-lib-defaults.sh) | PASS | 12 default values |
| [test-lib-hash-path.sh](../tests/test-lib-hash-path.sh) | PASS | determinism, uniqueness, length |
| [test-lib-load-config.sh](../tests/test-lib-load-config.sh) | PASS | defaults fallback, override, syntax-error fallback, config.local override |
| [test-lib-log-hook-event.sh](../tests/test-lib-log-hook-event.sh) | PASS | format, append, rotation, retention, gzip oldest |
| [test-lib-read-feature.sh](../tests/test-lib-read-feature.sh) | PASS | title/branch/plan extraction, missing FEAT, branch=none, notes, missing Branch |
| [test-parse-features.sh](../tests/test-parse-features.sh) | PASS | list/next id, status, count_subtasks |
| [test-script-pr-merge.sh](../tests/test-script-pr-merge.sh) | PASS | CHANGES_REQUESTED block, success path, null reviewDecision |
| [test-script-pr-open.sh](../tests/test-script-pr-open.sh) | PASS | create, idempotency, gh-missing graceful |
| [test-script-rollback.sh](../tests/test-script-rollback.sh) | PASS | move + comments, no-duplicate-Notes, preserve content |

Note: a few suites print `FAIL at line <N>` mid-stream — that comes from each test's `trap 'echo FAIL line $LINENO' ERR` firing on expected non-zero returns inside the test (e.g. `grep` no-match, intentional failure injection). Every suite still exits 0 and aggregate is 20/0.

---

## 8. Git state

- Branch: `main`
- Ahead of `origin/main`: **50 commits** (40 from the v0.3.0 work + 7 from the FEAT-009 cleanup + the merge commit + 2 post-merge fix commits)
- Latest commit: `8a79b1a docs(skill): clarify managing-feature-list cleanup gate under HARNESS_AUTO_PR=true`
- Backup branch: `backup/pre-merge-FEAT-009` → `711c0c8` (kept locally by user instruction; do not delete until the user signs off on the merged state)
- Tags (local, not yet pushed — SHAs preserved across the merge):
  - `v0.1.0` → `8a0b191` (`chore: fill author metadata`, 2026-05-03 — last commit in v0.1.0-shipped state)
  - `v0.2.0` → `8407de5` (`chore: bump to v0.2.0 + CHANGELOG`, 2026-05-11)
  - `v0.3.0` → `2af20ad` (`chore(release): bump version to 0.3.0, update docs`, 2026-05-11)
- Untracked files: only this snapshot (intentional; the file is the output of the snapshot, not state).
- Top of history after the integration:
  ```
  8a79b1a docs(skill): clarify managing-feature-list cleanup gate under HARNESS_AUTO_PR=true
  e3a7165 fix(schema): deduplicate Branch fields after auto-merge with PR #1
  483e660 Merge origin/main (PR #1 branch-wip-limit) into FEAT-009 cleanup line. [...]
  711c0c8 docs(state): regenerate STATE-OF-HARNESS snapshot post-FEAT-009 cleanup
  fda2ae7 docs(plans): archive 2026-05-11-nontechnical-gap.md (delivered in v0.3.0)
  9047415 docs(assets): commit architecture diagram sources to docs/assets/
  3016fe4 chore(versions): drop package.json, move excalidraw-cli to docs/contributing.md
  ```
- Note on the merge: `git merge --no-ff` resolved automatically via the `ort` strategy without flagging a conflict in `docs/feature-format.md`, because the two competing `Branch:` insertions sat at different line positions and git treated them as independent hunks. The result was semantically duplicated (two `Branch:` lines per schema/example). Commit `e3a7165` cleans that up by hand per the resolution rules agreed before the merge (PR #1 model wins on schema position, slug format, and the "backlog always `none`" rule; the FEAT-009 "## The Branch: field" section is kept and absorbs the two lines PR #1 had placed under "## ID rules"). Commit `8a79b1a` then patches the only operational tension introduced by the merge: the PR #1 "Branch cleanup on done" gate (which prompts the user to merge BEFORE moving to done.md) does not apply when `HARNESS_AUTO_PR=true`, where the flow is reversed.

---

## 9. Integration with Superpowers

No hard dependency in code. Specifically:

- `plugin.json` declares no `dependencies` field.
- No `hooks/*.sh` or `scripts/*.sh` invokes a Superpowers skill or script.
- The plugin runs to completion in a project where Superpowers is not installed.

Soft references (guidance only) appear in:

- [skills/using-claude-harness/SKILL.md:27-31](../skills/using-claude-harness/SKILL.md#L27-L31) — describes the flow `brainstorming → writing-plans → breaking-down-features`.
- [skills/tracking-progress/SKILL.md:10](../skills/tracking-progress/SKILL.md#L10) — "Before any `Task` tool call that dispatches a subagent".
- [skills/breaking-down-features/SKILL.md:10,19](../skills/breaking-down-features/SKILL.md#L10) — "Right after `superpowers:writing-plans` produces a plan"; "the plan's tasks (`### Task N`) become subtasks".
- [skills/scaffolding-environment/SKILL.md:16](../skills/scaffolding-environment/SKILL.md#L16) — `$(claude-harness-plugin-root)` (helper not defined anywhere in this repo; assumed Superpowers-provided convention).
- [templates/AGENTS.md](../templates/AGENTS.md) — declares "This project uses **Superpowers** + **claude-harness**" and references `superpowers:subagent-driven-development`, `superpowers:writing-plans`.
- [docs/interop-with-superpowers.md](docs/interop-with-superpowers.md) and [docs/workflow.md](docs/workflow.md) — describe the combined flow.

Conclusion: claude-harness will install and run alongside Superpowers but does not require it. Skill prose names Superpowers skills as the intended upstream producer of plans/specs; if Superpowers is absent the prose is misleading but no hook breaks.

---

## 10. Gaps, TODOs, inconsistencies

> Diff vs. the previous snapshot (pre-FEAT-009 cleanup, commit `2af20ad`): items §10.1 (README hooks count), §10.2 (README skills count), §10.3 (package.json drift), §10.4 (Branch: field undocumented), §10.5 (untagged releases — now local-only, pending push), §10.6 (plugin's own hooks.log gitignore) **are resolved**. The 10 commits from PR #1 are now integrated; the Branch model documented here is the PR #1 model (decided at in-progress transition, default `none` in backlog) with FEAT-009's v0.3.0-specific semantics layered on top. What remains:

### Outstanding

1. **Tags + commits not yet pushed.** `main` is 50 commits ahead of `origin/main` and the three release tags are local-only. See `## End — push checklist` for the exact commands.
2. **`v0.1.0 (unreleased)` line in CHANGELOG**: cosmetic. The tag now exists locally; the CHANGELOG header is left in place for historical accuracy (it really was never released to anyone as v0.1.0 — the tag is retroactive). Decide later whether to rewrite the header to `## 0.1.0 — 2026-05-03` when the tags are pushed (likely bundled into the v0.4.0 CHANGELOG edit per the user's earlier note).
3. **`backup/pre-merge-FEAT-009` branch**: a safety pointer at `711c0c8` (the state right before the merge with PR #1). Kept locally by user instruction; remove it once the merged state has been pushed and verified.

### Notable behaviors worth knowing

- `BRIEF-claude-harness.md` is the original v0.1.0 spec. The implementation has evolved beyond it (10 vs 6 skills, 9 vs 4 hooks, added safety/format/PR-automation layers). Treat the BRIEF as historical context, not as a current contract.
- `scripts/harness/doctor.sh` run from inside this plugin repo reports `features/ directory missing` because the plugin is not a user-initialized project. Expected. Doctor is meant to run inside `$PROJECT_ROOT` of a target project, not against the plugin root.
- All hooks are designed to never break Claude: every hook except `pre-tool-safety.sh` exits 0 unconditionally; errors are routed to `progress/hooks.log` and (since v0.3.0) to stderr via `emit-status.sh`.
- `TODO(user):` markers exist in [templates/AGENTS.md:36-37](../templates/AGENTS.md#L36-L37) — these are intentional, prompts for the user to fill in domain notes after install.

### TODO/FIXME scan

`grep -rnE 'TODO|FIXME|XXX|HACK'` across `*.sh`, `*.md`, `*.json` (excluding `node_modules/`, `.git/`, archived plans):

- **No `TODO`/`FIXME`/`XXX`/`HACK` markers in `hooks/`, `scripts/`, `skills/`, `templates/`** (the implementation surface).
- `TODO(brief-clarify):` placeholders only appear in the historical `BRIEF-claude-harness.md` spec and in `docs/superpowers/plans/2026-05-03-claude-harness-plugin.md` — both are upstream design docs.
- One `TODO:` line in [docs/contributing.md](contributing.md#regenerating-the-architecture-diagram) noting that `excalidraw-cli@0.0.2` doesn't export to SVG/PNG; tracked as future tooling work.

---

## End — push checklist

The owner of this repo (not the agent) should run, in order:

```bash
git push origin main
git push origin v0.1.0 v0.2.0 v0.3.0
```

(Or `git push origin main --follow-tags` to do both in one shot — only works because every tag references a commit reachable from `main`.)

---

Generated by reading: plugin.json, hooks/*, hooks/lib/*, skills/*/SKILL.md, scripts/*, scripts/lib/*, scripts/harness/*, templates/*, docs/*, tests/, git state, and running `scripts/self-test.sh` + `scripts/harness/doctor.sh`.

Did not run: a clean install into a separate temp project (would require user permission; trust the install-v02 test suite for that contract).
