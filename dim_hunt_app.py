"""Interactive 1D/2D/3D embedding dimension explorer.

Single-file app: format-agnostic analysis helpers + Dash UI design target.

STATUS: no data source. The legacy JSONL load was removed; the standard-JSON
loader is not implemented yet. Starting this program raises
NotImplementedError. TODO(card [1]/[2]): load via PoemEmbeddings.load(),
build the token matrix, repopulate DIM_OPTS/LINE_OPTS, re-enable the
callbacks (currently commented) and app.run().
"""
import numpy as np
import pandas as pd
import plotly.graph_objects as go
from dash import Dash, Output, dcc, html, dash_table

# ---------------------------------------------------------------------------
# Data loading -- intentionally absent. Crash loudly at startup until the
# PoemEmbeddings-based loader lands (KANBAN cards [1] and [2]).
# ---------------------------------------------------------------------------
raise NotImplementedError(
    "dim-hunt has no data source: the legacy JSONL load was removed and the "
    "standard-JSON loader is not implemented yet (KANBAN cards [1] and [2]). "
    "Planned fix: PoemEmbeddings.load() over poem_emb/*.json."
)


# ---------------------------------------------------------------------------
# Data analysis (format-agnostic, usable standalone)
# ---------------------------------------------------------------------------

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
    """STUB. Intentionally no implementation (shows 'not implemented' in the UI)."""
    pass


# ---------------------------------------------------------------------------
# App (design target; unreachable until the loader lands)
# ---------------------------------------------------------------------------

DIM_OPTS: list = []   # future: [{"label": f"dim {i}", "value": i} ...]
LINE_OPTS: list = []  # future: [{"label": f"{i}: {line text}", "value": i} ...]

app = Dash(__name__)
app.title = "Embedding Dimension Explorer"

ctl = {"marginBottom": "14px"}

app.layout = html.Div(
    style={"display": "flex", "fontFamily": "sans-serif", "height": "100vh"},
    children=[
        # ---------------- sidebar ----------------
        html.Div(
            style={"width": "320px", "padding": "14px", "overflowY": "auto",
                   "borderRight": "1px solid #ddd"},
            children=[
                html.H3("Controls"),

                html.Div(style=ctl, children=[
                    html.Label("View"),
                    dcc.RadioItems(
                        id="ndim", value=3, inline=True,
                        options=[{"label": "1D", "value": 1},
                                 {"label": "2D", "value": 2},
                                 {"label": "3D", "value": 3}],
                    ),
                ]),

                html.Div(style=ctl, children=[
                    html.Label("1D style"),
                    dcc.RadioItems(
                        id="one-d-style", value="strip", inline=True,
                        options=[{"label": "strip", "value": "strip"},
                                 {"label": "jitter", "value": "jitter"},
                                 {"label": "histogram", "value": "hist"},
                                 {"label": "rug", "value": "rug"}],
                    ),
                ]),

                html.Div(style=ctl, children=[
                    html.Label("Source"),
                    dcc.RadioItems(
                        id="source", value="raw", inline=True,
                        options=[{"label": "raw dims", "value": "raw"},
                                 {"label": "PCA (stub)", "value": "pca"}],
                    ),
                    html.Div(id="pca-note",
                             style={"color": "#b00", "fontSize": "12px"}),
                ]),

                html.Div(style=ctl, children=[
                    html.Label("X dim"),
                    dcc.Dropdown(id="dx", options=DIM_OPTS, value=0, clearable=False),
                    html.Label("Y dim"),
                    dcc.Dropdown(id="dy", options=DIM_OPTS, value=1, clearable=False),
                    html.Label("Z dim"),
                    dcc.Dropdown(id="dz", options=DIM_OPTS, value=2, clearable=False),
                ]),

                html.Div(style=ctl, children=[
                    dcc.Checklist(
                        id="prep",
                        value=["center", "standardize"],
                        options=[{"label": " center (subtract mean)", "value": "center"},
                                 {"label": " standardize (/ std)", "value": "standardize"}],
                    ),
                ]),

                html.Div(style=ctl, children=[
                    html.Label("Color by"),
                    dcc.RadioItems(
                        id="color", value="none",
                        options=[{"label": " none", "value": "none"},
                                 {"label": " line index", "value": "line"},
                                 {"label": " extra dim", "value": "dim"},
                                 {"label": " word length", "value": "len"},
                                 {"label": " occurrence count", "value": "count"},
                                 {"label": " filler flag", "value": "filler"}],
                    ),
                    dcc.Dropdown(id="dc", options=DIM_OPTS, value=3, clearable=False),
                ]),

                html.Div(style=ctl, children=[
                    dcc.Checklist(
                        id="flags",
                        value=["unique"],
                        options=[
                            {"label": " shrink filler words", "value": "shrink"},
                            {"label": " draw poem as path", "value": "path"},
                            {"label": " unique tokens only", "value": "unique"},
                        ],
                    ),
                ]),

                html.Div(style=ctl, children=[
                    html.Label("Line"),
                    dcc.Dropdown(id="line-sel", options=LINE_OPTS, value=-1,
                                 clearable=False),
                ]),

                html.Div(style=ctl, children=[
                    html.Label("Search / filter (substring)"),
                    dcc.Input(id="search", type="text", value="",
                              debounce=True, style={"width": "100%"}),
                ]),

                html.Hr(),
                html.H4("Dimension ranking"),
                dcc.RadioItems(
                    id="rank-by", value="var", inline=True,
                    options=[{"label": "var", "value": "var"},
                             {"label": "kurtosis", "value": "kurtosis"},
                             {"label": "range", "value": "range"},
                             {"label": "spread/offset", "value": "spread_over_offset"},
                             {"label": "|mean|", "value": "abs_mean"}],
                ),
                html.Div(id="rank-table"),
            ],
        ),

        # ---------------- plot ----------------
        html.Div(style={"flex": 1, "padding": "6px"},
                 children=[dcc.Graph(id="plot", style={"height": "95vh"})]),
    ],
)


# ---------------------------------------------------------------------------
# Callbacks -- DEAD until the loader lands: they consume the removed
# word-level DataFrame (DF_FULL/X_FULL) and its filler/count columns.
# Revive with card [1]/[2] on top of PoemEmbeddings.
# ---------------------------------------------------------------------------
#
# def _subset(line_sel, search, unique):
#     ...
#
# @app.callback(Output("rank-table", "children"), Input("rank-by", "value"))
# def _rank(by):
#     ...
#
# @app.callback(
#     Output("plot", "figure"),
#     Output("pca-note", "children"),
#     Input("ndim", "value"), ...
# )
# def _plot(ndim, style, source, dx, dy, dz, prep, color, dc, flags, line_sel, search):
#     ...


if __name__ == "__main__":
    # unreachable: the module-level raise above fires first
    app.run(debug=True)
