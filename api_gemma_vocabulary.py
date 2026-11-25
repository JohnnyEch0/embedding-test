"""Build the vocabulary index: embed the 10,000 most common English words
(wordfreq) via the ScaDS AI API, for nearest-word lookups.

Writes out/vocab_10k/ (vectors.npy, vocab.txt, meta.json). Interrupted runs
resume: completed shards are skipped on rerun.
"""

from __future__ import annotations

import json
import time
from pathlib import Path
import random

import numpy as np
from wordfreq import top_n_list

from api_gemma import BATCH, DIMS, MODEL, client, embed

OUT = Path("out/vocab_10k")
N_WORDS = 10_000
LANG = "en"
SHARD = BATCH * 8  # words per checkpoint
RETRIES = 5


def load_vocab() -> list[str]:
    seen: set[str] = set()
    vocab: list[str] = []
    for w in top_n_list(LANG, N_WORDS):
        if w.isalpha() and w not in seen:
            seen.add(w)
            vocab.append(w)
    return vocab

RETRIES = 8
MIN_INTERVAL = 0.2     # s between calls (client-side throttle)
MAX_WAIT = 120         # s cap on backoff

_last_call = 0.0


def embed_retry(words: list[str]) -> np.ndarray:
    """One API call (len(words) <= BATCH) with throttle, backoff, Retry-After."""
    global _last_call
    for attempt in range(RETRIES):
        gap = MIN_INTERVAL - (time.monotonic() - _last_call)
        if gap > 0:
            time.sleep(gap)
        _last_call = time.monotonic()
        try:
            return np.asarray(embed(words, client, MODEL, DIMS, BATCH), dtype=np.float32)
        except Exception as e:  # noqa: BLE001
            status = getattr(e, "status_code", None)
            if status is not None and status not in (408, 409, 429) and status < 500:
                raise  # permanent client error (auth, bad request): don't retry
            if attempt == RETRIES - 1:
                raise
            headers = getattr(getattr(e, "response", None), "headers", None) or {}
            try:
                delay = float(headers.get("retry-after"))
            except (TypeError, ValueError):
                delay = min(MAX_WAIT, 2 ** attempt)
            delay += random.uniform(0, 1)  # jitter
            print(f"  retry {attempt + 1}/{RETRIES} in {delay:.1f}s "
                  f"(status={status}): {e}")
            time.sleep(delay)
    raise RuntimeError("unreachable")

def main() -> None:
    shards = OUT / "shards"
    shards.mkdir(parents=True, exist_ok=True)

    vocab = load_vocab()
    text = "\n".join(vocab) + "\n"
    vocab_path = OUT / "vocab.txt"
    if vocab_path.exists() and vocab_path.read_text(encoding="utf-8") != text:
        raise SystemExit(f"{vocab_path} differs from current vocab; delete {OUT} to rebuild.")
    vocab_path.write_text(text, encoding="utf-8")

    n_shards = -(-len(vocab) // SHARD)
    print(f"{len(vocab)} words, {n_shards} shards, model={MODEL}, dims={DIMS}")

    for s in range(n_shards):
        path = shards / f"{s:06d}.npy"
        if path.exists():
            continue
        chunk = vocab[s * SHARD:(s + 1) * SHARD]
        vecs = embed_retry(chunk)
        if vecs.shape != (len(chunk), DIMS):
            raise ValueError(f"shard {s}: bad shape {vecs.shape}")
        tmp = path.with_suffix(".tmp.npy")
        np.save(tmp, vecs)
        tmp.replace(path)
        print(f"shard {s + 1}/{n_shards} done")

    vectors = np.concatenate([np.load(shards / f"{s:06d}.npy") for s in range(n_shards)])
    assert vectors.shape == (len(vocab), DIMS), vectors.shape

    norms = np.linalg.norm(vectors, axis=1)
    unit = bool(np.allclose(norms, 1.0, atol=1e-3))
    if not unit:
        print(f"WARNING: not unit-norm. min={norms.min():.4f} "
              f"max={norms.max():.4f} mean={norms.mean():.4f}. Stored as returned.")
    if not np.isfinite(vectors).all():
        print("WARNING: NaN/inf in vectors.")

    np.save(OUT / "vectors.npy", vectors)
    (OUT / "meta.json").write_text(json.dumps({
        "model": MODEL, "dims": DIMS, "count": len(vocab),
        "source": f"wordfreq:{LANG}:top{N_WORDS}", "unit_norm": unit,
    }, indent=2), encoding="utf-8")
    print(f"saved {vectors.shape} -> {OUT}")


if __name__ == "__main__":
    main()
