# Interop with Superpowers

## Flow diagram

```
User request
    │
    ▼
superpowers:brainstorming ────► docs/superpowers/specs/<file>.md
    │
    ▼
superpowers:writing-plans ─────► docs/superpowers/plans/<file>.md
    │
    ▼
claude-harness:breaking-down-features ──► features/backlog.md
    │
    ▼ (user starts work)
claude-harness:managing-feature-list ───► features/in-progress.md
    │
    ▼
superpowers:subagent-driven-development
    │  ├── implementer subagent
    │  │     │
    │  │     ▼
    │  │  claude-harness:tracking-progress ──► progress/current.md
    │  │                                       progress/subagents/<task>.md
    │  ├── spec-reviewer subagent
    │  └── code-quality-reviewer subagent
    │
    ▼ (all subtasks [x] + verification)
claude-harness:managing-feature-list ───► features/done.md
    │
    ▼
superpowers:finishing-a-development-branch
    │
    ▼
claude-harness:handing-off-session ──────► progress/history.md (drained)
```

## Responsibility table

| Question | Superpowers | claude-harness |
|---|---|---|
| How does design start? | brainstorming | — |
| How is work planned? | writing-plans | — |
| How is work executed? | subagent-driven-development | — |
| What will be built in this project? | — | features/backlog.md |
| What is being built now? | — | features/in-progress.md |
| What has been built? | — | features/done.md |
| What happened last session? | — | progress/history.md |
| What is happening right now? | — | progress/current.md |
| How is context isolated between subagents? | subagent-driven-development | — |
| How is a subagent report persisted? | — | tracking-progress |

## Key principle

Superpowers is the **process engine** (how to think, plan, and execute).
claude-harness is the **memory system** (what exists, what's done, what happened).

They compose without conflict because they write to different locations and handle different lifecycle events.
