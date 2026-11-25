---
type: Testing Convention
title: Headless Godot Testing
description: GDScript SceneTree unit tests run via godot --headless -s, plus the pytest suite for the Python pipeline.
tags: [testing, godot, headless, pytest]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-25T15:31:25Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: testdimmap
    resource: godot/test_dim_map.gd
    title: test_dim_map.gd (DimMap tests)
    last_modified: 2026-11-24
  - id: testinput
    resource: godot/test_input_handler.gd
    title: test_input_handler.gd (InputHandler dispatch tests)
    last_modified: 2026-11-24
  - id: testdimshud
    resource: godot/test_dims_hud.gd
    title: test_dims_hud.gd (DimsHud bind/refresh tests)
    last_modified: 2026-11-24
  - id: testconsole
    resource: godot/test_dev_console.gd
    title: test_dev_console.gd (headless console/applier tests)
    last_modified: 2026-11-25
usage_window: { from: 2026-11-24, to: 2026-11-25 }
---

# Headless Godot Testing

The Godot side is tested without the editor or a display. See
[Run tests](/runbooks/run-tests.md) for commands.

## Pattern

Tests `extend SceneTree`, `preload` the script under test, drive it with
synthetic inputs (for `InputHandler`, real `InputEvent`s dispatched against
the project's loaded InputMap), count checks, print one `FAIL:` line per
failure plus a summary. **Exit code 0 = all pass, 1 = at least one
failure.** Run from `godot/`: `godot --headless -s test_<unit>.gd`.

## Coverage

| Test file | Covers |
|-----------|--------|
| `test_dim_map.gd` | defaults; window advance; axis advance with distinct-skip; duplicates allowed when `enforce_distinct` off; degenerate dim counts (d=1, d=2 collapse); unknown axis is a warned no-op; identity wraps emit nothing; `changed` signal contract |
| `test_input_handler.gd` | `next_line`; dim windows incl. `Shift+R` exact-match dispatch; per-axis typed dispatch; user-input-terminates-dispatch (movement keys and mouse motion) |
| `test_dims_hud.gd` | the full `bind → advance → refresh` path: the HUD text mirrors the `DimMap` mapping after window/axis advances (a `Label` works headless — no rendering, just state) |
| `test_star_settings.gd` | `StarSettings` (dev-console model): registry completeness, harvested/adopted defaults, set/get round-trip, clamping, type & parse rejection (bool/color/enum), relative float adjusts, reset, `changed` contract, `to_dict` (colors as hex, enums as names) |
| `test_dev_console.gd` | commands through `_execute()` (incl. unknown-key/command and bad-value error paths); applier against synthetic `Environment` / `Camera3D` / `MeshInstance3D` + `OmniLight3D` nodes (material, lights, camera, env); rebuild re-apply incl. late stars; one-shot light-default harvest; `export` JSON written to `user://`; open/close + bound-key path |

Not covered headless (documented in the test files): `exit` (quitting would
end the runner) and `toggle_automation` (no InputMap action exists — dead
branch); both need manual/editor coverage.[^testinput] The dev console's
visual effect and the `LineEdit` focus/history interaction are manual as
well (run the game, press `^`).[^testconsole]

## Python side

`pytest` over the pipeline: `test_api_gemma.py` (CLI arg parsing, md parsing,
frontmatter, pure embedding-attach helpers) and `test_data.py`
(round-trip + byte-identity gate). Note `test_api_gemma.py` imports
`api_gemma`, which imports `auth` — an API key file must exist, see the
runbook.[^testdimmap]

## Related

- [DimMap](/godot/dim-map.md) — the primary tested unit
- [Run tests](/runbooks/run-tests.md)

[^testdimmap]: godot/test_dim_map.gd, godot/test_input_handler.gd, test_*.py (read during 2026-11-24 bundle rebuild)
[^testinput]: godot/test_input_handler.gd (read during 2026-11-24 bundle rebuild)
[^testconsole]: godot/test_dev_console.gd (2026-11-25 dev-console work)
