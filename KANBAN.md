# KANBAN — embedding-test

Protocol:
- A card moves column in the same commit that changes its state.
- Starting a task → card to **In Progress**; the completion commit flips it to **Done** with its hash.
- Card numbers are assigned once and never re-used. Next free number: **16**.
- Cards carry branch/commit refs where they exist.

## Backlog

- [7] Remove deprecated JSONL path entirely (`--jsonl` flag, `to_jsonl`/`from_jsonl`, JSONL tests) — requires [2] and [3] migrated first.
- [8] Godot visualization upgrade: line-level star layout (PCA-2D or 3D slice of the 128-dim line embeddings) instead of word-level line-0-only.

## To Do

- [1] Dim-hunt stage: dimension analysis (near-constant dims, redundant pairs, spread/offset ranking) over `PoemEmbeddings.load()` output — the unprocessed → analyzed pipeline step.
- [2] Rebuild `dim_hunt_app.py` on the new format — merged with `dim_hunt_data.py`, JSONL load removed, crashes at startup by design (`0b67de5`); remaining: `PoemEmbeddings.load()`-based loader, token matrix, callbacks, `app.run()`.
- [3] Regenerate godot `data/sample*.json` from `poem_emb/eg2_d128_wild-geese_mary-oliver.json` (+ dim-analysis output); define godot schema together with `spheres.gd` migration (still reads legacy `embedding_dict`).
- [4] Authorship metadata: `--author/--title` flags or per-poem manifest — headers currently carry `author: null`, `title` = filename stem.

## In Progress



## Done

- [15] Fix `Metadata.from_dict` title bug (copied author) + flatten `procedures`; regenerate data — `486620f`, `7b8ba43`.
- [14] Erase scaffold classes `Poem`/`PoemVerse`/`PoemLine`/`Embedding`; `poem_texts` parses `.md` directly (clean verse/poem texts) — `67004c2`.
- [13] Remove deprecated `LinewiseEmbeddingPerWord` + orphaned `helpers.py` — `667a6c2`.
- [12] Sever legacy consumers ahead of refactor (`dim_hunt_app.py`, `data.py` demo) — `6d883c7`.
- [11] Typed refactor: `WordEmb`/`LineEmb`/`VerseEmb`/`PoemEmb` dataclasses, `PoemEmbeddings.load`/`save`, byte-identity gate — `4afc166`, `1a7c04a`.
- [10] JSON becomes the standard single-file format; JSONL behind default-false flag — `0b13de8` (`json-single-file` branch).
- [9] Wild Geese embeddings at word/line/verse/poem levels, one file per poem — `a30fde6`.
