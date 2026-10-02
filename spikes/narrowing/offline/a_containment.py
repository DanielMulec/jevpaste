"""A. Containment mass: A0 (Jev's choice) vs A1(tau), replayed over the recorded r2b pastes."""
import collections
import common as C


def occurrences(hay, needle):
    h, n = hay.encode(), needle.encode()
    out, i = [], h.find(n)
    while i >= 0:
        out.append((i, i + len(n)))
        i = h.find(n, i + 1)
    return out


def masses(ch):
    pieces = ch.pieces()
    occ = {t: occurrences(ch.piece, t) for t, _ in pieces}
    m = {}
    for t, _ in pieces:
        m[t] = sum(q for u, q in pieces
                   if any(a >= s and b <= e for a, b in occ[u] for s, e in occ[t]))
    keep = ch.p_of("keep") + sum(q for _, q in pieces)
    first = {t: (occ[t][0][0] if occ[t] else 10 ** 9) for t, _ in pieces}
    return m, keep, first


def a1(tau):
    def rule(ch):
        j = ch.meaning(ch.choice)
        if j in (C.NOTHING, C.ASK):
            return j
        m, _, first = masses(ch)
        cands = [t for t in m if m[t] >= tau - 1e-9]
        if not cands:
            return "keep"
        return min(cands, key=lambda t: (len(t.encode()), -m[t], first[t]))
    return rule


RULES = [("A0", C.jev_rule)] + [("A1(%.1f)" % t, a1(t)) for t in (0.5, 0.6, 0.7)]

pastes = [p for p in C.load() if p["cell"] != "N04_too_big"]
base = {(p["cell"], p["run"]): C.replay(p, C.jev_rule) for p in pastes}
summary = collections.OrderedDict()
changes = []
for name, rule in RULES:
    for p in pastes:
        g = C.group(p["cell"])
        r = C.replay(p, rule)
        s = summary.setdefault((name, g), collections.Counter())
        s["pastes"] += 1
        b = base[(p["cell"], p["run"])]
        bhit = C.score(p, b)
        if r["known"]:
            s["known hit" if C.score(p, r) else "known miss"] += 1
            if C.score(p, r) != bhit:
                s["fixed" if C.score(p, r) else "broken"] += 1
        else:
            s["unknown " + r["stop_class"]] += 1
            s["unknown (A0 %s)" % ("hit" if bhit else "miss")] += 1
        if name != "A0" and [d for _, d, _ in r["steps"]] != [d for _, d, _ in b["steps"]]:
            first = next(i for i, (x, y) in enumerate(zip([d for _, d, _ in r["steps"]] + [None] * 9,
                                                            [d for _, d, _ in b["steps"]] + [None] * 9)) if x != y)
            piece, dec, ch = r["steps"][first]
            changes.append((name, p["cell"], p["run"], g, b, r, first, piece, dec, ch, C.score(p, b)))

print("## A summary")
print("| rule | group | pastes | known hit | known miss | fixed vs A0 | broken vs A0 | unknown: step exact / path / miss | unknown where A0 hit / missed |")
print("|---|---|---|---|---|---|---|---|---|")
for (name, g), s in summary.items():
    print("| %s | %s | %d | %d | %d | %d | %d | %d / %d / %d | %d / %d |" % (
        name, g, s["pastes"], s["known hit"], s["known miss"], s["fixed"], s["broken"], s["unknown exact"],
        s["unknown path"], s["unknown miss"], s["unknown (A0 hit)"], s["unknown (A0 miss)"]))

print("\n## A changes vs A0 (first differing step)")
print("| rule | cell | run | group | A0 result | A0 | step | Jev pick (p) | rule pick | rule result |")
print("|---|---|---|---|---|---|---|---|---|---|")
for name, cell, run, g, b, r, i, piece, dec, ch, bhit in changes:
    jp = ch.meaning(ch.choice)
    jtxt = "keep" if jp == "keep" else C.short(jp, 22)
    dtxt = "keep" if dec == "keep" else C.short(dec, 22)
    if r["known"]:
        res = ("hit " if C.r2.score(C.cell(cell), r["outcome"], r["final"]) else "MISS ") + (
            C.short(r["final"], 22) if r["outcome"] == "paste" else r["outcome"])
    else:
        res = "unknown; step %s" % r["stop_class"]
    a0 = (C.short(b["final"], 22) if b["outcome"] == "paste" else b["outcome"])
    print("| %s | %s | %d | %s | %s | %s | %d | %s (%.2f) | %s | %s |" % (
        name, cell, run, g, "hit" if bhit else "MISS", a0, i + 1, jtxt, ch.probs.get(ch.choice, 0), dtxt, res))

# the four known misses: masses at their deciding steps
print("\n## Masses at the known misses' step 1 deciding choice (top 5 by mass among pieces)")
for p in pastes:
    if p["cell"] in ("C03_availability", "C04_name", "R10_description", "B06_biography"):
        ch = C.replay(p, C.jev_rule)["steps"][0][2]
        m, keep, _ = masses(ch)
        top = sorted(m.items(), key=lambda kv: -kv[1])[:5]
        print(p["cell"], "r%d" % p["run"], "keep-mass %.2f" % keep, "p_keep %.2f" % ch.p_of("keep"),
              "p_nothing %.2f" % ch.p_of(C.NOTHING), "|", "; ".join("%s m=%.2f p=%.2f" % (
                  C.short(t, 24), v, dict(ch.pieces())[t]) for t, v in top))

# compact: every paste changed by any A1 rule, one column per rule
print("\n## A compact: every paste that any A1 rule changes")
print("`=` unchanged · `hit` / `MISS` full paste known · `?exact` / `?path` / `?miss` full paste unknown, deciding step class")
print("| cell | run | group | A0 | A1(0.5) | A1(0.6) | A1(0.7) |")
print("|---|---|---|---|---|---|---|")
cells_changed = sorted({(c[1], c[2]) for c in changes}, key=lambda k: (C.ORDER.index(k[0]), k[1]))
byname = {(name, c, r): (rr, bh) for name, c, r, g, b, rr, i, piece, dec, ch, bh in changes}
for cid, run in cells_changed:
    p = next(x for x in pastes if x["cell"] == cid and x["run"] == run)
    b = base[(cid, run)]
    cols = []
    for name, _ in RULES[1:]:
        if (name, cid, run) not in byname:
            cols.append("=")
            continue
        rr, _ = byname[(name, cid, run)]
        cols.append(("hit" if C.score(p, rr) else "**MISS**") if rr["known"] else "?" + rr["stop_class"])
    print("| %s | %d | %s | %s | %s |" % (cid, run, C.group(cid), "hit" if C.score(p, b) else "**MISS**", " | ".join(cols)))
