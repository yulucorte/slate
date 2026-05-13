# Contributing to claude-harness

claude-harness is intentionally small. Before opening a PR, please:

1. Run `bash scripts/self-test.sh` and confirm `20 pass, 0 fail` (or whatever the current count is at HEAD).
2. Keep the contract Markdown-only — no JSON/YAML/SQLite alternatives for state.
3. Touch only one concern per commit; the existing history uses conventional prefixes (`feat`, `fix`, `docs`, `chore`, `test`).
4. If you modify a hook, add or update a `tests/test-hook-*.sh` suite.
5. If you modify a skill, run [skills/verify-harness-hooks](../skills/verify-harness-hooks/SKILL.md) against a freshly-installed project.

## Optional tooling

### Regenerating the architecture diagram

The architecture diagram has two source files in [docs/assets/](assets/):

- [`claude-harness-overview.json`](assets/claude-harness-overview.json) — a hand-written element spec consumed by `excalidraw-cli create`.
- [`claude-harness-overview.excalidraw`](assets/claude-harness-overview.excalidraw) — the regenerated Excalidraw scene (canonical), and the source behind the ASCII reproduction in [docs/STATE-OF-HARNESS.md §2](STATE-OF-HARNESS.md#2-architecture-ascii).

To rebuild the `.excalidraw` after editing the `.json` spec:

```bash
npx --yes excalidraw-cli@0.0.2 create \
    --input docs/assets/claude-harness-overview.json \
    --output docs/assets/claude-harness-overview.excalidraw
```

claude-harness has no Node dependencies (no `package.json` in the repo); `excalidraw-cli` is only mentioned here as an optional one-off tool for contributors who want to regenerate the diagram.

TODO: `excalidraw-cli@0.0.2` does not export to SVG/PNG — it only builds `.excalidraw` scenes from JSON specs. To produce a rasterized/vector image, open the `.excalidraw` file in <https://excalidraw.com> and export from there (File → Export image…), or use a different CLI (e.g. `excalidraw-mcp`). When a settled tool exists, document the export command here.
