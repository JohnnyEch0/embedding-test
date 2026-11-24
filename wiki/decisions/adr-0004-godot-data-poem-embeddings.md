---
type: Decision
title: ADR-0004 Godot data is Poem-Embeddings JSON
description: godot/data holds the pipeline's eg2_d32_*.json files directly; spheres.gd reads the PoemEmbeddings schema, not the legacy embedding_dict.
tags: [decisions, godot, data-format]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
sources:
  - id: spheresgd
    resource: godot/spheres.gd
    title: spheres.gd (data loading)
    last_modified: 2026-11-24
  - id: kanban
    resource: KANBAN.md
    title: KANBAN.md (card 3)
    last_modified: 2026-11-24
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# ADR-0004: Godot data = Poem-Embeddings JSON

**Date**: 2026-11-19
**Status**: Accepted
**Commits**: `1bf149f`, `5e5cf8f` (KANBAN card [3])

## Context

`spheres.gd` consumed a legacy `sample.json` schema (`lines` as flat strings,
`embedding_dict` word → vector). The pipeline now emits typed
Poem-Embeddings JSON (ADR-0002/0003); the two schemas were incompatible —
loading `eg2_d32_*.json` with the old reader crashed in `_ready()`.

## Decision

`godot/data/` holds the pipeline's single-file JSON directly
(`eg2_d32_*.json`, the reduced d128→d32 corpus). `spheres.gd` reads
`metadata`/`lines`/`verses`/`poem` from the Poem-Embeddings schema; the
legacy `embedding_dict` path is gone. `sample.json` and `example.json` remain
in the data directory as legacy fixtures only.

## Consequences

- Pipeline and app share one schema — no conversion step; the runbook is
  "produce, (rename), copy" ([Regenerate embeddings](/runbooks/regenerate-embeddings.md)).
- `dim_count` is read from `metadata.dimensions`, which makes the
  `Main` ↔ `Spheres` dim-handshake assert meaningful (see
  [Architecture](/godot/architecture.md)).
- One known consumer bug remains: `spheres.gd` treats `line_range` as
  inclusive while the Python writer emits exclusive ends (see
  [Data format](/data-format.md#known-consumer-bug)).
- Dimension analysis output was split out of this card into card [1].

## Related

- [Data format](/data-format.md)
- [Godot architecture](/godot/architecture.md)
