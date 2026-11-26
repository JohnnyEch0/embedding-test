# KANBAN — embedding-test

Protocol:
- A card moves column in the same commit that changes its state.
- Starting a task → card to **In Progress**; the completion commit flips it to **Done** with its hash.
- Card numbers are assigned once and never re-used. Next free number: **30**.
- Cards carry branch/commit refs where they exist.
- Within a column, cards are grouped by project stage: **a)** Getting Embeddings and Datastructure, **b)** Finding Semantically meaningful Dimensions, **c)** Godot Demonstrator.

## Backlog

### a) Getting Embeddings and Datastructure

- [2] Decide fate of `dim_hunt_app.py`: no data source (legacy JSONL loader removed, `PoemEmbeddings.load()` loader unimplemented — raises `NotImplementedError`). Rebuild on the new format or delete; also gates card [7]. Low priority; revisit only if it still matters.
- [7] Remove deprecated JSONL path entirely (`--jsonl` flag, `to_jsonl`/`from_jsonl`, JSONL tests) — requires [2] decided first ([3] done).

### b) Finding Semantically meaningful Dimensions

- [17] Dim-reduction stage renaming: `dimension_reduction.py` should apply the `d<N>` tag rename (d128→d32) to output filenames itself — done manually in `5e5cf8f`.
- [1] Dim-hunt stage: dimension analysis (near-constant dims, redundant pairs, spread/offset ranking) over `PoemEmbeddings.load()` output — the unprocessed → analyzed pipeline step.

### c) Godot Demonstrator

- [27] Concrete alternate view (placeholder): first real "completely different way to view the app". Undefined until it exists; defines the actual requirements [26] designs against. No speculative abstraction before this.
- [26] Input→action remap / app-configuration exploration: decouple keys from fixed semantic actions so the same key can mean different things per view; `ViewSetting` (look) + mappings converge into one app-configuration object. Exploration only — no interface design before the first concrete alternate view exists. Blocked by [27].
- [25] Automation with a multi-line set idles: no auto-collapse, no rebuild — orbit keeps rotating, warning fires per completed rotation (decide once-vs-every-time during implementation). No code beyond [23]+[24] wiring; card documents the decided behavior. Depends on [24].
- [24] Multi-line step semantics: `step()` on a multi-element set no-ops with `push_warning` instead of collapsing (behavior change, [23] first); single-element set steps with wrap as today. Preserves the startup `[0..7]` multi-line display. Depends on [23].
- [23] Extract line-selection state from `main.gd` into `godot/line_selector.gd` (name TBD): owns `lines: Array[int]` (set semantics, not cursor) + `step()` + `changed(Array[int])` signal; `InputHandler.next_line_requested` and `AutoOrbit.rotation_completed` both wire to `step()`; `main.gd` wiring-only. Behavior-preserving relocation of the current collapse logic. Headless test `test_line_selector.gd`. Completes the model/input/view split alongside [18]/[20]/[22].
- [21] DimMap direction enum: replace bare ±1 ints on `advance_window`/`advance_axis` and InputHandler's dim signals with a named const/enum pair (PR #2 review, primitive obsession). Unknown-axis behavior now unified: `get_dim` warns once (was silent 0).
- [8] Godot visualization upgrade: line-level star layout (PCA-2D or 3D slice of the 128-dim line embeddings) instead of word-level line-0-only.

## To Do

_(empty)_

## In Progress

_(empty)_

## Done

### a) Getting Embeddings and Datastructure

- [16] New poems (10) + `dimension_reduction.py` step registry (center/abtt/pca); d32 godot data set — `6beb2b5`, `5e5cf8f`.
- [4] Authorship metadata via per-poem YAML frontmatter — `parse_frontmatter()`/`make_metadata()` in `api_gemma.py`, `poem_texts` strips frontmatter (`14125de`); all `poem_emb/` data regenerated with author/title — `6b7af2c`, `5e5cf8f`.
- [15] Fix `Metadata.from_dict` title bug (copied author) + flatten `procedures`; regenerate data — `486620f`, `7b8ba43`.
- [14] Erase scaffold classes `Poem`/`PoemVerse`/`PoemLine`/`Embedding`; `poem_texts` parses `.md` directly (clean verse/poem texts) — `67004c2`.
- [13] Remove deprecated `LinewiseEmbeddingPerWord` + orphaned `helpers.py` — `667a6c2`.
- [12] Sever legacy consumers ahead of refactor (`dim_hunt_app.py`, `data.py` demo) — `6d883c7`.
- [11] Typed refactor: `WordEmb`/`LineEmb`/`VerseEmb`/`PoemEmb` dataclasses, `PoemEmbeddings.load`/`save`, byte-identity gate — `4afc166`, `1a7c04a`.
- [10] JSON becomes the standard single-file format; JSONL behind default-false flag — `0b13de8` (`json-single-file` branch).
- [9] Wild Geese embeddings at word/line/verse/poem levels, one file per poem — `a30fde6`.

### b) Finding Semantically meaningful Dimensions

_(none yet — [1] and [17] still open in Backlog)_

### c) Godot Demonstrator

- [29] Godot project restructure (branch `godot-structure-refactor`): flat `godot/` layout into feature dirs — `app/` (main), `stars/` (spheres, emb_star, space.gdshader), `dims/` (dim_map, input_handler, dims_hud, controls_label), `camera/` (camera_rig, auto_orbit), `intro/` (intro mother + intro_scene merged with existing subscenes), `tests/` (test_*.gd); `resources/`, `data/` unchanged. Unused `scripts/view_settings.gd` deleted. All `res://` refs + `project.godot` main scene updated; `.uid` files moved with their scripts (uids stable). No behavior change; headless tests + clean boot green — `3d7e52c`.
- [28] Intro mother scene (branch `xx_startup_scene_2`): `intro.tscn` (`Intro`) owns the app's single camera + environment/sky, plays handcrafted `IntroScene` children in order (title fades, labelled stars, camera glide), resets the camera pose per child, fades out, then error-checks the switch to `main.tscn` (failure stays on intro, fade reset); `skip_step` (Space) / `skip_all` (Esc) actions; headless test `godot/test_intro.gd`; project main scene now `intro.tscn` — `2b7eb28`, `74c585b`, `eff258e`, `7637163`, `5855f5a`, `4de287a`; fix round: star lines join in order (`4df5a53`), failed scene switch re-arms the intro (`53910ff`), deferred play blocked after finish (`dcea41f`), smoke test covering the real child scenes (`dfc4928`); fix round 2: stars reuse EmbStar — fixed-size labels readable at glide distance (`35481ad`), camera glide looks into the star cluster (`3bb7f75`), tween-kill skip hoisted into the `IntroScene` base (`c118a54`).
- [22] Extract `DimsHud` node (`godot/dims_hud.gd`) from main.gd: bound observer of `DimMap` (`bind()` tracks `changed`), layout/font moved to main.tscn, headless test `test_dims_hud.gd`, main.gd wiring-only — `d639f74`, `480225b`.
- [20] Extract `InputHandler` node (`godot/input_handler.gd`) from `main.gd`: raw input → semantic signals (`next_line_requested`, `dims_window_requested(dir)`, `dim_axis_requested(axis, dir)`, `automation_toggled`, `user_input_detected`, `debug_toggled`); `main.gd` only connects — `ea7c179`.
- [18] Manual dimension switching: `DimMap` (godot/dim_map.gd) X/Y/Z mapping, R = next 3 dims, F/G/H = per-axis (+shift reverse), distinct-skip (export `enforce_distinct`, default on), dims HUD, headless test (godot/test_dim_map.gd) — `e8b1c31`, `5e827e4`, `79ec0a2`, `77e6e8b`.
- [3] Godot schema = `PoemEmbeddings` JSON (data.py); `spheres.gd` migrated off legacy `embedding_dict`; godot data regenerated as `eg2_d32_*.json` — `1bf149f`, `5e5cf8f`. (Dim-analysis output split off to [1].)
