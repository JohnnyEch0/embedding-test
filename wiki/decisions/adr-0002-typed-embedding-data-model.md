---
type: Decision
title: ADR-0002 Typed embedding data model
description: WordEmb/LineEmb/VerseEmb/PoemEmb dataclasses with PoemEmbeddings.load/save replace scaffold classes and raw dicts.
tags: [decisions, data-model, refactor]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
sources:
  - id: datapy
    resource: data.py
    title: data.py (resulting data layer)
    last_modified: 2026-11-19
  - id: kanban
    resource: KANBAN.md
    title: KANBAN.md (card 11)
    last_modified: 2026-11-24
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# ADR-0002: Typed embedding data model

**Date**: 2026-11-19
**Status**: Accepted
**Commits**: `4afc166`, `1a7c04a` (KANBAN card [11])

## Context

Embedding records circulated as raw dicts and JSONL; scaffold classes
(`Poem`/`PoemVerse`/`PoemLine`/`Embedding`, later erased in card [14]) had
drifted from the data they described. The Godot side needed a stable,
documented on-disk contract to consume.

## Decision

Introduce dataclasses `WordEmb`, `LineEmb`, `VerseEmb`, `PoemEmb` plus
`Metadata` and a one-file-per-poem store `PoemEmbeddings` with
`load`/`save` (format chosen by suffix) and symmetric `to_dict`/`from_dict`.
A byte-identity gate in `test_data.py` pins the serialization.

## Consequences

- One authoritative record model; `api_gemma.py` builds typed records and
  writes via `PoemEmbeddings.save` (`1a7c04a`).
- JSONL became the deprecated path (see ADR-0003); legacy consumers were
  severed first (card [12]) and removed (cards [13], [14]).
- Consumers with no typed loader are stranded: `dim_hunt_app.py`, `pca.py`
  (see [Stranded legacy scripts](/pipeline/legacy-scripts.md), cards [1], [2]).
- Godot consumes the same schema directly (ADR-0004).

## Related

- [Data layer](/pipeline/data-layer.md) — the resulting model
- [Data format](/data-format.md) — the on-disk schema
