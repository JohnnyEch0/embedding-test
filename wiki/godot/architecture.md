---
type: Application Architecture
title: Godot App Architecture
description: Entry via the intro mother scene (intro.tscn), then the node graph and model/input/view split of the star visualization (main.tscn, Spheres, DimMap, InputHandler, AutoOrbit).
tags: [godot, architecture, visualization, scene-graph]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-26T10:25:24Z }
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
    last_modified: 2026-11-26
  - id: projectgodot
    resource: godot/project.godot
    title: project.godot (input map, main scene)
    last_modified: 2026-11-25
  - id: introgd
    resource: godot/intro.gd
    title: "intro.gd (intro mother: child sequence, skip, guarded switch)"
    last_modified: 2026-11-25
  - id: a5
    resource: /decisions/adr-0005-godot-model-input-view-split.md
    title: ADR-0005 Model/input/view split
usage_window: { from: 2026-11-24, to: 2026-11-26 }
---

# Godot App Architecture

Godot 4.7 project (`godot/`), main scene `intro.tscn` (the intro mother
scene), which plays its intro children in order, fades out, and switches
to `main.tscn` — the star visualization below. Data lives in `godot/data/`
(`res://data`) as [Poem-Embeddings JSON](/data-format.md) — see
[ADR-0004](/decisions/adr-0004-godot-data-poem-embeddings.md).

The app follows a **model / input / view** split (ADR-0005):

| Node / class | File | Responsibility |
|--------------|------|----------------|
| `Intro` / `IntroScene` | `intro.gd` / `intro_scene.gd` | **Entry** — the intro mother plays `IntroScene` children in order, then fades and switches to `main.tscn` (see [Intro mother scene](/godot/intro-scene.md)) |
| `Main` | `main.gd` | Wiring only: connects signals, owns app state (`cur_line`, `automation`, `show_*` flags), rebuilds stars |
| `Spheres` | `spheres.gd` | Data loading, star spawning, dimension projection, debug overlay registry, cluster metrics |
| `DimMap` | `dim_map.gd` | **Model** — pure `RefCounted` state for the X/Y/Z dimension mapping; no scene refs (see [DimMap](/godot/dim-map.md)) |
| `InputHandler` | `input_handler.gd` | **Input** — raw events → semantic signals; no scene knowledge |
| `AutoOrbit` | `auto_orbit.gd` | Camera orbit automation; `fit(box, cone)` on rebuild, `rotation_completed` → next line |
| `CharacterBody3D` | `camera_rig.gd` | Manual WASD/space/shift flight; `manual` mirrors `!automation` |
| `EmbStar` | `emb_star.tscn` / `emb_star.gd` | One star: `MeshInstance3D` + `Label3D` |
| `DimsHud` | `dims_hud.gd` | **View** — `Label` on `CanvasLayer` in `main.tscn`; bound observer of `DimMap` (`bind()` tracks `changed`), renders `dims X:.. Y:.. Z:.. (of ..)`; layout lives in the scene |

## Startup sequence

**1. Intro** (`run/main_scene = res://intro.tscn`). `Intro._ready` →
`_play(0)`: frees the previous child, resets the camera pose, instantiates
the next configured child (must be an `IntroScene` — otherwise error +
skip), injects the mother's camera, connects `finished` one-shot, and calls
`start()`. When the last child finishes, the mother fades out and runs
`change_scene_to_file(res://main.tscn)`; a failed switch stays on the intro
and re-arms (Esc / child skip can finish again). `skip_step` (Space) skips
the current child, `skip_all` (Esc) jumps straight to the fade. Full detail
in [Intro mother scene](/godot/intro-scene.md).[^introgd]

**2. Main scene.** Once `main.tscn` is up:

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

- [Intro mother scene](/godot/intro-scene.md) — entry scene, child contract, skip/exit behavior
- [DimMap](/godot/dim-map.md) — mapping semantics and keymap
- [Headless testing](/godot/headless-testing.md)
- [Data format](/data-format.md)

[^maingd]: godot/main.gd (read during 2026-11-24 bundle rebuild)
[^spheresgd]: godot/spheres.gd (read during 2026-11-24 bundle rebuild)
[^introgd]: godot/intro.gd (read 2026-11-26)
