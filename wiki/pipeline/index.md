# Pipeline

Python stages that turn `poem/` markdown into the JSON corpus the Godot app visualizes.

* [API embedding (api_gemma.py)](api-embedding.md) - word/line/verse/poem embeddings via the ScaDS AI API (d128)
* [Dimension reduction (dimension_reduction.py)](dimension-reduction.md) - step pipeline (center/abtt/pca/...) across the corpus (d32)
* [Data layer (data.py)](data-layer.md) - typed record model and the one-file-per-poem store
* [Stranded legacy scripts](legacy-scripts.md) - dim_hunt_app.py and pca.py, no working data source (cards 1, 2)
