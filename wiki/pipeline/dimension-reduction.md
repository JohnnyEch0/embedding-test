---
type: Pipeline Stage
title: Dimension Reduction Stage (dimension_reduction.py)
description: Fits a step pipeline (center/abtt/pca/...) across all poems and writes reduced eg2_d32_*.json plus _pipeline.json.
tags: [pipeline, dimension-reduction, pca, abtt]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: dimred
    resource: dimension_reduction.py
    title: dimension_reduction.py (stage source)
    last_modified: 2026-11-19
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# Pipeline Stage: Dimension Reduction

`dimension_reduction.py` is stage 2: it takes the `eg2_d128_*.json` corpus and
produces reduced files (d32 by default) for `godot/data/`.

## Invocation

```bash
python3 dimension_reduction.py <input_dir> <output_dir> \
    [--steps "center abtt:d=2 pca:k=32"] [--fit-levels words,lines,verses,poems] \
    [--seed 0] [--decimals 6]
```

## Step registry

Steps are classes registered in `REGISTRY`; the `--steps` spec lists them
space- or `+`-separated, params as `name:a=1;b=2`.[^dimred]

| Step | Params | Effect |
|------|--------|--------|
| `center` | — | subtract corpus mean |
| `abtt` | `d` (default 1) | all-but-the-top: remove mean + top-`d` PCA directions |
| `pca` | `k` or `var` (default 0.95) | SVD-based PCA, components ordered by variance |
| `ica` | `k` (default min(32, d)) | FastICA, ordered by \|excess kurtosis\|, sign by skew |
| `l2` | — | row-normalize |
| `trunc` | `k` | Matryoshka truncation (MRL models only) |

The default `center abtt:d=2 pca:k=32` is what produced the current
`godot/data/eg2_d32_*.json` corpus.[^dimred]

## Fit/transform discipline

- **Fit** on the unique rows (`np.unique`) of all poems × `--fit-levels`
  (default: all four levels) — one shared transform for the whole corpus.
- **Transform** every level of every poem, write back rounded to
  `--decimals` (default 6), update `metadata.dimensions`, and append the step
  labels to `metadata.procedures` (e.g. `["api-embedding:...", "center",
  "abtt:d=2", "pca:k=32"]`).
- Output files keep the input filename; the `d128`→`d32` rename is currently
  manual (KANBAN card [17]).
- Emits `output_dir/_pipeline.json` — steps, seed, fit levels, fit shape, and
  full fitted state (means, components, explained variance) for
  reproducibility.

## Related

- [API embedding](/pipeline/api-embedding.md) — stage 1
- [Data format](/data-format.md) — `procedures` and `dimensions` fields
- [Regenerate embeddings](/runbooks/regenerate-embeddings.md)

[^dimred]: dimension_reduction.py (read during 2026-11-24 bundle rebuild)
