---
type: Overview
title: EmbVis Architecture Overview
description: High-level architecture and data flow of the embedding visualization project.
tags: [architecture, overview]
---

# EmbVis Architecture Overview

EmbVis visualizes text embeddings in an aesthetic, star-like way. The project treats a poem (or any markdown text) as the unit of analysis, embeds it, then explores and visualizes the resulting vector space.

## Data Flow

```
poem/ (markdown source)
    │
    ├── api_gemma.py ──> ScaDS AI API (embeddinggemma-2) ──> JSONL (word-level embeddings)
    │
    ├── gemma.py ──> sentence_transformers (local) ──> embeddings
    │
    └── dim_hunt_app.py / pca.py ──> Dash / Plotly ──> interactive exploration
    │
    └── godot/ ──> Godot engine ──> star-like visualization
```

## Core Components

| Component | File(s) | Purpose |
|-----------|---------|---------|
| API embedding | `api_gemma.py` | Batch-embed words from .md poems via ScaDS AI API, output JSONL |
| Local embedding | `gemma.py` | Embed via sentence_transformers locally (sentence_transformers) |
| Data layer | `data.py`, `helpers.py` | Load/save embeddings, JSONL parsing, Metadata class |
| Dimension hunt | `dim_hunt_app.py`, `dim_hunt_data.py` | Interactive Dash app for 1D/2D/3D embedding dimension exploration |
| PCA | `pca.py` | Principal component analysis on word embeddings |
| Binder mapping | `binder_mapping.py` | Map embeddings to neuroscientific binder features |
| Auth | `auth.py` | Load ScaDS AI API key from `~/.tudai-api-key` |
| Visualization | `godot/` | Godot project for star-like embedding visualization |

## Key Details

- **Model**: `google/embeddinggemma-2` via ScaDS AI API (see `api_gemma.py`)
- **Default dims**: 128 (configurable via `--dims`)
- **Batch size**: 256 words per API call (configurable via `--batch`)
- **Input**: markdown poems in `poem/` directory
- **Output**: JSONL files with word-level embeddings, one record per line

## Testing

Run tests with:

```bash
python -m pytest test_api_gemma.py
```

## Related

- [Decisions](decisions/index.md) — architecture decision records
- [Changelog](changelog.md) — notable changes
