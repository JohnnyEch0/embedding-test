---
type: Application Architecture
title: Godot App Architecture
description: Node graph and model/input/view split of the star visualization (main.tscn, Spheres, DimMap, InputHandler, AutoOrbit).
tags: [godot, architecture, visualization, scene-graph]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-25T15:31:25Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: maingd
    resource: godot/main.gd
    title: main.gd (wiring + app state)
    last_modified: 2026-11-24
  - id: dimshudgd
    resource: godot/dims_hud.gd
    title: dims_hud.gd (DimsHud label)
    last_modified: 2026-11-24
  - id: spheresgd
    resource: godot/spheres.gd
    title: spheres.gd (data load + star spawning)
    last_modified: 2026-11-24
  - id: projectgodot
    resource: godot/project.godot
    title: project.godot (input map, main scene)
    last_modified: 2026-11-24
  - id: a5
    resource: /decisions/adr-0005-godot-model-input-view-split.md
    title: ADR-0005 Model/input/view split
usage_window: { from: 2026-11-24, to: 2026-11-25 }
---

# Godot App Architecture

Godot 4.7 project (`godot/`), main scene `main.tscn`. Data lives in
`godot/data/` (`res://data`) as [Poem-Embeddings JSON](/data-format.md) —
see [ADR-0004](/decisions/adr-0004-godot-data-poem-embeddings.md).

The app follows a **model / input / view** split (ADR-0005):

| Node / class | File | Responsibility |
|--------------|------|----------------|
| `Main` | `main.gd` | Wiring only: connects signals, owns app state (`cur_line`, `automation`, `show_*` flags), rebuilds stars |
| `Spheres` | `spheres.gd` | Data loading, star spawning, dimension projection, debug overlay registry, cluster metrics |
| `DimMap` | `dim_map.gd` | **Model** — pure `RefCounted` state for the X/Y/Z dimension mapping; no scene refs (see [DimMap](/godot/dim-map.md)) |
| `InputHandler` | `input_handler.gd` | **Input** — raw events → semantic signals; no scene knowledge |
| `AutoOrbit` | `auto_orbit.gd` | Camera orbit automation; `fit(box, cone)` on rebuild, `rotation_completed` → next line |
| `CharacterBody3D` | `camera_rig.gd` | Manual WASD/space/shift flight; `manual` mirrors `!automation` |
| `EmbStar` | `emb_star.tscn` / `emb_star.gd` | One star: `MeshInstance3D` + `Label3D` |
| `DimsHud` | `dims_hud.gd` | **View** — `Label` on `CanvasLayer` in `main.tscn`; bound observer of `DimMap` (`bind()` tracks `changed`), renders `dims X:.. Y:.. Z:.. (of ..)`; layout lives in the scene |
| `DevConsole` | `dev_console.gd` | **View + applier** — in-game console (toggle: `^` key / `toggle_console` action) that live-tunes star material, per-star `OmniLight3D`, environment glow/fog, camera, and the Forward+ cluster limit; model is `StarSettings` (`star_settings.gd`); `export` command hands off values to bake into the scenes. See [Dev Console](/godot/dev-console.md) |

## Startup sequence

1. `Spheres._ready` — `_read_json()` via `_resolve_path()`: the
   `default_filename` export if set and present, else a **random** file from
   `res://data`. Reads `metadata`, `lines`, `verses`, `poem`; `dim_count`
   comes from `metadata.dimensions` (fallback: first word embedding size).
2. `Main._ready` — connects `orbit.rotation_completed → _advance_line` and
   `stars.stars_rebuilt → orbit.fit`; sets automation; `_rebuild()`;
   `_setup_dim_map()`; `_setup_input()`.
3. **Dim handshake** — `Main` asserts `stars.dim_count > 3` before building
   the `DimMap`, then binds the `DimsHud`: a failed data load would leave
   `dim_count` at its default 3
   and every mapping would be a lie. The assert is a wiring invariant, not
   data validation.[^maingd]

## Rebuild flow

`_rebuild()` → `Spheres.create_stars_from_data(cur_line, [], show_poem,
show_line, show_verse)` → word stars for the current line (plus optional
line/verse/poem stars; verse/line/poem get `KIND_STYLE` — orange ×2 / magenta
×5 / white ×8) → `stars_rebuilt(box, cone)` → `orbit.fit`. `cur_line` starts
as `[0..7]` (intentional startup line set, not debt — KANBAN card [19]).
[^maingd]

## Debug overlays

`Spheres` keeps a `debug_nodes` registry keyed by `StringName`; the
convention is that every key must have a same-named InputMap action
(`Ctrl+1..6`, `Ctrl+Q`), otherwise `register_debug` warns once. `Main`
dispatches `debug_toggled` from `InputHandler`; hidden by default, state
survives rebuilds. Keys: `word_connections`, `word_to_origin`,
`sentence_bounds_box`, `sentence_cone`, `labels`, `line_stars`,
`verse_stars`, `poem_stars`, `debug_hide_ctrl_label`.[^spheresgd]

## Projection and mismatch handling

Stars are placed at `embedding[dim_axes.x/y/z] * 1000` (SCALE), where
`dim_axes` is set from `DimMap.axes_vector()`. If an embedding's size
disagrees with `metadata.dimensions`, indices are clamped and one warning is
emitted per rebuild.[^spheresgd]

## In flight

- **View Settings** (`ViewSetting` type) — work started 2026-11-23, `main.gd`
  carries a commented `normal_look` export ("will be added later").[^maingd]

## Related

- [DimMap](/godot/dim-map.md) — mapping semantics and keymap
- [Dev Console](/godot/dev-console.md) — in-game star/light/glow/camera tuning
- [Headless testing](/godot/headless-testing.md)
- [Data format](/data-format.md)

[^maingd]: godot/main.gd (read during 2026-11-24 bundle rebuild)
[^spheresgd]: godot/spheres.gd (read during 2026-11-24 bundle rebuild)
