# Bundle Update Log

## 2026-11-19

* **Initialization**: Created the Open Knowledge bundle scaffold.
* **Setup**: Interviewed user; wiki scope is high-level architecture overview for future coding agents, with ADR-style decisions and a changelog.
* **Content**: Added [Architecture Overview](overview.md), [Changelog](changelog.md), and [ADR-0001: Use ScaDS AI API for embeddings](decisions/adr-0001-use-scads-api-for-embeddings.md).
* **Cleanup**: Deleted SETUP.MD after setup completed.

## 2026-11-24

* **Regeneration**: Rebuilt the bundle against current code (worktree state `7969d95`). Rewrote [overview](overview.md), [data format](data-format.md), [changelog](changelog.md), [Agent Rules](AGENTS.md); ADR-0001 gained trust frontmatter + an addendum (local `gemma.py` fallback removed).
* **Creation**: New concepts — [pipeline/](pipeline/index.md) (api-embedding, dimension-reduction, data-layer, legacy-scripts), [godot/](godot/index.md) (architecture, dim-map, headless-testing), [runbooks/](runbooks/regenerate-embeddings.md), [agent conventions](conventions/agent-conventions.md), and ADR-0002 … ADR-0005 in [decisions/](decisions/index.md).
* **Verification**: `okf_validate.py --strict` clean except one false-positive on the pinned upstream `SPEC.md` (its v0.1 example contains a `# Citations` line inside a code fence).
