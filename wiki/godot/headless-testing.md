---
type: Testing Convention
title: Headless Godot Testing
description: GDScript SceneTree unit tests run via godot --headless -s, plus the pytest suite for the Python pipeline.
tags: [testing, godot, headless, pytest]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-26T10:26:06Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: testdimmap
    resource: godot/tests/test_dim_map.gd
    title: test_dim_map.gd (DimMap tests)
    last_modified: 2026-11-24
  - id: testinput
    resource: godot/tests/test_input_handler.gd
    title: test_input_handler.gd (InputHandler dispatch tests)
    last_modified: 2026-11-24
  - id: testdimshud
    resource: godot/tests/test_dims_hud.gd
    title: test_dims_hud.gd (DimsHud bind/refresh tests)
    last_modified: 2026-11-24
  - id: testintro
    resource: godot/tests/test_intro.gd
    title: test_intro.gd (intro mother/base-contract/smoke tests)
    last_modified: 2026-11-26
usage_window: { from: 2026-11-24, to: 2026-11-26 }
---

# Headless Godot Testing

The Godot side is tested without the editor or a display. See
[Run tests](/runbooks/run-tests.md) for commands.

## Pattern

Tests `extend SceneTree`, `preload` the script under test, drive it with
synthetic inputs (for `InputHandler`, real `InputEvent`s dispatched against
the project's loaded InputMap), count checks, print one `FAIL:` line per
failure plus a summary. **Exit code 0 = all pass, 1 = at least one
failure.** Run from `godot/`: `godot --headless -s tests/test_<unit>.gd`.

Tests that need the tree to advance (deferred calls, tweens) drive frames
via `process_frame` state machines — `test_intro.gd` is the frame-driven
example. Gotcha found there: `_ready()` of nodes added during `_initialize()`
only fires on the **first frame**, not synchronously on `add_child`, so
tests must not rely on `_ready`-assigned members right after adding a node.

## Coverage

| Test file | Covers |
|-----------|--------|
| `test_dim_map.gd` | defaults; window advance; axis advance with distinct-skip; duplicates allowed when `enforce_distinct` off; degenerate dim counts (d=1, d=2 collapse); unknown axis is a warned no-op; identity wraps emit nothing; `changed` signal contract |
| `test_input_handler.gd` | `next_line`; dim windows incl. `Shift+R` exact-match dispatch; per-axis typed dispatch; user-input-terminates-dispatch (movement keys and mouse motion) |
| `test_dims_hud.gd` | the full `bind → advance → refresh` path: the HUD text mirrors the `DimMap` mapping after window/axis advances (a `Label` works headless — no rendering, just state) |
| `test_intro.gd` | intro mother scene (frame-driven): play order, camera-pose reset per child, `skip_step`/`skip_all`, bad-scene skip with error, double-`finished` ignored, failed-switch fallback (stays on intro, fade reset, Esc retry re-arms); real StarsScene — EmbStar reuse (word as label text, intro-distance label visibility, transparent fade-in start) and the line mesh joining stars in order; smoke run of the real Title/Stars/Camera scenes under the mother |

Not covered headless (documented in the test file): `exit` (quitting would
end the runner) and `toggle_automation` (no InputMap action exists — dead
branch); both need manual/editor coverage.[^testinput] The intro's visual
result (label legibility at glide distance, camera framing) is manual as
well — run the game and press through the intro.[^testintro]

## Python side

`pytest` over the pipeline: `test_api_gemma.py` (CLI arg parsing, md parsing,
frontmatter, pure embedding-attach helpers) and `test_data.py`
(round-trip + byte-identity gate). Note `test_api_gemma.py` imports
`api_gemma`, which imports `auth` — an API key file must exist, see the
runbook.[^testdimmap]

## Related

- [DimMap](/godot/dim-map.md) — the primary tested unit
- [Run tests](/runbooks/run-tests.md)

[^testdimmap]: godot/tests/test_dim_map.gd, godot/tests/test_input_handler.gd, test_*.py (read during 2026-11-24 bundle rebuild)
[^testinput]: godot/tests/test_input_handler.gd (read during 2026-11-24 bundle rebuild)
[^testintro]: godot/tests/test_intro.gd (read during 2026-11-26 intro fix round)
