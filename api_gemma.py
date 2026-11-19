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
from data import Metadata, Poem, PoemEmbeddings

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
    p.add_argument("--jsonl", action="store_true",
                  help="DEPRECATED: write JSONL instead of the default single JSON file")
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


def poem_texts(
    path: str | Path,
) -> tuple[list[str], list[str], list[tuple[str, tuple[int, int]]], str]:
    """Return (words, raw_lines, verse_infos, poem_text) for a .md poem file.

    verse_infos: one (text, (line_start, line_end_exclusive)) per verse.
    Verse/poem texts are the verbatim to_str() outputs (trailing
    spaces/newlines included).
    """
    p = Path(path)
    poem = Poem.from_markdown(p)
    words = [w for v in poem.verses for l in v.lines for w in l.words]
    raw_lines = [ln for ln in p.read_text(encoding="utf-8").splitlines() if ln.strip()]
    verse_infos: list[tuple[str, tuple[int, int]]] = []
    start = 0
    for v in poem.verses:
        n = len(v.lines)
        verse_infos.append((v.to_str(), (start, start + n)))
        start += n
    return words, raw_lines, verse_infos, poem.to_str()


def make_metadata(stem: str, model: str, dims: int) -> Metadata:
    m = Metadata()
    m.schema_version = PoemEmbeddings.SCHEMA_VERSION
    m.author = None
    m.title = stem
    m.model = model
    m.dimensions = dims
    m.procedures = [f"api-embedding:{model}"]
    return m


def embed_poem_file(
    path: str | Path,
    client: Any,
    model: str,
    dims: int,
    batch: int,
    out_dir: str | Path,
    jsonl: bool = False,
) -> Path | None:
    """Embed one poem at word/line/verse/poem levels, write it, return path.

    Writes a single JSON file by default; jsonl=True keeps the deprecated
    JSONL format.
    """
    path = Path(path)
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    words, raw_lines, verse_infos, poem_text = poem_texts(path)
    if not words:
        return None
    n_lines = len(raw_lines)
    if n_lines != sum(e - s for _, (s, e) in verse_infos):
        return None

    texts = words + raw_lines + [t for t, _ in verse_infos] + [poem_text]
    vectors = embed(texts, client, model, dims, batch)

    n_words = len(words)
    word_vecs = vectors[:n_words]
    line_vecs = vectors[n_words:n_words + n_lines]
    verse_vecs = vectors[n_words + n_lines:-1]
    poem_vec = vectors[-1]

    line_records = []
    pos = 0
    for i, line in enumerate(raw_lines):
        ws = line.split()
        rec_words = [{"word": w, "embedding": v}
                     for w, v in zip(ws, word_vecs[pos:pos + len(ws)])]
        pos += len(ws)
        line_records.append({
            "line_index": i,
            "line": line,
            "words": rec_words,
            "line_embedding": line_vecs[i],
        })
    if pos != n_words:
        raise ValueError(f"word split mismatch: {pos} vs {n_words}")

    verse_records = [{
        "verse_index": i,
        "line_range": [s, e],
        "text": t,
        "verse_embedding": v,
    } for i, ((t, (s, e)), v) in enumerate(zip(verse_infos, verse_vecs))]

    pe = PoemEmbeddings()
    pe.metadata = make_metadata(path.stem, model, dims)
    pe.lines = line_records
    pe.verses = verse_records
    pe.poem = {"text": poem_text, "poem_embedding": poem_vec}

    out_suffix = ".jsonl" if jsonl else ".json"
    out_path = out_dir / f"eg2_d{dims}_{path.stem}{out_suffix}"
    if jsonl:
        pe.to_jsonl(out_path)  # deprecated format, kept behind the jsonl flag
    else:
        pe.to_json(out_path)
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
        summary = embed_poem_file(path, client, args.model, args.dims, args.batch,
                                  args.output, jsonl=args.jsonl)
        if summary:
            print(f"{os.path.basename(path)} -> {summary}")


if __name__ == "__main__":
    main()
