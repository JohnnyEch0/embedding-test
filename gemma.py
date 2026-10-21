from sentence_transformers import SentenceTransformer
import os

directory = "poem" # os.fsencode("poem")
output_dir = "embeddings/"

for f in os.listdir(directory):
    name = os.fsdecode(f)
    if not name.endswith(".md"):
        print(f"Not processing {name} as it's not .md")
        continue
    name = name.strip(".md")

    with open(f) as file:
        print(file)

serious = False
if serious:
    model_id = "google/embeddinggemma-2"
    model = SentenceTransformer(model_id, config_kwargs={"vision_config": None, "audio_config": None})

    print(f"device: {model.device}")
    print(f"dtype: {model.dtype}")
    print(model)
    print("Total number of parameters in the model:", sum(p.numel() for p in model.parameters()))
