---
type: Data Model
title: Embedding Data Layer (data.py)
description: Typed record classes WordEmb/LineEmb/VerseEmb/PoemEmb and the one-file-per-poem PoemEmbeddings store.
tags: [data-model, data-layer, json, schema]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: datapy
    resource: data.py
    title: data.py (data layer source)
    last_modified: 2026-11-19
  - id: testdata
    resource: test_data.py
    title: test_data.py (round-trip tests)
    last_modified: 2026-11-19
  - id: a2
    resource: /decisions/adr-0002-typed-embedding-data-model.md
    title: ADR-0002 Typed embedding data model
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# Data Layer

`data.py` defines the typed record model shared by the pipeline and consumed
as the on-disk schema. Introduced by the typed refactor — see
[ADR-0002](/decisions/adr-0002-typed-embedding-data-model.md).

## Classes

| Class | Role |
|-------|------|
| `WordEmb` | one word + its vector. Dict key order is the on-disk contract |
| `LineEmb` | `line_index`, `line`, `words: list[WordEmb]`, `line_embedding` |
| `VerseEmb` | `verse_index`, `line_range: (start, end)` — **exclusive end** into the poem's lines, `text`, `verse_embedding` |
| `PoemEmb` | `text`, `poem_embedding` |
| `Metadata` | `schema_version` (1), `author` (may be `None`), `title`, `model`, `dimensions`, `procedures`; `from_dict` tolerates missing `procedures` |
| `PoemEmbeddings` | the store: `metadata`, `lines`, `verses`, `poem`; `save`/`load` dispatch on file suffix |

`save`/`load` choose the format by suffix: `.json` (standard single file) or
`.jsonl` (deprecated); anything else raises `ValueError`.[^datapy]

## Contracts

- Every record has symmetric `to_dict`/`from_dict`; `PoemEmbeddings.to_dict`
  injects `type: "Poem-Embeddings"` into the metadata header.
- `VerseEmb.line_range` end is **exclusive** in the Python writer;
  `godot/stars/spheres.gd` currently consumes it as inclusive (see the off-by-one
  note in [Data format](/data-format.md#known-consumer-bug)).
- The `__main__` demo block is dead (TODO: rewrite against
  `PoemEmbeddings.load()`).[^datapy]

## Tests

`test_data.py` round-trips the model through both formats and asserts
byte-identity of the JSON serialization (the "byte-identity gate" from
ADR-0002).[^testdata]

## Related

- [Data format](/data-format.md) — the on-disk schema
- [API embedding](/pipeline/api-embedding.md) — producer of records
- [Dimension reduction](/pipeline/dimension-reduction.md) — mutates records in place

[^datapy]: data.py (read during 2026-11-24 bundle rebuild)
[^testdata]: test_data.py (read during 2026-11-24 bundle rebuild)
