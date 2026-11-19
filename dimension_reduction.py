#!/usr/bin/env python3
"""Usage: python3 dimension_reduction.py <input_dir> <output_dir>
          [--steps center,abtt:d=2,pca:k=32] [--fit-levels words,lines,verses,poems]
          [--seed 0] [--decimals 6]
"""
import argparse, ast, json, sys
from abc import ABC, abstractmethod
from pathlib import Path
import numpy as np
from data import PoemEmbeddings

# ---------------- step registry ----------------
REGISTRY: dict[str, type] = {}

def register(cls):
    REGISTRY[cls.name] = cls
    return cls

class Step(ABC):
    name: str
    def __init__(self, seed: int = 0, **params):
        self.seed, self.params = seed, params
    @abstractmethod
    def fit(self, X: np.ndarray) -> None: ...
    @abstractmethod
    def transform(self, X: np.ndarray) -> np.ndarray: ...
    def label(self) -> str:
        p = ",".join(f"{k}={v}" for k, v in self.params.items())
        return f"{self.name}:{p}" if p else self.name
    def state(self) -> dict:
        return {}

@register
class Center(Step):
    name = "center"
    def fit(self, X): self.mean = X.mean(0)
    def transform(self, X): return X - self.mean
    def state(self): return {"mean": self.mean.tolist()}

@register
class Abtt(Step):
    """All-but-the-top: remove mean and top-d principal directions."""
    name = "abtt"
    def fit(self, X):
        self.mean = X.mean(0)
        _, _, vt = np.linalg.svd(X - self.mean, full_matrices=False)
        self.top = vt[: int(self.params.get("d", 1))]
    def transform(self, X):
        Xc = X - self.mean
        return Xc - Xc @ self.top.T @ self.top
    def state(self): return {"mean": self.mean.tolist(), "top": self.top.tolist()}

@register
class PCA(Step):
    """Params: k (int) or var (float 0-1). Output ordered by variance."""
    name = "pca"
    def fit(self, X):
        self.mean = X.mean(0)
        _, s, vt = np.linalg.svd(X - self.mean, full_matrices=False)
        ev = s**2 / (s**2).sum()
        if "k" in self.params:
            k = int(self.params["k"])
        else:
            k = int(np.searchsorted(np.cumsum(ev), float(self.params.get("var", 0.95))) + 1)
        k = min(k, vt.shape[0])
        self.comp, self.ev = vt[:k], ev[:k]
    def transform(self, X): return (X - self.mean) @ self.comp.T
    def state(self):
        return {"mean": self.mean.tolist(), "components": self.comp.tolist(),
                "explained_variance_ratio": self.ev.tolist()}

@register
class ICA(Step):
    """FastICA, components ordered by |excess kurtosis| desc, sign: skew>0."""
    name = "ica"
    def fit(self, X):
        from sklearn.decomposition import FastICA
        k = int(self.params.get("k", min(32, X.shape[1])))
        self.ica = FastICA(n_components=k, whiten="unit-variance",
                           random_state=self.seed, max_iter=1000)
        S = self.ica.fit_transform(X)
        kurt = (S**4).mean(0) - 3
        self.order = np.argsort(-np.abs(kurt))
        S = S[:, self.order]
        self.sign = np.where(((S - S.mean(0))**3).mean(0) < 0, -1.0, 1.0)
        self.kurt = kurt[self.order]
    def transform(self, X):
        return self.ica.transform(X)[:, self.order] * self.sign
    def state(self):
        return {"order": self.order.tolist(), "sign": self.sign.tolist(),
                "kurtosis": self.kurt.tolist(),
                "mixing": self.ica.mixing_.tolist(), "mean": self.ica.mean_.tolist()}

@register
class Normalize(Step):
    name = "l2"
    def fit(self, X): pass
    def transform(self, X):
        return X / np.maximum(np.linalg.norm(X, axis=1, keepdims=True), 1e-12)

@register
class Trunc(Step):
    """Matryoshka truncation (valid only for MRL models)."""
    name = "trunc"
    def fit(self, X): pass
    def transform(self, X): return X[:, : int(self.params["k"])]

# ---------------- pipeline ----------------
def _val(s: str):
    try: return ast.literal_eval(s)
    except Exception: return s

def parse_steps(spec: str, seed: int) -> list[Step]:
    steps = []
    for tok in filter(None, (t.strip() for t in spec.split(","))):
        pass  # replaced below (commas inside params need ';' or ':' handling)
    return steps

def parse_steps(spec: str, seed: int) -> list[Step]:
    """'center abtt:d=2 pca:k=32' -> steps. Separator between steps: whitespace or '+'.
    Params within a step: ':' then 'a=1;b=2'."""
    steps = []
    for tok in spec.replace("+", " ").split():
        name, _, ps = tok.partition(":")
        if name not in REGISTRY:
            sys.exit(f"unknown step {name!r}; known: {sorted(REGISTRY)}")
        params = {k: _val(v) for k, v in (p.split("=", 1) for p in ps.split(";") if p)}
        steps.append(REGISTRY[name](seed=seed, **params))
    return steps

class Pipeline:
    def __init__(self, steps): self.steps = steps
    def fit(self, X):
        for s in self.steps:
            X = s.fit_transform(X) if hasattr(s, "fit_transform") else (s.fit(X), s.transform(X))[1]
        return self
    def transform(self, X):
        for s in self.steps: X = s.transform(X)
        return X
    def labels(self): return [s.label() for s in self.steps]
    def state(self): return [{"step": s.label(), **s.state()} for s in self.steps]

# ---------------- data access (uses project classes) ----------------
LEVELS = {
    "words":  lambda pe: [(w, "embedding") for l in pe.lines for w in l.words],
    "lines":  lambda pe: [(l, "line_embedding") for l in pe.lines],
    "verses": lambda pe: [(v, "verse_embedding") for v in pe.verses],
    "poems":  lambda pe: [(pe.poem, "poem_embedding")],
}

def slots(pe, levels):
    return [s for lv in levels for s in LEVELS[lv](pe)]

def matrix(pe, levels) -> np.ndarray:
    return np.array([getattr(o, a) for o, a in slots(pe, levels)], dtype=np.float64)

def write_back(pe, levels, M, decimals):
    for (o, a), row in zip(slots(pe, levels), M):
        setattr(o, a, np.round(row, decimals).tolist())

# ---------------- main ----------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input_dir"); ap.add_argument("output_dir")
    ap.add_argument("--steps", default="center abtt:d=2 pca:k=32")
    ap.add_argument("--fit-levels", default="words,lines,verses,poems")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--decimals", type=int, default=6)
    a = ap.parse_args()

    fit_levels = a.fit_levels.split(",")
    all_levels = list(LEVELS)
    files = sorted(Path(a.input_dir).glob("*.json"))
    if not files: sys.exit("no .json files in input_dir")
    poems = [PoemEmbeddings.load(f) for f in files]

    dims = {p.metadata.dimensions for p in poems}
    if len(dims) != 1: sys.exit(f"mixed input dimensions: {dims}")

    X = np.unique(np.vstack([matrix(p, fit_levels) for p in poems]), axis=0)
    print(f"fit matrix: {X.shape} from {len(poems)} poems", file=sys.stderr)
    pipe = Pipeline(parse_steps(a.steps, a.seed)).fit(X)

    out = Path(a.output_dir); out.mkdir(parents=True, exist_ok=True)
    for f, p in zip(files, poems):
        Y = pipe.transform(matrix(p, all_levels))
        write_back(p, all_levels, Y, a.decimals)
        p.metadata.dimensions = Y.shape[1]
        p.metadata.procedures = [*p.metadata.procedures, *pipe.labels()]
        p.save(out / f.name)

    (out / "_pipeline.json").write_text(
        json.dumps({"steps": pipe.labels(), "seed": a.seed, "fit_levels": fit_levels,
                    "fit_shape": list(X.shape), "state": pipe.state()}))

if __name__ == "__main__":
    main()
