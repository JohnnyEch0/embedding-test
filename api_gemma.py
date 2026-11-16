"""Batch-embed words from .md files via the ScaDS AI API."""

import argparse
import json
import os
from pathlib import Path

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


def iter_md_files(input_dir):
    """Yield Path objects of .md files in input_dir."""
    for fname in sorted(os.listdir(input_dir)):
        path = Path(input_dir) / fname
        if path.is_file() and fname.endswith(".md"):
            yield path


def parse_md_lines(lines):
    """Parse raw lines into records: [{line_index, line, words}]."""
    records = []
    for idx, line in enumerate(lines):
        words = line.split()
        if words:
            records.append({"line_index": idx, "line": line, "words": words})
    return records


def embed(words, client, model, dims, batch):
    """Embed flat word list via API in chunks."""
    out = []
    for i in range(0, len(words), batch):
        chunk = words[i:i + batch]
        resp = client.embeddings.create(model=model, input=chunk, dimensions=dims)
        out.extend(item.embedding for item in sorted(resp.data, key=lambda d: d.index))
    return out


def attach_embeddings(records, vectors):
    """Return new records with words → [{word, embedding}] dicts (pure)."""
    out = []
    pos = 0
    for rec in records:
        n = len(rec["words"])
        new_rec = {**rec, "words": [
            {"word": w, "embedding": v}
            for w, v in zip(rec["words"], vectors[pos:pos + n])
        ]}
        out.append(new_rec)
        pos += n
    return out


def write_jsonl(records, out_dir, dims, stem):
    """Write records to JSONL, return path. Assumes out_dir exists."""
    out_path = Path(out_dir) / f"eg2_d{dims}_{stem}.jsonl"
    with open(out_path, "w", encoding="utf-8") as f:
        for rec in records:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    return out_path


def embed_file(path, client, model, dims, batch, out_dir):
    """Embed one .md file, write JSONL, return summary."""
    path = Path(path)
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    lines = path.read_text(encoding="utf-8").splitlines()
    records = parse_md_lines(lines)
    if not records:
        return None
    all_words = [w for rec in records for w in rec["words"]]
    vectors = embed(all_words, client, model, dims, batch)
    records = attach_embeddings(records, vectors)
    stem = path.stem
    out_path = write_jsonl(records, out_dir, dims, stem)
    return out_path, len(records), len(all_words)


def main(argv=None):
    args = parse_args(argv)
    os.makedirs(args.output, exist_ok=True)
    for path in iter_md_files(args.input):
        summary = embed_file(path, client, args.model, args.dims, args.batch, args.output)
        if summary:
            out_path, n_lines, n_words = summary
            print(f"{os.path.basename(path)} -> {out_path} ({n_lines} lines, {n_words} words)")


if __name__ == "__main__":
    main()
