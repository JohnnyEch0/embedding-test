from auth import client
import argparse
import os
import sys

import openai
from openai import OpenAI


MODEL = "Cloudflare/clef-flash"

actions = [
    "Vault a 10-ft chasm mid-chase",                      # Athletics
    "Pick a noble's coin purse at a crowded gala",        # Sleight of Hand
    "Identify the sigil burned into a corpse's palm",     # Arcana or Religion — depends on sigil origin
    "Talk a city guard out of a bribe accusation",        # Persuasion or Deception — depends on guilt
    "Set a snare to catch dinner in the woods",           # Survival
    "Jump over the Log",
    "Convince them of giving us a discount",
    "Steal the pearl from under the Fairy Dragons' Claw"
]
CHOICE = {
    "type": "choice", # the type is a pseudo enum of choice, predicate (0-1) and score { tiered labels }
    "name": "Skill",
    "instructions": "Which skill should be used for this action? ",
    "choices": [
            {"value": "Acrobatics", "description": "Balance, tumbling, aerial maneuvers, staying upright on difficult footing."},
            {"value": "Animal Handling",  "description": "Calm, control, train, or read intentions of domesticated and wild animals."},
            {"value": "Arcana", "description": "Recall lore on spells, magic items, eldritch symbols, magical traditions, planes."},
            {"value": "Athletics", "description": "Climbing, jumping, swimming, grappling, shoving."},
            {"value": "Deception", "description": "Convincingly hide the truth via lies, disguise, misdirection."},
            {"value": "History", "description": "Recall legendary events, ancient kingdoms, past disputes, wars, lost civilizations."},
            {"value": "Insight",  "description": "Determine true intentions of a creature; detect lies, predict next move."},
            {"value": "Intimidation", "description": "Influence through overt threats, hostile actions, physical menace."},
            {"value": "Investigation", "description": "Deduce from clues, search for hidden details, infer location of concealed objects."},
            {"value": "Medicine",  "description": "Stabilize dying creatures, diagnose illness, determine cause of death."},
            {"value": "Nature", "description": "Recall lore on terrain, plants, animals, weather, natural cycles."},
            {"value": "Perception",  "description": "Spot, hear, or otherwise detect presence of something via senses."},
            {"value": "Performance", "description": "Delight an audience with music, dance, acting, storytelling."},
            {"value": "Persuasion", "description": "Influence with tact, social grace, good nature; act in good faith."},
            {"value": "Religion",  "description": "Recall lore on deities, rites, prayers, religious hierarchies, holy symbols, cults."},
            {"value": "Sleight of Hand", "description": "Manual trickery: planting objects, concealing items, picking pockets."},
            {"value": "Stealth", "description": "Hide, move silently, slip past foes unnoticed."},
            {"value": "Survival", "description": "Track, hunt, forage, navigate wilderness, predict weather, avoid natural hazards."}
        ]
}


PREDICT = {
    "type": "predicate",
    "name": "Difficulty v Predict",
    "instructions": "How hard is this task to achieve in Dungeons and Dragons? Where 0.01 is trivial and 1.00 is undoable. Remember that the action-takers are heroes!",
}

SCORE = {
  "type": "score",
  "name": "Difficulty v Score",
  "instructions": "How hard is this task to achieve in Dungeons and Dragons? Judge the inherent difficulty of the task itself, ignoring the character's bonuses.",
  "levels": [
    {"label": "Very Easy",        "description": "DC 5. Succeeds without meaningful risk; almost anyone pulls it off. Usually no roll needed."},
    {"label": "Easy",             "description": "DC 10. Minor obstacle; an untrained character succeeds more often than not."},
    {"label": "Medium",           "description": "DC 15. Real challenge; trained or competent characters succeed about half the time."},
    {"label": "Hard",             "description": "DC 20. Demands high ability, proficiency, or favorable circumstances."},
    {"label": "Very Hard",        "description": "DC 25. Expert territory; needs expertise, magic, or strong advantage to be plausible."},
    {"label": "Nearly Impossible","description": "DC 30. Legendary feat; only high-level, optimized characters have any chance."}
  ]
}

def print_decision(decision):
    for answer in decision.answers:
            if answer.type == "choice":
                print(f"  {answer.name}: {answer.choice} ({answer.confidence:.0%})")
            elif answer.type == "predicate":
                print(f"  {answer.name}: {answer.probability:.0%} likely")
            elif answer.type == "score":
                likeliest = max(answer.probabilities, key=lambda level: level.probability)
                print(f"  {answer.name}: {answer.score:.2f} on a scale from 0 to {len(answer.probabilities) - 1}"
                      f" (most likely {likeliest.label}, {likeliest.probability:.0%})")
            else:
                print(f"  {answer.name}: the model declined to answer this question")

def ask_decisions(text, questions):
    # The openai library knows this endpoint (version 3.26 or newer) and returns typed objects.
    decision = client.decisions.create(model=MODEL, input=text, questions=questions)
    print_decision(decision)

    return decision.answers


def main():
    decisions = []
    for a in actions:
        print(a)
        decisions.append(ask_decisions(a, [CHOICE, PREDICT, SCORE]))

    render_image(actions, decisions, path="skill_check_report.png")
    pass

# ── image rendering ──────────────────────────────────────────────────────────


import matplotlib
matplotlib.use("Agg")  # headless; drop if you want interactive windows
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, FancyBboxPatch


BG       = "#12131a"
PANEL    = "#1b1d27"
ROW_ALT  = "#20232f"
FG       = "#e8e8f0"
MUTED    = "#8a8fa3"
ACCENT   = "#c9a227"   # gold
GRID     = "#2e3242"

# DC tier -> color ramp (easy → impossible)
TIER_COLORS = ["#4ade80", "#a3e635", "#facc15", "#fb923c", "#f87171", "#c084fc"]


def _extract(answers):
    row = {"skill": "—", "skill_conf": None, "prob": None,
           "score": None, "score_max": None, "label": "—", "label_conf": None}
    if not answers:
        return row
    for a in answers:
        t = getattr(a, "type", None)
        if t == "choice":
            row["skill"], row["skill_conf"] = a.choice, a.confidence
        elif t == "predicate":
            row["prob"] = a.probability
        elif t == "score":
            row["score"] = a.score
            row["score_max"] = len(a.probabilities) - 1
            best = max(a.probabilities, key=lambda lv: lv.probability)
            row["label"], row["label_conf"] = best.label, best.probability
    return row


def _dc_from_score(score, base=5, step=5):
    return base + step * score


def _tier_color(score, score_max):
    if score is None:
        return MUTED
    idx = int(round(score))
    idx = max(0, min(len(TIER_COLORS) - 1, idx))
    return TIER_COLORS[idx]


def _wrap(text, n=46):
    import textwrap
    return "\n".join(textwrap.wrap(text, n)) or text


def render_image(actions, decisions, path="skill_check_report.png", dpi=200):
    rows = [_extract(d) for d in decisions]
    n = len(rows)

    row_h = 0.62
    header_h = 1.15
    fig_h = header_h + n * row_h + 0.9
    fig_w = 20

    fig, ax = plt.subplots(figsize=(fig_w, fig_h))
    fig.patch.set_facecolor(BG)
    ax.set_facecolor(BG)
    ax.set_xlim(0, 100)
    ax.set_ylim(0, fig_h)
    ax.axis("off")

    # column x-anchors (in 0-100 space)
    X_ACTION, X_SKILL, X_CONF, X_PRED, X_DC, X_TIER = 2.5, 36, 46, 56, 80, 86
    BAR_W = 16.0

    y = fig_h - 0.55

    # title
    ax.text(X_ACTION, y, "SKILL CHECK ANALYSIS", color=ACCENT,
            fontsize=16, fontweight="bold", family="DejaVu Sans", va="center")
    ax.text(98, y, MODEL, color=MUTED, fontsize=9, ha="right", va="center")
    y -= 0.42

    # header row
    hdrs = [(X_ACTION, "ACTION"), (X_SKILL, "SKILL"), (X_CONF, "CONF"),
            (X_PRED, "DIFFICULTY (predicate)"), (X_DC, "DC"), (X_TIER, "TIER")]
    for x, label in hdrs:
        ax.text(x, y, label, color=MUTED, fontsize=8.5,
                fontweight="bold", va="center", family="DejaVu Sans")
    y -= 0.18
    ax.plot([X_ACTION, 98], [y, y], color=GRID, lw=1.0)
    y -= row_h / 2 + 0.08

    for i, (action, r) in enumerate(zip(actions, rows)):
        # zebra stripe
        if i % 2 == 0:
            ax.add_patch(Rectangle((X_ACTION - 1.2, y - row_h / 2 + 0.04),
                                   99.2 - X_ACTION, row_h - 0.08,
                                   facecolor=ROW_ALT, edgecolor="none", zorder=0))

        # action
        ax.text(X_ACTION, y, action, color=FG, fontsize=10,
                va="center", family="DejaVu Sans", zorder=2)

        # skill
        ax.text(X_SKILL, y, r["skill"], color=FG, fontsize=10,
                fontweight="bold", va="center", zorder=2)

        # confidence dot + pct
        c = r["skill_conf"]
        if c is None:
            ax.text(X_CONF, y, "—", color=MUTED, fontsize=9, va="center", zorder=2)
        else:
            dot = "#4ade80" if c >= 0.75 else "#facc15" if c >= 0.50 else "#f87171"
            ax.scatter([X_CONF], [y], s=42, color=dot, zorder=3)
            ax.text(X_CONF + 1.6, y, f"{c:.0%}", color=FG if c >= 0.5 else dot,
                    fontsize=9, va="center", zorder=2)

        # predicate bar
        p = r["prob"]
        ax.add_patch(FancyBboxPatch((X_PRED, y - 0.11), BAR_W, 0.22,
                                    boxstyle="round,pad=0,rounding_size=0.11",
                                    facecolor=GRID, edgecolor="none", zorder=1))
        if p is not None:
            ax.add_patch(FancyBboxPatch((X_PRED, y - 0.11), max(BAR_W * p, 0.25), 0.22,
                                        boxstyle="round,pad=0,rounding_size=0.11",
                                        facecolor=_tier_color(r["score"], r["score_max"]),
                                        edgecolor="none", zorder=2))
            ax.text(X_PRED + BAR_W + 0.8, y, f"{p:.0%}", color=FG,
                    fontsize=9, va="center", zorder=2)

        # DC badge
        if r["score"] is not None:
            dc = _dc_from_score(r["score"])
            col = _tier_color(r["score"], r["score_max"])
            ax.add_patch(FancyBboxPatch((X_DC - 1.3, y - 0.17), 3.6, 0.34,
                                        boxstyle="round,pad=0,rounding_size=0.1",
                                        facecolor=col, edgecolor="none", zorder=2))
            ax.text(X_DC + 0.5, y, f"{dc:.0f}", color="#12131a", fontsize=9.5,
                    fontweight="bold", ha="center", va="center", zorder=3)
            tier_txt = f"{r['label']}"
            if r["label_conf"] is not None:
                tier_txt += f"  {r['label_conf']:.0%}"
            ax.text(X_TIER, y, tier_txt, color=col, fontsize=9, va="center", zorder=2)
        else:
            ax.text(X_DC, y, "—", color=MUTED, fontsize=9, va="center", zorder=2)

        y -= row_h

    # legend
    y -= 0.05
    ax.plot([X_ACTION, 98], [y + 0.22, y + 0.22], color=GRID, lw=1.0)
    low = sum(1 for r in rows if r["skill_conf"] is not None and r["skill_conf"] < 0.50)
    legend = "DC = 5 + 5 × score   ·   ● ≥75%  ● ≥50%  ● <50% skill confidence"
    if low:
        legend += f"   ·   ⚠ {low} ambiguous action(s)"
    ax.text(X_ACTION, y - 0.05, legend, color=MUTED, fontsize=8, va="center")

    fig.savefig(path, dpi=dpi, facecolor=BG, bbox_inches="tight", pad_inches=0.25)
    plt.close(fig)
    print(f"wrote {path}")
    return path


if __name__ == "__main__":
    main()
