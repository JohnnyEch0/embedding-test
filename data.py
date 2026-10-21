"""
classes to load and save the used the embeddings
"""
import helpers

import numpy as np

class LinewiseEmbeddingPerWord():
    def __init__(self) -> None:
        self.lines:list[str]
        self.emb_dict:dict[str, list[float]]
        pass

    @classmethod
    def from_jsonl(cls, path):
        rows, emb_dict = helpers.load_jsonl(path)
        instance = cls()
        instance.lines = rows
        instance.emb_dict = emb_dict
        return instance

    # Data Analysis
    def near_constant_dims(self, max_deviation:float=0.1):
        X = np.array([e for w,e in self.emb_dict.items()])
        sd = X.std(0)
        print(sd.min(), np.percentile(sd, [1,5,25,50]), sd.max())
        print((sd / sd.mean()).min())
        return np.where(sd < max_deviation * sd.mean())[0].tolist()

    def near_constant_dims_quantile(self, quantile=0.01):
        """Returns the dimensions in the lowest sd ::quantile:: """
        X = np.array(list(self.emb_dict.values()))
        sd = X.std(0)
        thr = np.quantile(sd, quantile)
        return np.where(sd <= thr)[0].tolist()

    def redundant_dim_pairs(self, top_k: int = 10) -> dict[tuple[int, int], float]:
        """Top-k dim pairs by |Pearson correlation|. Keys (i, j) with i < j."""
        X = np.array(list(self.emb_dict.values()))
        C = np.corrcoef(X, rowvar=False)
        np.fill_diagonal(C, 0.0)
        iu = np.triu_indices_from(C, k=1)
        vals = np.abs(C[iu])
        k = min(top_k, vals.size)
        sel = np.argpartition(-vals, k - 1)[:k]
        sel = sel[np.argsort(-vals[sel])]
        return {
            (int(iu[0][s]), int(iu[1][s])): float(C[iu[0][s], iu[1][s]])
            for s in sel
        }

    def diagnostics(self):
        X = np.array(list(self.emb_dict.values()))
        Xc = X - X.mean(0)
        s = np.linalg.svd(Xc, compute_uv=False)
        ev = s**2 / (len(X) - 1)
        print(X.shape)
        print("top component shares")
        print(ev[:10] / ev.sum())
        print("how many dims for 90/95/99%")
        print(np.cumsum(ev)/ev.sum())
        print("participation ratio = effective dim")
        print((ev.sum()**2) / (ev**2).sum())
    # Utilities
    def print_embeddings(self) -> None:
        for row in self.lines:
            print(row)
            for word in row.split():
                if self.emb_dict.get(word):
                    embedding_vals = []
                    for i in self.emb_dict[word][:5]:
                        embedding_vals.append(i)

                    txt = f"{word} - Embeddings: {[f"{e:.2f}" for e in embedding_vals]}"
                    print(txt)

    # Dunder Stuff
    def __repr__(self) -> str:
        return f"Linewise Poem Embeddings of {len(self.lines)=} {self.lines[0]}"



if __name__ == "__main__":
    instance = LinewiseEmbeddingPerWord.from_jsonl("poem_emb/linewise_emb-per-word/eg2_d128_wild-geese_mary-oliver.jsonl")
    instance.print_embeddings()
    print(instance)
    print(instance.near_constant_dims())
    print(instance.near_constant_dims_quantile(0.1))
    print(instance.redundant_dim_pairs())
    print(instance.diagnostics())
