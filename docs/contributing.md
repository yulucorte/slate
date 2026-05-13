# Contributing to claude-harness

claude-harness is intentionally small. Before opening a PR, please:

1. Run `bash scripts/self-test.sh` and confirm `20 pass, 0 fail` (or whatever the current count is at HEAD).
2. Keep the contract Markdown-only — no JSON/YAML/SQLite alternatives for state.
3. Touch only one concern per commit; the existing history uses conventional prefixes (`feat`, `fix`, `docs`, `chore`, `test`).
4. If you modify a hook, add or update a `tests/test-hook-*.sh` suite.
5. If you modify a skill, run [skills/verify-harness-hooks](../skills/verify-harness-hooks/SKILL.md) against a freshly-installed project.

## Optional tooling

### Regenerating the architecture diagram

The architecture diagram lives in [docs/assets/claude-harness-overview.excalidraw](assets/claude-harness-overview.excalidraw) (Excalidraw source) and is the canonical sketch behind the ASCII reproduction in [docs/STATE-OF-HARNESS.md §2](STATE-OF-HARNESS.md#2-architecture-ascii).

To export the `.excalidraw` file to SVG/PNG without installing anything globally:

```bash
npx excalidraw-cli@^0.0.2 docs/assets/claude-harness-overview.excalidraw \
    --output docs/assets/claude-harness-overview.svg
```

(claude-harness itself has no Node dependencies — there is no `package.json` in the repo. `excalidraw-cli` is only mentioned here as an optional one-off tool for contributors who want to regenerate the diagram.)
