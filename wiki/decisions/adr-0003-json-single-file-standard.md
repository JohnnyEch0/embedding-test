---
type: Decision
title: ADR-0003 JSON single-file standard
description: One JSON object per poem file is the standard format; JSONL is deprecated behind a default-false flag.
tags: [decisions, data-format, json]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
sources:
  - id: datapy
    resource: data.py
    title: data.py (save/load by suffix)
    last_modified: 2026-11-19
  - id: kanban
    resource: KANBAN.md
    title: KANBAN.md (cards 10, 7)
    last_modified: 2026-11-24
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# ADR-0003: JSON single-file standard

**Date**: 2026-11-19
**Status**: Accepted
**Commits**: `0b13de8` (KANBAN card [10], branch `json-single-file`)

## Context

The store was JSONL: a metadata header line, then one record per line, verse,
and finally the poem. Header detection and record-kind sniffing
(`schema_version` / `line_index` / `verse_index` / `poem`) made readers
fragile, and it mapped poorly onto Godot's `JSON` class, which parses one
document.

## Decision

A single JSON object per poem file is the standard format
(`PoemEmbeddings.save`/`load` with `.json`). JSONL is kept behind a
default-false `--jsonl` flag and marked deprecated in the code; its removal
is KANBAN card [7], blocked by the fate of `dim_hunt_app.py` (card [2]).

## Consequences

- Atomic read/write; trivially parseable in GDScript (one
  `json.parse` of the whole file) — the basis for ADR-0004.
- `PoemEmbeddings.from_jsonl`/`to_jsonl` remain as the compatibility path.
- All current data (`poem_emb/`, `godot/data/`) is single-file JSON.

## Related

- [Data format](/data-format.md)
- [Stranded legacy scripts](/pipeline/legacy-scripts.md) — what gates card [7]
