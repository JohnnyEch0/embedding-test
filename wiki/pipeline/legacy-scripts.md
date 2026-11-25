---
type: Legacy Component
title: Stranded Legacy Scripts (dim_hunt_app.py, pca.py)
description: Exploration scripts with no working data source; dim_hunt_app.py raises NotImplementedError on import.
tags: [legacy, exploration, dash, plotly]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: dimhunt
    resource: dim_hunt_app.py
    title: dim_hunt_app.py (stranded Dash app)
    last_modified: 2026-11-19
  - id: pca
    resource: pca.py
    title: pca.py (standalone Plotly PCA)
    last_modified: 2026-10-21
  - id: kanban
    resource: KANBAN.md
    title: KANBAN.md (open cards 1, 2)
    last_modified: 2026-11-24
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# Stranded Legacy Scripts

Two exploration scripts predate the typed data layer and currently have no
working data source. Neither is part of the pipeline.

## `dim_hunt_app.py`

Single-file Dash app: interactive 1D/2D/3D embedding-dimension explorer
(rankings of dimensions by spread/offset, line selection, tables).

- **Status: no data source.** The legacy JSONL load was removed and the
  standard-JSON loader is not implemented; the module `raise
  NotImplementedError` at import, so running it crashes immediately.[^dimhunt]
- Below the raise sit format-agnostic analysis helpers (`dim_stats`,
  `center_standardize`, ...) usable standalone.[^dimhunt]
- **Open cards:** [1] rebuild the dim-analysis stage on
  `PoemEmbeddings.load()` output; [2] decide the app's fate (rebuild on the
  new format or delete). Card [2] gates card [7] (JSONL removal).[^kanban]

## `pca.py`

Standalone Plotly script: fit PCA on a word-embedding matrix, print
variance report + loadings, scatter-3d and scree plots.

- Hardcoded path `poem_emb/linewise_emb-per-word/eg2_d128_wild-geese_*.jsonl`
  no longer exists (legacy layout, gone since the typed refactor).[^pca]
- No KANBAN card; effectively dormant. The in-pipeline replacement for most
  of this is the `pca` step in [dimension_reduction.py](/pipeline/dimension-reduction.md).[^pca]

## Related

- [KANBAN protocol](/conventions/agent-conventions.md) — cards [1], [2], [7]
- [Data layer](/pipeline/data-layer.md) — the intended future data source

[^dimhunt]: dim_hunt_app.py (read during 2026-11-24 bundle rebuild)
[^pca]: pca.py (read during 2026-11-24 bundle rebuild)
[^kanban]: KANBAN.md (read during 2026-11-24 bundle rebuild)
