# Embedding Visualizer (EmbVis)

This Project aims to visualize embeddings in an aesthetic, star-like way.

There are multiple python scripts for various tasks, in no particular order.

Workflow
- Get Markdown Poems
- run `python3 api-gemmy.py <in-dir> <out-dir>`
- run `python3 dimension_reduction.py <in-dir> <out-dir>`
- move to godot/data


## [[api-gemma.py]]
Takes a directory with markdown poems and transformes them into embeddings.
`python3 api-gemmy.py <in-dir> <out-dir>`

## godot/
Star visualization. Which embedding dimensions are shown on the X/Y/Z axes
is steered by `dim_map.gd` (pure state, headless-testable via
`godot --headless -s test_dim_map.gd`; its HUD via
`godot --headless -s test_dims_hud.gd`):
- `R` / `Shift+R` — next / previous trio of dimensions
- `F` / `G` / `H` (+shift for reverse) — step the dimension on the X / Y / Z axis,
  skipping dimensions already shown on other axes (`enforce_distinct`, default on)
- Current mapping is shown top-left (`dims X:.. Y:.. Z:.. (of ..)`)
