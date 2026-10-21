import json

def load_jsonl(path:str) :
    lines:list[str] = []
    emb_dict: dict[str, list[float]] = {}
    with open(path, "r", encoding="utf-8") as fh:
            for raw in fh:
                raw = raw.strip()
                if not raw:
                    continue
                # load single json
                obj = json.loads(raw)
                li, line = obj["line_index"], obj["line"]
                print(line)
                lines.append(line)

                for _, w in enumerate(obj["words"]):
                    if not emb_dict.get(w["word"]):
                         emb_dict[w["word"]] = w["embedding"]


    return lines, emb_dict
