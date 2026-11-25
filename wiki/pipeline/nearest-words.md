---
type: Pipeline Stage
title: Nearest Words (api_gemma_vocabulary.py, api_gemma_nearest_n.py)
description: Vocabulary embedding index plus nearest-word annotation for poem JSONs — semantic lookup, outside the main pipeline.
tags: [pipeline, embeddings, vocabulary, nearest-neighbors]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-25T14:21:07Z }
stale_after: 2027-02-25T00:00:00Z
sources:
  - id: vocab
    resource: api_gemma_vocabulary.py
    title: api_gemma_vocabulary.py (index builder)
    last_modified: 2026-11-25
  - id: nearest
    resource: api_gemma_nearest_n.py
    title: api_gemma_nearest_n.py (annotator)
    last_modified: 2026-11-25
  - id: apigemma
    resource: api_gemma.py
    title: api_gemma.py (shared client, model/dims/batch)
usage_window: { from: 2026-11-25, to: 2026-11-25 }
---

# Pipeline Stage: Nearest Words

A vocabulary-index pair that answers *which common words sit closest to this
embedding?* It sits **outside** the embed → reduce pipeline: it consumes
[API embedding](api-embedding.md) output and never writes back into it.

## Index — `api_gemma_vocabulary.py`

Embeds the 10,000 most common English words (`wordfreq` `top_n_list`,
alpha-only) through the shared `api_gemma` client — same model, dims, and
batch constants as [stage 1](api-embedding.md).[^vocab]

- Output: `out/vocab_10k/` — `vectors.npy`, `vocab.txt`, `meta.json`
  (model/dims/source + unit-norm flag), plus per-shard checkpoints in
  `shards/`. `out/` is gitignored; the index is a regenerable artifact.
- Resumable: reruns skip completed shards. If `vocab.txt` drifts from the
  current wordfreq list, the script aborts rather than mix vocabs.
- Vectors are stored as returned; the script warns (does not renormalize) if
  they are not unit-norm.

## Annotator — `api_gemma_nearest_n.py`

Loads the index (hardcoded `out/vocab_10k`; refuses a dimension mismatch
against the poem JSON's `metadata.dimensions`) and, for a poem JSON, finds
the top-`n` most similar vocab words (cosine — the index is L2-normalized)
for **every** word, line, verse, and poem embedding. Words already present
in the queried text are masked to `-inf`, so neighbors are always
*different* words.[^nearest]

```bash
python3 api_gemma_nearest_n.py poem.json               # print
python3 api_gemma_nearest_n.py poem.json -n 20 --save  # also write <stem>_neighbors.json
```

Output JSON: the poem's `metadata`, the index path and `n`, and a mirrored
lines/verses/poem structure where every level carries a
`neighbors: [{word, score}]` list.

## Related

- [API embedding](api-embedding.md) — stage 1; shared client and embedding format
- [Data format](/data-format.md) — the poem JSON schema the annotator reads
- [Data layer](data-layer.md) — `PoemEmbeddings` record model

[^vocab]: api_gemma_vocabulary.py (read 2026-11-25)
[^nearest]: api_gemma_nearest_n.py (read 2026-11-25)
