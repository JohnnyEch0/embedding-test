---
type: Reference
title: Poem-Embeddings JSON Format
description: Schema of the one-file-per-poem embedding JSON (poem_emb/ d128, godot/data/ d32), naming, provenance, and legacy fixtures.
tags: [reference, data-format, json, embeddings]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: d128
    resource: poem_emb/eg2_d128_oread_h-d.json
    title: example d128 file
    last_modified: 2026-11-19
  - id: d32
    resource: godot/data/eg2_d32_oread_h-d.json
    title: example d32 file
    last_modified: 2026-11-19
  - id: datapy
    resource: data.py
    title: data.py (writer/reader of record)
    last_modified: 2026-11-19
  - id: spheresgd
    resource: godot/stars/spheres.gd
    title: godot/stars/spheres.gd (consumer)
    last_modified: 2026-11-24
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# Poem-Embeddings JSON Format

One file per poem, written by `PoemEmbeddings.save` (`data.py`) —
[ADR-0002](/decisions/adr-0002-typed-embedding-data-model.md),
[ADR-0003](/decisions/adr-0003-json-single-file-standard.md). All current
files in `poem_emb/` (d128) and `godot/data/` (d32) share this schema.

## Schema

```json
{
  "metadata": {
    "schema_version": 1,
    "author": "H.D.",
    "title": "Oread",
    "model": "google/embeddinggemma-2",
    "dimensions": 128,
    "procedures": ["api-embedding:google/embeddinggemma-2"],
    "type": "Poem-Embeddings"
  },
  "lines": [
    {
      "line_index": 0,
      "line": "Whirl up, sea—",
      "words": [ { "word": "Whirl", "embedding": [0.0, ...] } ],
      "line_embedding": [0.0, ...]
    }
  ],
  "verses": [
    {
      "verse_index": 0,
      "line_range": [0, 1],
      "text": "Whirl up, sea—",
      "verse_embedding": [0.0, ...]
    }
  ],
  "poem": { "text": "...", "poem_embedding": [0.0, ...] }
}
```

| Field | Notes |
|-------|-------|
| `metadata.schema_version` | 1 |
| `metadata.author` | from the poem's YAML frontmatter; `null` when absent |
| `metadata.dimensions` | vector length in this file (128 in `poem_emb/`, 32 in `godot/data/`) |
| `metadata.procedures` | provenance chain, appended by each stage — e.g. d32 files: `["api-embedding:...", "center", "abtt:d=2", "pca:k=32"]` |
| `lines[i].line_index` | index into `lines` (verses' `line_range` points here) |
| `lines[i].words[j].embedding` | word vector, length `dimensions` |
| `verses[i].line_range` | `[start, end)` — **end exclusive** (writer's convention) |
| `poem` | whole-poem text (verses joined by blank line) + embedding |

Dict key order is part of the on-disk contract; serialization is pinned by
the byte-identity gate in `test_data.py`.

## Naming and layout

- `eg2_d{dims}_{poem-stem}.json` — `eg2` = embeddinggemma-2, `d128`/`d32` =
  vector dimensionality, stem = poem filename without `.md`.
- `poem_emb/` — raw d128 stage-1 output.
- `godot/data/` (`res://data`) — reduced d32 corpus the app loads.
- `_pipeline.json` (output dir of stage 2, not shipped to `godot/data/`) —
  fitted state of the reduction: steps, seed, fit levels, fit shape,
  means/components.

## Deprecated: JSONL

`PoemEmbeddings` still reads/writes JSONL behind a default-false `--jsonl`
flag (metadata header line, then one record per line/verse/poem). Removal is
KANBAN card [7]. No JSONL files remain in the repo.

## Legacy fixtures in godot/data/

- `sample.json` — early dev schema: `lines` as flat strings, `embedding_dict`
  word → 6-dim vector, `metadata: null`. Not loadable as Poem-Embeddings.
- `example.json` — metadata-only remnant (`schema_version: 0`, no
  lines/verses/poem).

Both are kept for reference; the app picks files randomly or via the
`default_filename` export, so they can be loaded — and then fail with "No
lines in JSON data".

## Known consumer bug

`stars/spheres.gd` treats `verses[i].line_range` as **inclusive**
(`range(r[0], r[1] + 1)` with a `# ASSUMED inclusive` comment, plus an
inclusive hit-test), while the Python writer emits **exclusive** ends.
Effect: verse-related marking (verse-star hit tests, `verses_used` expansion)
includes the first line of the next verse. One-line off; no crash. Tracked as
KANBAN card [23].[^spheresgd]

## Related

- [Data layer](/pipeline/data-layer.md) — typed model
- [API embedding](/pipeline/api-embedding.md) — producer
- [Dimension reduction](/pipeline/dimension-reduction.md) — appends to `procedures`
- [ADR-0004](/decisions/adr-0004-godot-data-poem-embeddings.md) — godot consumes this schema directly

[^spheresgd]: godot/stars/spheres.gd (read during 2026-11-24 bundle rebuild)
