---
type: Runbook
title: Run Tests
description: How to run the pytest suite and the headless Godot unit tests, and what each covers.
tags: [runbook, testing, pytest, godot]
status: stable
generated: { by: pi/1.5.2, at: 2026-11-24T13:35:47Z }
stale_after: 2027-02-24T00:00:00Z
sources:
  - id: testdata
    resource: test_data.py
    title: test_data.py
    last_modified: 2026-11-19
  - id: testinput
    resource: godot/test_input_handler.gd
    title: godot headless tests
    last_modified: 2026-11-24
usage_window: { from: 2026-11-24, to: 2026-11-24 }
---

# Runbook: Run Tests

## Python (pipeline)

```bash
python -m pytest test_api_gemma.py test_data.py
```

From the repo root. Covers CLI arg parsing, md/frontmatter parsing,
embedding-attach helpers, and the PoemEmbeddings round-trip byte-identity
gate.

Gotcha: `test_api_gemma.py` imports `api_gemma` → `auth`, which **exits the
process if `~/.tudai-api-key` is missing or empty**. No key file means the
suite dies at import, not at a test.

## Godot (headless)

```bash
cd godot
godot --headless -s test_dim_map.gd
godot --headless -s test_input_handler.gd
```

Exit code 0 = all checks pass, 1 = at least one failure; one `FAIL:` line per
failure plus a summary. See [Headless testing](/godot/headless-testing.md)
for what each file covers and the documented gaps (`exit`,
`toggle_automation`).

## Manual / editor coverage

Not reachable headless: the `exit` action, `toggle_automation` (dead branch,
no InputMap action), and the visual behavior of star spawning and the orbit.

## Related

- [Headless testing](/godot/headless-testing.md)
