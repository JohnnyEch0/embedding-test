---
type: Testing Convention
title: Headless Godot Testing
description: GDScript SceneTree unit tests run via godot --headless -s, plus the pytest suite for the Python pipeline.
tags: [testing, godot, headless, pytest]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
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
usage_window: { from: 2026-11-24, to: 2026-11-24 }
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

Not covered headless (documented in the test file): `exit` (quitting would
end the runner) and `toggle_automation` (no InputMap action exists — dead
branch); both need manual/editor coverage.[^testinput]

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
