"""Batch-embed words from .md files via the ScaDS AI API."""

from __future__ import annotations

import argparse
import json
import os
from collections.abc import Iterator, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from auth import client

MODEL = "google/embeddinggemma-2"
DIMS = 128
BATCH = 256


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
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


def iter_md_files(input_dir: str | Path) -> Iterator[Path]:
    """Yield Path objects of .md files in input_dir."""
    for fname in sorted(os.listdir(input_dir)):
        path = Path(input_dir) / fname
        if path.is_file() and fname.endswith(".md"):
            yield path


@dataclass
class Record:
    """A parsed poem line: original index, raw text, and its words."""
    line_index: int
    line: str
    words: list[str]


def parse_md_lines(lines: Sequence[str]) -> list[Record]:
    """Parse raw lines into Record objects."""
    records = []
    for idx, line in enumerate(lines):
        words = line.split()
        if words:
            records.append(Record(line_index=idx, line=line, words=words))
    return records


def embed(
    words: Sequence[str],
    client: Any,
    model: str,
    dims: int,
    batch: int,
) -> list[list[float]]:
    """Embed flat word list via API in chunks."""
    out: list[list[float]] = []
    for i in range(0, len(words), batch):
        chunk = words[i:i + batch]
        resp = client.embeddings.create(model=model, input=chunk, dimensions=dims)
        out.extend(item.embedding for item in sorted(resp.data, key=lambda d: d.index))
    return out


def attach_embeddings(
    records: list[Record],
    vectors: Sequence[Sequence[float]],
) -> list[dict[str, Any]]:
    """Return new records with words → [{word, embedding}] dicts (pure)."""
    out = []
    pos = 0
    for rec in records:
        n = len(rec.words)
        new_words = [{"word": w, "embedding": v}
                     for w, v in zip(rec.words, vectors[pos:pos + n])]
        out.append({"line_index": rec.line_index, "line": rec.line, "words": new_words})
        pos += n
    return out


def write_jsonl(
    records: Sequence[dict[str, Any]],
    out_dir: str | Path,
    dims: int,
    stem: str,
) -> Path:
    """Write records to JSONL, return path. Assumes out_dir exists."""
    out_path = Path(out_dir) / f"eg2_d{dims}_{stem}.jsonl"
    with open(out_path, "w", encoding="utf-8") as f:
        for rec in records:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    return out_path


def embed_file(
    path: str | Path,
    client: Any,
    model: str,
    dims: int,
    batch: int,
    out_dir: str | Path,
) -> tuple[Path, int, int] | None:
    """Embed one .md file, write JSONL, return summary."""
    path = Path(path)

    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    lines = path.read_text(encoding="utf-8").splitlines()
    records = parse_md_lines(lines)
    if not records:
        return None
    all_words = [w for rec in records for w in rec.words]
    vectors = embed(all_words, client, model, dims, batch)
    embedded = attach_embeddings(records, vectors)
    stem = path.stem
    out_path = write_jsonl(embedded, out_dir, dims, stem)

    return out_path, len(embedded), len(all_words)


def main(argv: Sequence[str] | None = None) -> None:
    args = parse_args(argv)
    os.makedirs(args.output, exist_ok=True)
    for path in iter_md_files(args.input):
        summary = embed_file(path, client, args.model, args.dims, args.batch, args.output)
        if summary:
            out_path, n_lines, n_words = summary
            print(f"{os.path.basename(path)} -> {out_path} ({n_lines} lines, {n_words} words)")


if __name__ == "__main__":
    main()
