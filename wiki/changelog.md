---
type: Changelog
title: EmbVis Changelog
description: Notable changes to the EmbVis project, newest first.
tags: [changelog]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
sources:
  - id: kanban
    resource: KANBAN.md
    title: KANBAN.md (done cards with commit refs)
    last_modified: 2026-11-24
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# Changelog

Notable changes only. For the full commit history, see `git log`; for task
context, `KANBAN.md`.

## 2026-11-24

- **InputHandler extracted from `main.gd`** (card [20], `ea7c179`): raw input
  → semantic signals; dispatch hardened (user input terminates dispatch,
  typed axis dispatch), `Shift+R/F/G/H` reverse actions fixed via exact-match
  dispatch (`1e9dc47`), headless dispatch tests added (`7eef1be`), dim
  handshake assert in `main.gd` (`c8242df`).
- DimMap `get_dim` warns once on unknown axis (`3f7787d`, card [21]).
- **DimsHud extracted from `main.gd`** (card [22], `d639f74`/`480225b`):
  `godot/dims_hud.gd`, a bound observer of `DimMap` (`bind()` tracks
  `changed`); layout in `main.tscn`; headless test `test_dims_hud.gd` —
  completes the model/input/view split. Startup line set `[0..7]` confirmed
  intentional (card [19]).
- `GLOSSARY.md` added (LAPMAN — the reporting-budget term).

## 2026-11-23

- **Manual dimension switching** (card [18]): `DimMap` pure X/Y/Z mapping
  state (`5e827e4`), star projection decoupled from hardcoded dims 0/1/2
  (`79ec0a2`), `R`/`Shift+R` trio jump + `F`/`G`/`H` per-axis stepping and an
  always-visible dims HUD (`77e6e8b`); headless DimMap test spec (`e8b1c31`).
- DimMap emits `changed` only on real mapping change (`a5fe7bf`); HUD
  anchored top-left, resize-safe (`5b84450`); embedding/metadata dim-mismatch
  warning (`9af55b3`); `show_*` flag injection fixed (`aef8084`).

## 2026-11-20

- Verse/line/poem embedding stars shown alongside word stars (`8f32a42`);
  camera orbit automation (`53c6610`); input-driven line advance (`2e85089`).

## 2026-11-19

- **Typed data layer** (card [11], `4afc166`/`1a7c04a`): `WordEmb`/`LineEmb`/`VerseEmb`/`PoemEmb` + `PoemEmbeddings.load/save`; scaffold classes erased (card [14]).
- **Single-file JSON is the standard format** (card [10], `0b13de8`); JSONL deprecated behind `--jsonl`.
- **Godot schema = Poem-Embeddings JSON** (card [3], `1bf149f`): `spheres.gd` off the legacy `embedding_dict`; godot data regenerated as d32.
- 10 new poems (corpus now 11) + `dimension_reduction.py` step registry
  center/abtt/pca (`6beb2b5`, `5e5cf8f`, card [16]).
- Author/title metadata from per-poem YAML frontmatter (card [4], `6b7af2c`);
  `Metadata.from_dict` title bug fixed (card [15], `486620f`).
- Legacy consumers severed and removed: `dim_hunt_app.py`/`data.py` demo
  (card [12]), `LinewiseEmbeddingPerWord` + `helpers.py` (card [13]).

## 2026-11-17

- Added `api_gemma.py` — batch-embed words from .md poems via ScaDS AI API.
- Added tests (`test_api_gemma.py`).

## 2026-11-16

- Added `dim_hunt_app.py` / `dim_hunt_data.py` — interactive Dash app for embedding dimension exploration.
- Added `pca.py` — PCA on word embeddings.
- Added `binder_mapping.py` — mapping embeddings to neuroscientific binder features.

## Earlier

- Initial scaffolding: `gemma.py`, `data.py`, `helpers.py`, `auth.py`, Godot project.
  (`gemma.py`, `helpers.py`, `binder_mapping.py`, `dim_hunt_data.py` have since been removed; see [Legacy](/pipeline/legacy-scripts.md) and the 2026-11-19 entry.)
