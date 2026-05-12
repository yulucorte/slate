---
name: harness-create-branch
description: Use when the user asks to create the git branch for a claude-harness feature, says "create branch for FEAT-X", "switch to the dark-mode branch", or wants to manually trigger branch creation when HARNESS_AUTO_BRANCH=false. Reads the feature's Branch field and runs git switch -c.
---

# Create a branch for a harness feature

Manually create the git branch declared in a feature's `Branch:` field. Used when `HARNESS_AUTO_BRANCH=false` (the default) and the user wants the branch explicitly.

## When to invoke

- User says: "create branch for FEAT-X", "switch to the branch for the dark-mode feature", "make the branch"
- After a feature lands in `features/in-progress.md` and the user wants the branch
- After a watcher hook printed a `→ harness: FEAT-X ready — run: git switch -c ...` suggestion

## Preconditions

1. Feature exists in `features/in-progress.md` with a `Branch:` field that is not `none`.
2. Working tree has no uncommitted changes that would block a branch switch. If dirty, ask the user whether to commit/stash first — do not silently lose work.

## How to invoke

```bash
# Parse the feature's Branch field
BRANCH=$(bash "${CLAUDE_PLUGIN_ROOT}/hooks/lib/read-feature.sh" \
  "${PROJECT_ROOT:-.}/features/in-progress.md" "<FEAT-ID>" \
  | grep '^branch=' | cut -d= -f2-)

# Create or switch
git -C "${PROJECT_ROOT:-.}" switch -c "$BRANCH" 2>/dev/null \
  || git -C "${PROJECT_ROOT:-.}" switch "$BRANCH"
```

## Reporting to the user

- Newly created: "Branch `<branch>` created and checked out."
- Already existed: "Branch `<branch>` already existed — switched to it."
- Failed: surface the git error and suggest checking working tree state.
