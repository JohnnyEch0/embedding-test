"""Data loading, aggregation, dimension stats, PCA stub."""
import json
from collections import Counter

import numpy as np
import pandas as pd

# --- VERBOSE FILLER LIST (hand-collected from this poem) ----------------------
# Per instruction: hardcoded stopword set, no external frequency source.
FILLER_WORDS = {
    # articles / determiners
    "a", "the", "no",
    # pronouns
    "you", "your", "yours,", "i", "it", "me", "my", "mine.", "itself", "whoever",
    # be / aux / modal
    "are", "are,", "be", "is", "will", "do", "have", "goes",
    # prepositions / particles
    "to", "of", "in", "on", "on.", "over", "across", "through", "about",
    "for", "with", "from", "like", "at", "by",
    # conjunctions / negation
    "and", "or", "but", "not", "what", "how", "only", "again.",
    # punctuation-only token
    "-",
}


def _norm(w: str) -> str:
    """Normalize a token for filler lookup: lowercase, strip trailing punct."""
    return w.lower().strip(".,;:!?-—'\"")


def load_jsonl(path):
    """Read JSONL -> long DataFrame (one row per word occurrence)."""
    rows, vecs = [], []
    with open(path, "r", encoding="utf-8") as fh:
        for raw in fh:
            raw = raw.strip()
            if not raw:
                continue
            obj = json.loads(raw)
            li, line = obj["line_index"], obj["line"]
            for wpos, w in enumerate(obj["words"]):
                rows.append(
                    {
                        "line_index": li,
                        "line": line,
                        "word_pos": wpos,
                        "word": w["word"],
                    }
                )
                vecs.append(w["embedding"])

    df = pd.DataFrame(rows)
    X = np.asarray(vecs, dtype=np.float32)

    # global reading order index (for the poem-path line)
    df = df.sort_values(["line_index", "word_pos"]).reset_index(drop=True)
    df["order"] = np.arange(len(df))

    # ---- filler flag + occurrence counts -------------------------------------
    norm = df["word"].map(_norm)
    df["norm"] = norm
    df["is_filler"] = norm.isin(FILLER_WORDS)
    counts = Counter(norm)
    df["count"] = norm.map(counts)

    n_filler = int(df["is_filler"].sum())
    unmatched = sorted(
        {w for w, c in counts.items() if c >= 3 and w not in FILLER_WORDS}
    )
    print(
        f"[warn] filler list is a hardcoded hand-made set ({len(FILLER_WORDS)} entries). "
        f"{n_filler}/{len(df)} tokens flagged as filler. "
        f"No corpus-external frequency source used."
    )
    if unmatched:
        print(f"[warn] frequent (>=3x) tokens NOT in filler list: {unmatched}")

    return df, X


def dedupe(df, X):
    """Collapse to unique token types (first occurrence wins)."""
    keep = ~df["norm"].duplicated()
    return df[keep].reset_index(drop=True), X[keep.values]


def dim_stats(X):
    """Per-dimension ranking table. X: (n, d)."""
    mean = X.mean(0)
    std = X.std(0)
    var = X.var(0)
    rng = X.max(0) - X.min(0)
    # excess kurtosis, guarded against ~zero variance
    safe = np.where(std < 1e-8, 1.0, std)
    z = (X - mean) / safe
    kurt = (z ** 4).mean(0) - 3.0
    kurt[std < 1e-8] = 0.0

    out = pd.DataFrame(
        {
            "dim": np.arange(X.shape[1]),
            "mean": mean,
            "std": std,
            "var": var,
            "range": rng,
            "kurtosis": kurt,
            "abs_mean": np.abs(mean),
        }
    )
    # "informative" = high spread relative to offset
    out["spread_over_offset"] = out["std"] / (out["abs_mean"] + 1e-6)
    return out.sort_values("var", ascending=False).reset_index(drop=True)


def center_standardize(X, center=True, standardize=True):
    Z = X.astype(np.float32).copy()
    if center:
        Z -= Z.mean(0, keepdims=True)
    if standardize:
        s = Z.std(0, keepdims=True)
        Z /= np.where(s < 1e-8, 1.0, s)
    return Z


def compute_pca(X, n_components=3):
    """STUB. Frontend-triggered, intentionally no implementation.

    Returns None so the callback can show a 'not implemented' notice.
    """
    pass
