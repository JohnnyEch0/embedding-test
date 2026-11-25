"""For every embedding in a poem JSON — words, lines, verses, the poem — find
the nearest vocabulary words (words in the text itself are excluded).

Usage:
  python api_gemma_nearest_n.py poem.json               # print
  python api_gemma_nearest_n.py poem.json -n 20 --save  # also write <stem>_neighbors.json

Needs the index built by api_gemma_vocabulary.py in out/vocab_10k.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import numpy as np

INDEX = Path("out/vocab_10k")
N = 10
TOKEN = re.compile(r"[^\W\d_]+")  # letter runs; drops punctuation/digits


def tokens(text: str) -> set[str]:
    return set(TOKEN.findall(text.lower()))


class Index:
    def __init__(self, path: Path) -> None:
        self.V = np.load(path / "vectors.npy").astype(np.float32)
        self.words = (path / "vocab.txt").read_text(encoding="utf-8").splitlines()
        if len(self.words) != len(self.V):
            raise SystemExit(f"vocab/vectors mismatch: {len(self.words)} vs {len(self.V)}")
        self.pos = {w: i for i, w in enumerate(self.words)}
        norms = np.linalg.norm(self.V, axis=1, keepdims=True)
        self.V /= np.where(norms == 0, 1, norms)  # no-op if already unit-norm
        self.dims = self.V.shape[1]

    def query(self, emb: list[float], text: str, n: int) -> list[dict[str, Any]]:
        q = np.asarray(emb, dtype=np.float32)
        if q.shape != (self.dims,):
            raise ValueError(f"query dim {q.shape} != index dim {self.dims}")
        norm = np.linalg.norm(q)
        if norm == 0:
            return []
        sims = self.V @ (q / norm)
        for t in tokens(text):
            i = self.pos.get(t)
            if i is not None:
                sims[i] = -np.inf  # exclude words already in the text
        k = min(n, int(np.isfinite(sims).sum()))
        top = np.argpartition(-sims, k - 1)[:k]
        top = top[np.argsort(-sims[top])]
        return [{"word": self.words[i], "score": round(float(sims[i]), 4)} for i in top]


def process(poem: dict[str, Any], idx: Index, n: int) -> dict[str, Any]:
    dims = poem.get("metadata", {}).get("dimensions")
    if dims != idx.dims:
        raise SystemExit(f"dimension mismatch: json={dims}, index={idx.dims}")

    out: dict[str, Any] = {"metadata": poem["metadata"], "index": str(INDEX), "n": n}

    out["lines"] = []
    for ln in poem.get("lines", []):
        words = []
        for w in ln["words"]:
            clean = " ".join(TOKEN.findall(w["word"].lower()))
            words.append({"word": w["word"], "clean": clean,
                          "neighbors": idx.query(w["embedding"], clean, n)})
        out["lines"].append({
            "line_index": ln["line_index"],
            "line": ln["line"],
            "neighbors": idx.query(ln["line_embedding"], ln["line"], n),
            "words": words,
        })

    out["verses"] = [{
        "verse_index": v["verse_index"],
        "line_range": v["line_range"],
        "text": v["text"],
        "neighbors": idx.query(v["verse_embedding"], v["text"], n),
    } for v in poem.get("verses", [])]

    p = poem["poem"]
    out["poem"] = {"neighbors": idx.query(p["poem_embedding"], p["text"], n)}
    return out


def fmt(nb: list[dict[str, Any]]) -> str:
    return ", ".join(f"{x['word']} ({x['score']:.2f})" for x in nb)


def show(res: dict[str, Any]) -> None:
    m = res["metadata"]
    print(f"== {m.get('author')} - {m.get('title')} ==")
    print(f"POEM: {fmt(res['poem']['neighbors'])}")
    for v in res["verses"]:
        print(f"\nVERSE {v['verse_index']} {v['line_range']}: {fmt(v['neighbors'])}")
    for ln in res["lines"]:
        print(f"\nLINE {ln['line_index']}: {ln['line']}\n  -> {fmt(ln['neighbors'])}")
        for w in ln["words"]:
            print(f"    {w['clean'] or w['word']}: {fmt(w['neighbors'])}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("json", help="Poem embeddings JSON")
    ap.add_argument("-n", type=int, default=N, help="Neighbors per query (default: %(default)s)")
    ap.add_argument("--save", action="store_true", help="Write <stem>_neighbors.json next to input")
    args = ap.parse_args()

    src = Path(args.json)
    poem = json.loads(src.read_text(encoding="utf-8"))
    res = process(poem, Index(INDEX), args.n)

    if args.save:
        dst = src.with_name(f"{src.stem}_neighbors.json")
        dst.write_text(json.dumps(res, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"saved -> {dst}")
    else:
        show(res)


if __name__ == "__main__":
    main()
