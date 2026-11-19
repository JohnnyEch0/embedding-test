---
type: Reference
title: JSON Data Formats
description: Schemas of the JSON files in godot/data/ — sample.json (legacy) and eg2_d32_*.json (poem embeddings).
tags: [reference, data-format, json, embeddings]
---

# JSON Data Formats

The `godot/data/` directory (`res://data` in-game) contains two distinct JSON schemas. `spheres.gd`'s `_read_json()` loads whichever file `_resolve_path()` picks — default filename first, random fallback.

## `sample.json` (legacy schema)

```json
{
  "lines": ["You do not have to be good.", ...],
  "embedding_dict": {"You": [0.075, -0.037, ...], ...},
  "metadata": null
}
```

- `lines` — flat list of line strings (18 entries).
- `embedding_dict` — word → 6-dim vector (86 entries). No `verses`, `poem`, or word-level `words` arrays.
- `metadata` — null placeholder.

## `eg2_d32_*.json` (poem embedding schema)

All 11 `eg2_d32_*.json` files share this schema:

```json
{
  "metadata": {
    "schema_version": 1,
    "author": "H.D.",
    "title": "Oread",
    "model": "google/embeddinggemma-2",
    "dimensions": 32,
    "procedures": ["api-embedding:...", "center", "abtt:d=2", "pca:k=32"],
    "type": "Poem-Embeddings"
  },
  "lines": [
    {
      "line_index": 0,
      "line": "Whirl up, sea—",
      "words": [
        {"word": "Whirl", "embedding": [-0.122, ...]},
        ...
      ],
      "line_embedding": [...]
    }
  ],
  "verses": [{"verse_index": 0, "line_range": [0, 4], "text": "...", "verse_embedding": [...]}],
  "poem": {"text": "...", "poem_embedding": [...]}
}
```

- `metadata.dimensions` — 32 (matches `d32` in filenames).
- `lines[i].words[j].embedding` — per-word vector, length 32.
- `verses[i].verse_embedding`, `poem.poem_embedding` — same length.

## Consumer mismatch (known issue)

`spheres.gd`'s `_ready()` does:

```gdscript
var first_line: String = data["lines"][0]
var emb_dict = data["embedding_dict"]
```

- Works with `sample.json` (lines are strings, `embedding_dict` exists).
- **Crashes** on `eg2_d32_*.json` — `data["lines"][0]` is a dict, and `data["embedding_dict"]` doesn't exist.

`_read_json()` itself is schema-agnostic — it just parses and returns the dict. The crash happens downstream in `_ready()`.

## Generation

- `sample.json` — legacy, unclear origin.
- `eg2_d32_*.json` — produced by `api_gemma.py` (ScaDS AI API, `google/embeddinggemma-2`). See [ADR-0001](decisions/adr-0001-use-scads-api-for-embeddings.md).

## Related

- [Architecture Overview](overview.md)
- [Changelog](changelog.md)
