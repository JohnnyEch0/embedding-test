---
type: Decision
title: ADR-0005 Godot model/input/view split
description: DimMap (pure state) and InputHandler (semantic signals) extracted from main.gd so the core is headless-testable.
tags: [decisions, godot, refactor, architecture]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T14:00:35Z }
sources:
  - id: dimmapgd
    resource: godot/dims/dim_map.gd
    title: dims/dim_map.gd
    last_modified: 2026-11-24
  - id: inputhandlergd
    resource: godot/dims/input_handler.gd
    title: dims/input_handler.gd
    last_modified: 2026-11-24
  - id: kanban
    resource: KANBAN.md
    title: KANBAN.md (cards 18, 20, 22)
    last_modified: 2026-11-24
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# ADR-0005: Godot model/input/view split

**Date**: 2026-11-23 (card [18]); 2026-11-24 (card [20]); 2026-11-24 (card [22])
**Status**: Accepted
**Commits**: `5e827e4`, `79ec0a2`, `77e6e8b`, `e8b1c31` (DimMap, card [18]); `ea7c179`, `937b924`, `1e9dc47`, `7eef1be`, `c8242df` (InputHandler, card [20]); `d639f74`, `480225b` (DimsHud, card [22])

## Context

Manual dimension switching (card [18]) landed in `main.gd`, which already
mixed input dispatch, application state, HUD building, and star rebuilding.
Input semantics (especially `Shift`-modified reverse actions) needed tests
that cannot run with a scene tree.

## Decision

Split by responsibility:

- **`DimMap`** — pure `RefCounted` state for the X/Y/Z mapping
  (`advance_window`, `advance_axis`, `changed`-only-on-real-change),
  headless-testable.
- **`InputHandler`** — `Node` translating raw events into semantic signals
  (`next_line_requested`, `dims_window_requested(dir)`,
  `dim_axis_requested(axis, dir)`, `automation_toggled`,
  `user_input_detected`, `debug_toggled`); no scene knowledge.
- **`app/main.gd`** — wiring only: connect signals, own app state, rebuild.

## Consequences

- Dispatch bugs became testable headlessly; the `Shift+R`/`Shift+F/G/H`
  loose-match bug was found and fixed via `exact_match` (`1e9dc47`).
- User input terminates dispatch (a takeover event never also advances a
  line or toggles a debug overlay).
- - **`DimsHud`** — `Label` on `CanvasLayer` in `app/main.tscn` (`dims/dims_hud.gd`),
  a bound observer of `DimMap` (`bind()` tracks `changed`); layout lives in
  the scene. Completed the split on 2026-11-24 (card [22], `d639f74` /
  `480225b`) with headless test `test_dims_hud.gd`.
- Card [21] (direction enum for ±1 ints) and card [19] (startup call
  cleanup) are follow-ups from the same review.

## Related

- [DimMap](/godot/dim-map.md)
- [Godot architecture](/godot/architecture.md)
- [Headless testing](/godot/headless-testing.md)
