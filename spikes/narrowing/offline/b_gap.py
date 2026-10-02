"""B. Top-two gap of every deciding Choice of the recorded r2b pastes; hits vs misses; threshold table."""
import common as C

pastes = [p for p in C.load() if p["cell"] != "N04_too_big"]
rows = []
for p in pastes:
    r = C.replay(p, C.jev_rule)
    sig = []
    for piece, dec, ch in r["steps"]:
        ps = sorted(ch.probs.values(), reverse=True) + [0.0]
        p1, p2 = ps[0], ps[1]
        sig.append(dict(p1=p1, p2=p2, gap=p1 - p2, ratio=(p2 / p1 if p1 else 1.0), conf=ch.confidence))
    last = sig[-1]
    weak = dict(p1=min(s["p1"] for s in sig), gap=min(s["gap"] for s in sig), ratio=max(s["ratio"] for s in sig),
                conf=min(s["conf"] for s in sig if s["conf"] is not None))
    c = C.cell(p["cell"])
    rows.append(dict(cell=p["cell"], run=p["run"], group=C.group(p["cell"]), hit=p["hit"], last=last, weak=weak,
                     borderline=bool(c["borderline"])))

print("## B every miss, and hits with a weak last step")
print("| cell | run | group | result | last p1 | p2 | p1−p2 | p2/p1 | conf | weakest p1 | weakest gap | weakest conf |")
print("|---|---|---|---|---|---|---|---|---|---|---|---|")
for x in rows:
    L, W = x["last"], x["weak"]
    if not x["hit"] or L["gap"] < 0.1:
        print("| %s | %d | %s | %s | %.2f | %.2f | %.2f | %.2f | %s | %.2f | %.2f | %.2f |" % (
            x["cell"], x["run"], x["group"], "hit" if x["hit"] else "MISS", L["p1"], L["p2"], L["gap"], L["ratio"],
            "%.2f" % L["conf"] if L["conf"] is not None else "–", W["p1"], W["gap"], W["conf"]))

hits = [x for x in rows if x["hit"]]
miss = [x for x in rows if not x["hit"]]
print("\nhits %d (round-1 %d, held-out %d), misses %d" % (len(hits), sum(x["group"] == "round-1" for x in hits),
                                                         sum(x["group"] == "held-out" for x in hits), len(miss)))
for which in ("last", "weak"):
    print("\n## B thresholds, signal = %s deciding step (flag = below; p2/p1: at or above)" % (
        "the last" if which == "last" else "the weakest"))
    print("| signal | threshold | hits flagged (round-1 / held-out) | misses flagged (of %d) |" % len(miss))
    print("|---|---|---|---|")
    grid = [("p1", (0.3, 0.4, 0.5, 0.6, 0.7), lambda v, t: v < t), ("gap", (0.05, 0.1, 0.2, 0.3, 0.4), lambda v, t: v < t),
            ("ratio", (0.33, 0.5, 0.75, 0.9), lambda v, t: v >= t), ("conf", (0.3, 0.4, 0.5, 0.6, 0.7), lambda v, t: v < t)]
    for key, ts, flag in grid:
        for t in ts:
            f = lambda x: x[which][key] is not None and flag(x[which][key], t)  # noqa: E731
            fh = [x for x in hits if f(x)]
            fm = [x for x in miss if f(x)]
            print("| %s | %s | %d (%d / %d) | %d (%s) |" % (
                {"p1": "p1", "gap": "p1 − p2", "ratio": "p2 / p1", "conf": "confidence"}[key],
                ("< %.2f" if key != "ratio" else "≥ %.2f") % t, len(fh), sum(x["group"] == "round-1" for x in fh),
                sum(x["group"] == "held-out" for x in fh), len(fm),
                ", ".join(sorted({"%s" % x["cell"].split("_")[0] for x in fm}))))

print("\n## B thresholds combined: hits flagged (round-1 / held-out) · misses flagged of %d" % len(miss))
print("| signal | flag when | last step: hits | last: misses | weakest step: hits | weakest: misses |")
print("|---|---|---|---|---|---|")
grid = [("p1", (0.3, 0.4, 0.5, 0.6, 0.7), lambda v, t: v < t), ("gap", (0.05, 0.1, 0.2, 0.3, 0.4), lambda v, t: v < t),
        ("ratio", (0.33, 0.5, 0.75, 0.9), lambda v, t: v >= t), ("conf", (0.3, 0.4, 0.5, 0.6, 0.7), lambda v, t: v < t)]
for key, ts, flag in grid:
    for t in ts:
        cells = []
        for which in ("last", "weak"):
            f = lambda x: x[which][key] is not None and flag(x[which][key], t)  # noqa: E731
            fh = [x for x in hits if f(x)]
            fm = [x for x in miss if f(x)]
            cells += ["%d (%d / %d)" % (len(fh), sum(x["group"] == "round-1" for x in fh), sum(x["group"] == "held-out" for x in fh)),
                      "%d %s" % (len(fm), ",".join(sorted({x["cell"].split("_")[0] for x in fm})))]
        print("| %s | %s | %s |" % ({"p1": "p1", "gap": "p1 − p2", "ratio": "p2 / p1", "conf": "confidence"}[key],
                                   ("< %.2f" if key != "ratio" else "≥ %.2f") % t, " | ".join(cells)))
