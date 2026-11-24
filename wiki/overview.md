---
type: Overview
title: EmbVis Architecture Overview
description: High-level architecture and data flow of the embedding visualization project.
tags: [architecture, overview]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: readme
    resource: README.md
    title: README.md
    last_modified: 2026-11-19
  - id: datapy
    resource: data.py
    title: data.py
    last_modified: 2026-11-19
  - id: maingd
    resource: godot/main.gd
    title: godot/main.gd
    last_modified: 2026-11-24
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# EmbVis Architecture Overview

EmbVis visualizes poem embeddings as a star field and lets you steer which
embedding dimensions are displayed. The unit of analysis is a poem: markdown
in, star field out.

## Data flow

```
poem/ (11 .md poems, YAML frontmatter: author/title/...)
    │
    ├─ api_gemma.py ── ScaDS AI API (embeddinggemma-2) ──> poem_emb/eg2_d128_*.json
    │        (word + line + verse + poem embeddings, one pass per poem)
    │
    ├─ dimension_reduction.py ── center · abtt:d=2 · pca:k=32 (one shared fit)
    │        ──> eg2_d32_*.json  (+ _pipeline.json fitted state)
    │
    └─ rename d128→d32 (manual, card [17]), copy ──> godot/data/
             │
             └─ godot/ (4.7) ── star visualization, DimMap axis steering
```

One JSON schema end-to-end: the [Poem-Embeddings format](/data-format.md).

## Core components

| Component | File(s) | Purpose |
|-----------|---------|---------|
| API embedding | `api_gemma.py` | Stage 1 — embed poems via ScaDS AI API, write d128 JSON |
| Dimension reduction | `dimension_reduction.py` | Stage 2 — step pipeline over the corpus, writes d32 JSON |
| Data layer | `data.py` | Typed records (`WordEmb`…`PoemEmb`) + `PoemEmbeddings` store |
| Auth | `auth.py` | OpenAI-compatible client for `llm.scads.ai`, key from `~/.tudai-api-key` |
| Godot app | `godot/` | Star visualization: `main.gd` (wiring), `spheres.gd` (data + stars), `dim_map.gd` (axis state), `input_handler.gd` (signals), `auto_orbit.gd`, `emb_star.tscn` |
| Tests | `test_api_gemma.py`, `test_data.py`, `godot/test_*.gd` | pytest + headless GDScript |
| Task tracking | `KANBAN.md` | Cards 1–22, commit-referenced (see [Agent conventions](/conventions/agent-conventions.md)) |

## Design shape

- **Pipeline is fit-once, apply-everywhere**: the reduction transform is fit
  on unique rows of the whole corpus, then applied to every level of every
  poem; provenance is recorded in `metadata.procedures`.
- **Godot is model/input/view split** ([ADR-0005](/decisions/adr-0005-godot-model-input-view-split.md)):
  `DimMap` is pure state, `InputHandler` maps raw events to semantic signals,
  `main.gd` only wires. The split exists so the core is
  [headless-testable](/godot/headless-testing.md).
- **Decisions live in [decisions/](decisions/index.md)** (ADRs 0001–0005).

## Legacy / stranded (do not build on these)

- `dim_hunt_app.py` — raises `NotImplementedError` on import (no data source);
  fate open (cards [1], [2]) — [details](/pipeline/legacy-scripts.md).
- `pca.py` — hardcoded to a removed legacy path; dormant.
- `godot/data/sample.json`, `example.json` — legacy fixtures, not pipeline output.
- `README.md` is stale (mentions `api-gemmy.py`, word-only JSONL output);
  treat this bundle as the current reference.

## Getting started

[Regenerate embeddings](/runbooks/regenerate-embeddings.md) ·
[Run tests](/runbooks/run-tests.md) ·
[Agent conventions](/conventions/agent-conventions.md)

## Related

- [JSON Data Format](/data-format.md)
- [Changelog](/changelog.md)
- [Decisions](decisions/index.md)
