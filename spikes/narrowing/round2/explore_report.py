"""Exploration tables (D1-D4) from results/raw.jsonl (phase "explore") -> results/explore.md and stdout.
Only round-1 cells were used for exploration; the held-out cells never appear here."""

import json
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import r2  # noqa: E402

OUT = os.path.join(HERE, "results", "explore.md")
KEEPS = ("keep", "everything")


def short(t, n=26):
    if t is None:
        return "∅"
    t = t.replace("\n", "⏎")
    return "`%s`" % (t if len(t) <= n else t[:n] + "…")


def expected_class(cell):
    if cell["outcome"] in ("nothing", "ask"):
        return cell["outcome"]
    return "everything" if cell["expected"] == cell["item"] or cell["item"] in cell["accept"] else "one_part"


def step1_verdict(cell, res):
    """exact: the step-1 decision is the final answer (value / keep / nothing / ask);
    path: it is a strictly smaller piece that still contains the expected excerpt (Narrowing can go on)."""
    choice, text = res.get("choice"), res.get("choice_text")
    targets = ([cell["expected"]] if cell["expected"] else []) + cell["accept"]
    if cell["outcome"] == "nothing":
        return "exact" if choice == r2.NOTHING else "miss"
    if cell["outcome"] == "ask":
        return "exact" if choice == r2.ASK else "miss"
    if choice in KEEPS:
        return "exact" if cell["item"] in targets or cell["item"].strip("\r\n") in targets else "miss"
    if text is None:
        return "miss"
    if text in targets:
        return "exact"
    if any(t in text for t in targets) and text != cell["item"]:
        return "path"
    return "miss"


def pick_text(res):
    c = res.get("choice")
    if c in KEEPS:
        return "everything"
    if c in (r2.NOTHING, r2.ASK):
        return c
    return short(res.get("choice_text"))


def main():
    rows = [r for r in r2.rows() if r.get("phase") == "explore"]
    out = []
    w = out.append
    screens = [r for r in rows if r["kind"] == "screen"]
    calls = [r for r in rows if r["kind"] == "call"]
    pastes = [r for r in rows if r["kind"] == "paste"]
    tuned = sorted({r["cell"] for r in rows if r.get("cell")})
    w("# Exploration (round-1 cells only)\n")
    w("Billed exploration calls: %d (budget 150). Cells tuned on (%d): %s.\n" % (
        sum(1 for c in calls if c.get("billed")), len(tuned), ", ".join(tuned)))

    # ------------------------------------------------------------------ D3 wordings (screen, step 1 decision)
    w("## D3 wordings: the step-1 decision per variant (screen)\n")
    w("`exact` = the decision is the final answer; `path` = a smaller piece that still contains it; ✗ = miss. "
      "Design column: `base` = K=8 fine runs, document-order choices, full-text options.\n")
    variants = sorted({v for s in screens for v in s["results"]})
    by = {}
    for s in screens:
        for v, res in s["results"].items():
            if "choice" in res:
                by.setdefault((s["cell"], s["design"], v), []).append(res)
    cells_seen = sorted({k[0] for k in by}, key=lambda c: [x["id"] for x in r2.ALL_CELLS].index(c))
    designs = sorted({k[1] for k in by})
    for d in designs:
        vs = [v for v in variants if any(k[1] == d and k[2] == v for k in by)]
        w("### design `%s`\n" % d)
        w("| cell | expected | " + " | ".join(vs) + " |")
        w("|---|---|" + "---|" * len(vs))
        tally = {v: [0, 0, 0] for v in vs}
        for c in cells_seen:
            if not any(k[0] == c and k[1] == d for k in by):
                continue
            cell = r2.BY_ID[c]
            exp = cell["outcome"] if cell["outcome"] != "paste" else short(cell["expected"])
            row = []
            for v in vs:
                rs = by.get((c, d, v))
                if not rs:
                    row.append("")
                    continue
                cellres = []
                for res in rs:
                    ver = step1_verdict(cell, res)
                    tally[v][0 if ver == "exact" else 1 if ver == "path" else 2] += 1
                    cellres.append("%s %s %.2f" % ({"exact": "✅", "path": "↘", "miss": "✗"}[ver], pick_text(res),
                                                   res.get("p") or 0))
                row.append("<br>".join(cellres))
            w("| %s | %s | %s |" % (c, exp, " | ".join(row)))
        w("| **total** exact / path / miss | | %s |" % " | ".join("%d / %d / %d" % tuple(tally[v]) for v in vs))
        w("")

    # ------------------------------------------------------------------ D4 place choice
    w("## D4 place choice: argmax per wording (screen + runs)\n")
    w("Expected class: whole-copy cells → everything, traps → nothing, all others (incl. ask cells) → one_part.\n")
    pw_all = ["P1", "P2", "P3", "P4"]
    tally = {p: [0, 0] for p in pw_all}
    w("| cell | expected | " + " | ".join(pw_all) + " |")
    w("|---|---|" + "---|" * len(pw_all))
    for c in cells_seen:
        cell = r2.BY_ID[c]
        ec = expected_class(cell)
        row = []
        for p in pw_all:
            vals = [s["place"].get(p) for s in screens if s["cell"] == c and s["place"].get(p)]
            txt = []
            for pr in vals:
                top = max(pr, key=pr.get)
                ok = top == ec
                tally[p][0] += ok
                tally[p][1] += 1
                txt.append("%s %s %.2f" % ("✅" if ok else "✗", top, pr[top]))
            row.append("<br>".join(txt))
        w("| %s | %s | %s |" % (c, ec, " | ".join(row)))
    w("| **correct** | | %s |" % " | ".join("%d/%d" % tuple(tally[p]) for p in pw_all))
    w("")

    # ------------------------------------------------------------------ D2 option form: tokens and latency
    w("## D2 option form: input tokens and latency per request\n")
    w("Same wording (V5); `ids` = pieces held once in `state.excerpts`, options id-only (`null` descriptions); "
      "`full` = every option carries its text.\n")
    w("| cell | request | full: questions / tokens / ms | ids: questions / tokens / ms |")
    w("|---|---|---|---|")
    single = {}
    for c in calls:
        if c.get("sub") == "screen" and c.get("variants") == ["V5"]:
            u = (c["response"].get("usage") if isinstance(c["response"], dict) else None) or {}
            form = "ids" if "form=ids" in c["design"] else "full"
            single.setdefault((c["cell"], "screen step 1 (+4 place questions)", form), []).append(
                (c["questions_n"], u.get("inputTokens"), c["latency_ms"]))
    for c in calls:
        if c.get("sub") in ("step", "follow_up") and c.get("design") in ("r2", "r2+form=full+layout=doc"):
            u = (c["response"].get("usage") if isinstance(c["response"], dict) else None) or {}
            form = "ids" if "excerpts" in c["request"]["state"] else "full"
            single.setdefault((c["cell"], "run %s %s step %d" % (c["design"], c["sub"], c["step"]), form), []).append(
                (c["questions_n"], u.get("inputTokens"), c["latency_ms"]))
    keys = sorted({(k[0], k[1]) for k in single})
    for cell, req in keys:
        f = single.get((cell, req, "full"), [])
        i = single.get((cell, req, "ids"), [])
        fmt = lambda xs: "<br>".join("%d / %s / %.0f" % x for x in xs) or "–"  # noqa: E731
        w("| %s | %s | %s | %s |" % (cell, req, fmt(f), fmt(i)))
    w("")

    # ------------------------------------------------------------------ full pipeline runs
    w("## Full Narrowing runs (explore)\n")
    w("| design | cell | A | B | outcome | calls | ms | place (every / part / nothing) | steps |")
    w("|---|---|---|---|---|---|---|---|---|")
    for p in pastes:
        pp = (p.get("place") or {}).get("probabilities") or {}
        steps = " › ".join("%s (%d%s, %.2f)" % (
            s.get("choice") if s.get("choice") in ("keep", r2.NOTHING, r2.ASK) else short(s.get("choice_text"), 18),
            s["options"], "/%d" % s["choices"] if s.get("choices", 1) > 1 else "", s.get("p") or 0)
            for s in p["steps"])
        w("| %s | %s | %s | %s | %s | %d | %.0f | %.2f / %.2f / %.2f | %s |" % (
            p["design"], p["cell"], "✅" if p["hit"] else "❌", "✅" if p["b_hit"] else "❌",
            short(p["final"]) if p["outcome"] == "paste" else p["outcome"], p["calls"], p["latency_ms"],
            pp.get("everything", 0), pp.get("one_part", 0), pp.get("nothing", 0), steps))
    for d in sorted({p["design"] for p in pastes}):
        ps = [p for p in pastes if p["design"] == d]
        lat = [p["latency_ms"] for p in ps]
        w("\n- `%s`: A %d/%d, B %d/%d; calls mean %.2f; latency median %.0f ms, max %.0f ms." % (
            d, sum(p["hit"] for p in ps), len(ps), sum(p["b_hit"] for p in ps), len(ps),
            statistics.mean(p["calls"] for p in ps), statistics.median(lat), max(lat)))
    w("")
    text = "\n".join(out)
    with open(OUT, "w") as handle:
        handle.write(text + "\n")
    print(text)


if __name__ == "__main__":
    main()
