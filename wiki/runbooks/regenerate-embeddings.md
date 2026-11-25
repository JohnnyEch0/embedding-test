---
type: Runbook
title: Regenerate Embeddings
description: Full pipeline run from poem/ through d128 embedding and d32 reduction into godot/data/.
tags: [runbook, pipeline, embeddings]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: apigemma
    resource: api_gemma.py
    title: api_gemma.py (stage 1)
    last_modified: 2026-11-19
  - id: dimred
    resource: dimension_reduction.py
    title: dimension_reduction.py (stage 2)
    last_modified: 2026-11-19
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# Runbook: Regenerate Embeddings

Produces a fresh `godot/data/` corpus from `poem/`. Stages:
[API embedding](/pipeline/api-embedding.md) →
[dimension reduction](/pipeline/dimension-reduction.md).

## Prerequisites

- `python3` with `openai`, `numpy` (plus `scikit-learn` if you use the `ica` step).
- API key in `~/.tudai-api-key` (single line) — `api_gemma.py` exits without it.
- A `godot` 4.x binary only if you want to view/test the result.

## Steps

```bash
# 1. Embed the corpus (d128, one file per poem)
python3 api_gemma.py poem poem_emb

# 2. Reduce across the whole corpus (default: center abtt:d=2 pca:k=32 -> d32)
python3 dimension_reduction.py poem_emb reduced

# 3. Rename d128 -> d32 in the reduced filenames (manual until card [17])
cd reduced && for f in eg2_d128_*.json; do mv "$f" "eg2_d${f#eg2_d128_}"; done; cd ..

# 4. Install into the app
cp reduced/eg2_d32_*.json godot/data/
```

Notes:

- Step 1 overwrites files with the same stem in `poem_emb/` — re-embedding a
  poem replaces its d128 file.
- Step 2 fits **one shared transform** over the unique rows of the whole
  input corpus (`--fit-levels` defaults to all four levels); it fails fast on
  mixed input dimensions.
- Verify afterwards: `metadata.dimensions` is 32, `metadata.procedures` ends
  with `["center", "abtt:d=2", "pca:k=32"]`, and `reduced/_pipeline.json`
  holds the fitted state for exact reproducibility.
- Custom reduction: `--steps "center pca:k=8"`, `--fit-levels words,lines`,
  `--seed`, `--decimals` — see the stage concept for the step registry.

## Related

- [Run tests](/runbooks/run-tests.md)
- [Data format](/data-format.md)
