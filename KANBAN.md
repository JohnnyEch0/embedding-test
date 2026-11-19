# KANBAN — embedding-test

Protocol:
- A card moves column in the same commit that changes its state.
- Starting a task → card to **In Progress**; the completion commit flips it to **Done** with its hash.
- Card numbers are assigned once and never re-used. Next free number: **18**.
- Cards carry branch/commit refs where they exist.

## Backlog

- [2] Rebuild `dim_hunt_app.py` on the new format — early-stage visualizer, broken since the typed refactor (`0b67de5`), low priority; revisit only if it still matters.
- [7] Remove deprecated JSONL path entirely (`--jsonl` flag, `to_jsonl`/`from_jsonl`, JSONL tests) — requires [2] and [3] migrated first.
- [8] Godot visualization upgrade: line-level star layout (PCA-2D or 3D slice of the 128-dim line embeddings) instead of word-level line-0-only.

## To Do

- [17] Dim-reduction stage renaming: `dimension_reduction.py` should apply the `d<N>` tag rename (d128→d32) to output filenames itself — done manually in `5e5cf8f`.
- [1] Dim-hunt stage: dimension analysis (near-constant dims, redundant pairs, spread/offset ranking) over `PoemEmbeddings.load()` output — the unprocessed → analyzed pipeline step.
- [3] Regenerate godot `data/sample*.json` from `poem_emb/eg2_d128_wild-geese_mary-oliver.json` (+ dim-analysis output); define godot schema together with `spheres.gd` migration (still reads legacy `embedding_dict`).

## In Progress



## Done

- [16] New poems (10) + `dimension_reduction.py` step registry (center/abtt/pca); d32 godot data set — `6beb2b5`, `5e5cf8f`.
- [4] Authorship metadata via per-poem YAML frontmatter — `parse_frontmatter()`/`make_metadata()` in `api_gemma.py`, `poem_texts` strips frontmatter (`14125de`); all `poem_emb/` data regenerated with author/title — `6b7af2c`, `5e5cf8f`.
- [15] Fix `Metadata.from_dict` title bug (copied author) + flatten `procedures`; regenerate data — `486620f`, `7b8ba43`.
- [14] Erase scaffold classes `Poem`/`PoemVerse`/`PoemLine`/`Embedding`; `poem_texts` parses `.md` directly (clean verse/poem texts) — `67004c2`.
- [13] Remove deprecated `LinewiseEmbeddingPerWord` + orphaned `helpers.py` — `667a6c2`.
- [12] Sever legacy consumers ahead of refactor (`dim_hunt_app.py`, `data.py` demo) — `6d883c7`.
- [11] Typed refactor: `WordEmb`/`LineEmb`/`VerseEmb`/`PoemEmb` dataclasses, `PoemEmbeddings.load`/`save`, byte-identity gate — `4afc166`, `1a7c04a`.
- [10] JSON becomes the standard single-file format; JSONL behind default-false flag — `0b13de8` (`json-single-file` branch).
- [9] Wild Geese embeddings at word/line/verse/poem levels, one file per poem — `a30fde6`.
