---
type: Application Feature
title: Dev Console (Star/Light Tuning)
description: In-game console (^ key) that live-tunes star material, per-star OmniLight3D, WorldEnvironment glow/fog, camera, and the Forward+ cluster limit; exports the chosen values as JSON.
tags: [godot, dev-console, rendering, star, light, tuning]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-25T15:31:25Z }
stale_after: 2027-02-25T00:00:00Z
sources:
  - id: devconsolegd
    resource: godot/dev_console.gd
    title: dev_console.gd (UI, input isolation, applier)
    last_modified: 2026-11-25
  - id: starsgd
    resource: godot/star_settings.gd
    title: star_settings.gd (StarSettings model)
    last_modified: 2026-11-25
  - id: testconsole
    resource: godot/test_dev_console.gd
    title: test_dev_console.gd (headless console/applier tests)
    last_modified: 2026-11-25
usage_window: { from: 2026-11-25, to: 2026-11-25 }
---

# Dev Console (Star/Light Tuning)

A Quake-style drop-down console for tuning what the stars look like and how
they light the scene, without editor round-trips. Opened with the
`toggle_console` action and closed with the same key or Esc.

## Why

An `OmniLight3D` only illuminates nearby geometry — a star is *seen* as an
emissive mesh, and its halo comes from WorldEnvironment glow. The look is a
joint function of the star material, the per-star light, the environment, and
the camera, so tuning needs one place to fiddle with all of them live. The
console applies every change immediately and survives star rebuilds.

## Nodes

| Node / class | File | Role |
|---|---|---|
| `StarSettings` | `star_settings.gd` | **Model** (pure `RefCounted`, like `DimMap`): registry of 28 settings with type/range/help, defaults, current values, string parsing, clamping, `changed` signal |
| `DevConsole` | `dev_console.gd` | **View + applier** (`CanvasLayer` in `main.tscn`): builds its own UI (log + `LineEdit`), harvests defaults from the live scene, applies values to `WorldEnvironment` / `Camera3D` / stars, commands |

`Spheres`, `main.gd`, and `InputHandler` are untouched — the console is a
CanvasLayer wired via exported NodePaths.

## Key binding

`toggle_console` in `project.godot` (two physical events, layout-proof):

- physical key **left of "1"** (US `` ` `` / DE `°`), any shift state
- physical **7 + Shift** (German `^`, US `&`)

Rebind in Project Settings → Input Map if needed.

## Open/close behavior

- `_input` catches the toggle before the GUI, so it works while the
  `LineEdit` has focus and the key is never typed into the console.
- While open: mouse released, `player.manual = false`, and
  `_shortcut_input` swallows everything the console did not claim — the game
  input (`InputHandler`, `CharacterBody3D`) is dead, but `AutoOrbit` is
  `_process`-driven and keeps orbiting, so the scene stays alive.
- Command history: Up/Down in the `LineEdit`; log capped at 200 lines.

## Commands

| Command | Behavior |
|---|---|
| `help [command]` | command list / detail |
| `list [prefix]` | settings with current + default value (`*` = changed); prefix by key prefix or group: `star` / `env` / `camera` / `project` |
| `get <key>` | value, default, range/options, help |
| `set <key> <value>` | apply; floats accept relative `+0.5` / `-0.5`; colors `#rrggbb(aa)` or `Color(r, g, b[, a])`; bools `true/false/1/0/on/off`; enums by name |
| `reset [key\|all]` | back to the defaults harvested from the scene at startup |
| `export [path]` | write all values as JSON (default `user://star_settings.json`) and print it; colors as hex, enums as names |
| `clear` | clear the log |

No persistence across runs by design: the repo always starts from the
committed scene defaults; `export` is the hand-off to bake values into
`emb_star.tscn` / `main.tscn` / `project.godot`.

## Settings (28)

- **star** (mesh, uniform for all stars): `star_emission_energy`
  (`emission_energy_multiplier`, the HDR glow source — 4–8 is a good star
  range), `star_unshaded`, `star_size_scale` (multiplies every star's scale,
  incl. line/verse/poem), `star_visibility_range_end` (0 = off),
  `star_lights_enabled` (master switch for the per-star lights),
  `light_energy`, `light_color`, `omni_range` (hard cutoff),
  `omni_attenuation`, `light_specular`, `light_indirect_energy`,
  `shadow_enabled`, `distance_fade_enabled`, `distance_fade_begin`,
  `distance_fade_length`
- **env** (`WorldEnvironment`): `glow_enabled`, `glow_intensity`,
  `glow_strength`, `glow_bloom`, `glow_hdr_threshold`, `glow_blend_mode`
  (additive/screen/softlight/replace), `background_energy`,
  `volumetric_fog_enabled`, `volumetric_fog_density`
- **camera**: `camera_far` (engine default 4000 — raise to reach the stars,
  and raise `camera_near` as far grows for depth precision), `camera_near`,
  `camera_fov`
- **project**: `max_clustered_elements` (Forward+ cluster cap; in-memory
  only — the console says so; bake into `project.godot [rendering]` and
  restart)

Defaults: registry constants mirror the committed scene; the console also
**harvests** live values at startup (environment + camera) and adopts the
per-star light defaults from the **first spawned star** (`adopt_default`),
so `reset all` is always "the scene's current committed look".

## Apply mechanics (rebuild-proof)

- `changed(key)` → apply that key immediately.
- `stars_rebuilt` → re-apply all `star`-group keys `call_deferred` — the
  signal fires inside `create_stars_from_data` **before** the line/verse/poem
  extras are spawned, so the deferred pass covers them.
- Star material: applied on the star's **active** material — word stars use
  the packed scene's shared material (future instantiations inherit the
  tuned values), line/verse/poem stars their per-star `material_override`.
- `star_size_scale` keeps a per-star base scale in the `console_base_scale`
  meta so repeated applies multiply the base, not the current scale.
- `emb_star.tscn` sets `cast_shadow = 0` on the star mesh (stars must not
  cast shadows).

## Testing

`test_star_settings.gd` (registry, harvest/adopt, set/reset, parsing,
clamping, relative adjusts, `changed`, `to_dict`) and `test_dev_console.gd`
(constructed off-tree via the public `setup()`; commands through `_execute()`,
applier checked against synthetic `Environment` / `Camera3D` / `MeshInstance3D`
+ `OmniLight3D` nodes, rebuild re-apply, one-shot light harvest, export JSON,
toggle incl. the bound-key path). Not covered headless: visual result,
`LineEdit` focus/history interaction — manual verification (run the game,
press `^`).

## Related

- [Architecture](architecture.md)
- [Headless testing](headless-testing.md)

[^devconsolegd]: godot/dev_console.gd (read during the 2026-11-25 dev-console work)
[^starsgd]: godot/star_settings.gd (read during the 2026-11-25 dev-console work)
[^testconsole]: godot/test_dev_console.gd (read during the 2026-11-25 dev-console work)
