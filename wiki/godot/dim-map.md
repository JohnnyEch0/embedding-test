---
type: Component
title: DimMap — X/Y/Z Dimension Mapping
description: Pure state for which embedding dimension is displayed on each spatial axis, with window and per-axis advance semantics.
tags: [godot, dim-map, dimension-mapping, state]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T14:00:35Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: dimmapgd
    resource: godot/dim_map.gd
    title: dim_map.gd (DimMap source)
    last_modified: 2026-11-24
  - id: inputmap
    resource: godot/project.godot
    title: project.godot (dim_* input actions)
    last_modified: 2026-11-24
  - id: dimshudgd
    resource: godot/dims_hud.gd
    title: dims_hud.gd (DimsHud bound observer)
    last_modified: 2026-11-24
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# DimMap

`DimMap` (godot/dim_map.gd) is a pure `RefCounted` — no scene, mesh, or input
knowledge. `main.gd` feeds it keypresses via `InputHandler` signals;
`spheres.gd` consumes the mapping. This is what makes the switching logic
headless-testable (see [Headless testing](/godot/headless-testing.md)).

## State

- `dim_count` — total embedding dimensions, clamped ≥ 1.
- `enforce_distinct` — no dimension on two axes, where possible (default on;
  exported on `Main`).
- `_dims` — `{x, y, z}` → dimension index. Degenerate counts collapse:
  d=2 → 0/1/1, d=1 → 0/0/0.[^dimmapgd]

## Two switching modes

| Operation | Key | Semantics |
|-----------|-----|-----------|
| `advance_window(dir)` | `R` / `Shift+R` | shifts **all** axes by ±3 — jump to next/previous trio. Pure translation mod `dim_count`, so it preserves existing distinctness |
| `advance_axis(axis, dir)` | `F`/`G`/`H` (X/Y/Z), `Shift` = reverse | steps **one** axis, skipping dimensions held by the other axes while `enforce_distinct` is on, wrapping around. If no distinct slot exists (d ≤ 3 with a distinct mapping) it degrades to a plain step and accepts a duplicate rather than deadlocking |

## Signal contract

`changed` emits exactly once per actual state change. Identity wraps (a full
cycle at d=3, any move at d=1) emit nothing — no signal, no star rebuild, no
orbit refit downstream. Readers (`get_dim`, `mapping()`, `axes_vector()`)
never emit. `get_dim` on an unknown axis warns once and returns 0 — same
policy as `advance_axis`, which is a warned no-op.[^dimmapgd]

## Keymap notes

The `dim_*`/`next_dims`/`prev_dims` actions are dispatched with
`exact_match` in `InputHandler`: without it, `Shift+R` loosely matches
`next_dims` (checked first) and the reverse actions are unreachable. That bug
was fixed in `1e9dc47`.[^inputmap]

HUD readout: `DimsHud` (`godot/dims_hud.gd`, a `Label` in `main.tscn`) is a
bound observer — `bind(map)` renders `dims  X:%d  Y:%d  Z:%d  (of %d)` and
tracks `changed`; identity wraps are silent upstream, so no spurious
refreshes.[^dimshudgd]

## Related

- [Architecture](/godot/architecture.md) — where DimMap sits
- [Headless testing](/godot/headless-testing.md) — `test_dim_map.gd`

[^dimmapgd]: godot/dim_map.gd (read during 2026-11-24 bundle rebuild)
[^inputmap]: godot/project.godot + godot/input_handler.gd (read during 2026-11-24 bundle rebuild)
[^dimshudgd]: godot/dims_hud.gd (read during 2026-11-24 bundle rebuild)
