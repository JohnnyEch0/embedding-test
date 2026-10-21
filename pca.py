import numpy as np, pandas as pd
from sklearn.decomposition import PCA
import plotly.express as px

path="poem_emb/linewise_emb-per-word/eg2_d128_wild-geese_mary-oliver.jsonl"

def main():
    w = load_words(path)
    pca, pcs = fit_pca(w, 3)
    print(variance_report(pca))
    print(loadings(pca))
    plot_pca(pcs, pca).show()            # all lines
    plot_pca(pcs, pca, lines=0).show()   # single line
    plot_scree(pca).show()

def load_words(path):
    df = pd.read_json(path, lines=True)
    w = df.explode("words", ignore_index=True)
    return pd.concat([w.drop(columns="words"),
                      pd.json_normalize(w["words"])], axis=1)


def embedding_matrix(w):
    "Extracts embeddings from df and stacks them in a 2d matrix n_words x dims"
    return np.vstack(w["embedding"].to_numpy())


def fit_pca(w, n_components=3, dedupe=False):
    """Fit on the full corpus. Returns (pca, frame_with_PCs)."""
    if dedupe:
        w = w.drop_duplicates("word").reset_index(drop=True)
    E = embedding_matrix(w)
    pca = PCA(n_components=n_components).fit(E)
    out = w.copy()
    out[[f"PC{i+1}" for i in range(n_components)]] = pca.transform(E)
    return pca, out


def variance_report(pca):
    evr = pca.explained_variance_ratio_
    return pd.DataFrame({
        "PC": np.arange(1, len(evr) + 1),
        "eigenvalue": pca.explained_variance_,
        "explained_var_ratio": evr,
        "cumulative": evr.cumsum(),
    })


def loadings(pca, top=10):
    L = pd.DataFrame(pca.components_.T,
                     columns=[f"PC{i+1}" for i in range(pca.n_components_)])
    L.index.name = "orig_dim"
    return L.reindex(L["PC1"].abs().sort_values(ascending=False).index).head(top)


def plot_pca(pcs, pca, lines=None, color="line_index", title=None):
    """lines: None=all, int, or iterable of line_index values."""
    d = pcs
    if lines is not None:
        sel = [lines] if np.isscalar(lines) else list(lines)
        d = d[d["line_index"].isin(sel)]
    if d.empty:
        raise ValueError(f"no rows for lines={lines}")

    evr = pca.explained_variance_ratio_
    fig = px.scatter_3d(
        d, x="PC1", y="PC2", z="PC3",
        color=d[color].astype(str) if color else None,
        text="word", hover_data=["line", "word"],
        labels={f"PC{i+1}": f"PC{i+1} ({evr[i]:.1%})" for i in range(3)},
        title=title or f"lines={lines if lines is not None else 'all'}",
    )
    fig.update_traces(marker_size=5)
    return fig


def plot_scree(pca):
    evr = pca.explained_variance_ratio_
    x = np.arange(1, len(evr) + 1)
    fig = px.bar(x=x, y=evr, labels={"x": "PC", "y": "explained variance ratio"})
    fig.add_scatter(x=x, y=evr.cumsum(), mode="lines+markers", name="cumulative")
    return fig

if __name__ == "__main__":
    main()
