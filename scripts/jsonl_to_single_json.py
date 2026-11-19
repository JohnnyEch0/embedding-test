#!/usr/bin/env python
"""Convert a PoemEmbeddings JSONL file into a single JSON file.

All levels (per-word, per-line, per-verse, per-poem) plus metadata land in
one object:

    {
      "metadata": {...},
      "lines":  [{line_index, line, words: [{word, embedding}], line_embedding}],
      "verses": [{verse_index, line_range, text, verse_embedding}],
      "poem":   {text, poem_embedding}
    }

Examples:
    python scripts/jsonl_to_single_json.py
    python scripts/jsonl_to_single_json.py poem_emb/x.jsonl -o godot/data/single.json
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from data import PoemEmbeddings  # noqa: E402

DEFAULT_IN = ROOT / "poem_emb" / "eg2_d128_wild-geese_mary-oliver.jsonl"


def convert(in_path: str | Path, out_path: str | Path) -> Path:
    """Load JSONL, write the equivalent single-JSON file, return out path."""
    in_path, out_path = Path(in_path), Path(out_path)
    pe = PoemEmbeddings.from_jsonl(in_path)
    obj = {
        "metadata": {**pe.metadata.to_dict(), "type": "Poem-Embeddings"},
        "lines": pe.lines,
        "verses": pe.verses,
        "poem": pe.poem,
    }
    tmp = out_path.with_suffix(out_path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(tmp, out_path)
    return out_path


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", nargs="?", type=Path, default=DEFAULT_IN,
                    help=f"PoemEmbeddings JSONL (default: {DEFAULT_IN})")
    ap.add_argument("-o", "--out", type=Path, default=None,
                    help="output JSON path (default: <input> with .json suffix)")
    args = ap.parse_args()
    out = args.out or args.input.with_suffix(".json")
    result = convert(args.input, out)
    print(f"{args.input} -> {result} ({result.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
