"""Interactive 1D/2D/3D embedding dimension explorer."""
import sys

import numpy as np
import plotly.graph_objects as go
from dash import Dash, Input, Output, State, dcc, html, dash_table

from dim_hunt_data import (
    load_jsonl,
    dedupe,
    dim_stats,
    center_standardize,
    compute_pca,
)

PATH = sys.argv[1] if len(sys.argv) > 1 else "poem.jsonl"

DF_FULL, X_FULL = load_jsonl(PATH)
N_DIMS = X_FULL.shape[1]
print(f"[info] {len(DF_FULL)} tokens, {N_DIMS} dims, "
      f"{DF_FULL['line_index'].nunique()} lines")

DIM_OPTS = [{"label": f"dim {i}", "value": i} for i in range(N_DIMS)]
LINE_OPTS = [{"label": "— entire poem —", "value": -1}] + [
    {"label": f"{i}: {t[:45]}", "value": int(i)}
    for i, t in DF_FULL.drop_duplicates("line_index")[["line_index", "line"]].values
]

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


def _subset(line_sel, search, unique):
    df, X = DF_FULL, X_FULL
    if unique:
        df, X = dedupe(df, X)
    m = np.ones(len(df), bool)
    if line_sel != -1:
        m &= (df["line_index"] == line_sel).values
    if search:
        m &= df["word"].str.contains(search, case=False, regex=False).values
    return df[m].reset_index(drop=True), X[m]


@app.callback(Output("rank-table", "children"), Input("rank-by", "value"))
def _rank(by):
    s = dim_stats(X_FULL).sort_values(by, ascending=False).head(25)
    s = s[["dim", "var", "std", "abs_mean", "kurtosis", "spread_over_offset"]].round(4)
    return dash_table.DataTable(
        data=s.to_dict("records"),
        columns=[{"name": c, "id": c} for c in s.columns],
        style_cell={"fontSize": "11px", "padding": "2px"},
        style_table={"maxHeight": "320px", "overflowY": "auto"},
    )


@app.callback(
    Output("plot", "figure"),
    Output("pca-note", "children"),
    Input("ndim", "value"), Input("one-d-style", "value"), Input("source", "value"),
    Input("dx", "value"), Input("dy", "value"), Input("dz", "value"),
    Input("prep", "value"), Input("color", "value"), Input("dc", "value"),
    Input("flags", "value"), Input("line-sel", "value"), Input("search", "value"),
)
def _plot(ndim, style, source, dx, dy, dz, prep, color, dc, flags, line_sel, search):
    note = ""
    if source == "pca":
        if compute_pca(X_FULL, 3) is None:
            note = "PCA backend not implemented (stub). Falling back to raw dims."

    df, X = _subset(line_sel, search, "unique" in flags)
    if len(df) == 0:
        return go.Figure(layout={"title": "no tokens match filter"}), note

    Z = center_standardize(X, "center" in prep, "standardize" in prep)

    # --- size -----------------------------------------------------------------
    size = np.full(len(df), 11.0)
    if "shrink" in flags:
        size[df["is_filler"].values] = 3.5

    # --- color ----------------------------------------------------------------
    marker = {"size": size, "opacity": 0.85, "line": {"width": 0}}
    if color == "line":
        marker.update(color=df["line_index"], colorscale="Turbo", showscale=True)
    elif color == "dim":
        marker.update(color=Z[:, dc], colorscale="RdBu", showscale=True,
                      colorbar={"title": f"dim {dc}"})
    elif color == "len":
        marker.update(color=df["word"].str.len(), colorscale="Viridis", showscale=True)
    elif color == "count":
        marker.update(color=df["count"], colorscale="Cividis", showscale=True)
    elif color == "filler":
        marker.update(color=df["is_filler"].astype(int), colorscale="Bluered",
                      showscale=False)

    hover = [f"{w}<br>line {li}: {ln}"
             for w, li, ln in zip(df["word"], df["line_index"], df["line"])]
    order = np.argsort(df["order"].values)  # reading order for path
    draw_path = "path" in flags

    fig = go.Figure()

    # ----- 1D -----------------------------------------------------------------
    if ndim == 1:
        v = Z[:, dx]
        if style == "hist":
            fig.add_trace(go.Histogram(x=v, nbinsx=40))
        else:
            y = (np.random.default_rng(0).normal(0, 0.25, len(v))
                 if style == "jitter" else np.zeros(len(v)))
            mode = "markers" if style != "rug" else "markers"
            fig.add_trace(go.Scatter(
                x=v, y=y, mode=mode, marker=marker, text=hover,
                hoverinfo="text", name="words"))
            if style == "rug":
                for xi in v:
                    fig.add_shape(type="line", x0=xi, x1=xi, y0=-0.3, y1=0.3,
                                  line={"width": 1, "color": "#888"})
            if draw_path and style != "hist":
                fig.add_trace(go.Scatter(
                    x=v[order], y=y[order], mode="lines",
                    line={"width": 1, "color": "rgba(80,80,80,0.4)"},
                    hoverinfo="skip", name="poem path"))
            fig.update_yaxes(visible=(style == "jitter"))
        fig.update_xaxes(title=f"dim {dx}")

    # ----- 2D -----------------------------------------------------------------
    elif ndim == 2:
        fig.add_trace(go.Scattergl(
            x=Z[:, dx], y=Z[:, dy], mode="markers+text" if len(df) < 120 else "markers",
            text=df["word"], textposition="top center", textfont={"size": 8},
            hovertext=hover, hoverinfo="text", marker=marker, name="words"))
        if draw_path:
            fig.add_trace(go.Scattergl(
                x=Z[order, dx], y=Z[order, dy], mode="lines",
                line={"width": 1, "color": "rgba(80,80,80,0.4)"},
                hoverinfo="skip", name="poem path"))
        fig.update_xaxes(title=f"dim {dx}")
        fig.update_yaxes(title=f"dim {dy}")

    # ----- 3D -----------------------------------------------------------------
    else:
        fig.add_trace(go.Scatter3d(
            x=Z[:, dx], y=Z[:, dy], z=Z[:, dz],
            mode="markers+text" if len(df) < 120 else "markers",
            text=df["word"], textfont={"size": 9},
            hovertext=hover, hoverinfo="text", marker=marker, name="words"))
        if draw_path:
            fig.add_trace(go.Scatter3d(
                x=Z[order, dx], y=Z[order, dy], z=Z[order, dz], mode="lines",
                line={"width": 2, "color": "rgba(80,80,80,0.5)"},
                hoverinfo="skip", name="poem path"))
        fig.update_layout(scene={"xaxis_title": f"dim {dx}",
                                 "yaxis_title": f"dim {dy}",
                                 "zaxis_title": f"dim {dz}"})

    fig.update_layout(margin={"l": 0, "r": 0, "t": 30, "b": 0},
                      showlegend=False,
                      title=f"{len(df)} tokens | prep: {', '.join(prep) or 'none'}")
    return fig, note


if __name__ == "__main__":
    app.run(debug=True)
