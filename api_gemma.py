"""Batch-embed words from .md files via the ScaDS AI API."""

import argparse
import json
import os

from auth import client

MODEL = "google/embeddinggemma-2"
DIMS = 128
BATCH = 256


def parse_args(argv=None):
    p = argparse.ArgumentParser(
        description="Batch-embed words from .md files via the ScaDS AI API",
        epilog=("Input: directory of .md files. "
                "Output: JSONL, one record per line."),
    )
    p.add_argument("input", help="Directory containing .md files")
    p.add_argument("output", help="Output directory for JSONL files")
    p.add_argument("--model", default=MODEL, help="Embedding model (default: %(default)s)")
    p.add_argument("--dims", type=int, default=DIMS,
                   help="Embedding dimensions (default: %(default)s)")
    p.add_argument("--batch", type=int, default=BATCH,
                   help="Words per API call (default: %(default)s)")
    return p.parse_args(argv)


def embed(words, client, model, dims, batch):
    out = []
    for i in range(0, len(words), batch):
        chunk = words[i:i + batch]
        resp = client.embeddings.create(model=model, input=chunk, dimensions=dims)
        out.extend(item.embedding for item in sorted(resp.data, key=lambda d: d.index))
    return out


def main(argv=None):
    args = parse_args(argv)
    os.makedirs(args.output, exist_ok=True)

    for fname in sorted(os.listdir(args.input)):
        path = os.path.join(args.input, fname)
        if not os.path.isfile(path) or not fname.endswith(".md"):
            continue
        with open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()

        records = []
        all_words = []
        for idx, line in enumerate(lines):
            words = line.split()
            if not words:
                continue
            records.append({"line_index": idx, "line": line, "words": words})
            all_words.extend(words)

        if not all_words:
            continue

        vectors = embed(all_words, client, args.model, args.dims, args.batch)

        out_path = os.path.join(args.output, f"eg2_d{args.dims}_{fname[:-3]}.jsonl")
        with open(out_path, "w", encoding="utf-8") as f:
            pos = 0
            for rec in records:
                n = len(rec["words"])
                rec["words"] = [
                    {"word": w, "embedding": v}
                    for w, v in zip(rec["words"], vectors[pos:pos + n])
                ]
                pos += n
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")

        print(f"{fname} -> {out_path} ({len(records)} lines, {len(all_words)} words)")


if __name__ == "__main__":
    main()
