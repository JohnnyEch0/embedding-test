import json
from typing import Any

def load_jsonl(path:str) -> tuple[list[str], dict[str, list[float]], Any] :
    """ File reading function coupled to concrete structure."""
    lines:list[str] = []
    emb_dict: dict[str, list[float]] = {}
    metadata = None
    with open(path, "r", encoding="utf-8") as fh:
            for raw in fh:
                raw = raw.strip()
                if not raw:
                    continue
                # load single json
                obj = json.loads(raw)

                # metadata object
                if "schema_version" in obj:
                     metadata = obj

                else:

                    li, line = obj["line_index"], obj["line"]
                    lines.append(line)

                    for _, w in enumerate(obj["words"]):
                        if not emb_dict.get(w["word"]):
                            emb_dict[w["word"]] = w["embedding"]

    if not metadata: raise LookupError("Couldn't find metadata in jsonl.")

    return lines, emb_dict, metadata
