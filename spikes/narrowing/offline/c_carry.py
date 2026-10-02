"""C. Carry threshold, speculative width and tie order over every recorded r2b follow-up (offline; size model `cuts`)."""
import collections
import common as C

r2, cuts = C.r2, C.cuts
DESIGN = r2.design_of("r2b")
V = r2.VARIANTS[DESIGN["variant"]]
PER = r2.PIECES_PER_CHOICE


def carried(chunks, t, doc_ties=False, piece=None):
    """{text: max p} in carry order (as r2.carry), then sorted most likely first."""
    out = {}
    for ch in chunks:
        ranked = sorted(((p, oid) for oid, p in ch.probs.items()), key=lambda x: -x[0])  # stable: listing order
        for p, oid in ranked:
            m = ch.meaning(oid)
            if m in C.FIXED or m is None or p < t:
                continue
            out[m] = max(out.get(m, 0), p)
    if doc_ties:
        pos = lambda s: piece.encode().find(s.encode())  # noqa: E731
        return sorted(out, key=lambda s: (-out[s], pos(s))), out
    return sorted(out, key=lambda s: -out[s]), out


def speculation(cell, piece, order, w):
    cands = []
    for text in order[:w]:
        s_chunks, _ = r2.step_chunks(cell, DESIGN, text)
        if len(s_chunks) == 1 and s_chunks != [[]]:
            cands.append((text, s_chunks[0]))
    first = piece == cell["item"]
    fu_order = order[:PER]

    def build(form, spec):
        req = r2.Request(cell, form)
        req.add_choice("follow_up", V, piece, first, r2.doc_order(piece, fu_order))
        for i, (text, kids) in enumerate(spec):
            req.add_choice("spec_%d" % i, V, text, False, kids)
        return req
    for form, with_spec in (("ids", True), ("full", True), ("ids", False), ("full", False)):
        req = build(form, cands if with_spec else [])
        if req.fits():
            break
    spec = [t for t, _ in cands] if with_spec else []
    base = build(req.form, [])
    return spec, req.est()[0] - base.est()[0], req.form


pastes = [p for p in C.load() if p["cell"] != "N04_too_big"]
fus = []
for p in pastes:
    for sa in C.answers_of(p).values():
        if sa.follow_up is not None:
            fus.append((p, sa))
print("recorded follow-ups: %d (round-1 %d, held-out %d)" % (
    len(fus), sum(C.group(p["cell"]) == "round-1" for p, _ in fus), sum(C.group(p["cell"]) == "held-out" for p, _ in fus)))

# (a) carry
print("\n## C(a) carry threshold")
print("| carry ≥ | follow-ups whose pick is no longer carried | follow-up options: median / max | carried > 252 |")
print("|---|---|---|---|")
for t in (0.005, 0.01, 0.02, 0.05, 0.1):
    lost, sizes, over = [], [], 0
    for p, sa in fus:
        order, _ = carried(sa.chunks, t)
        sizes.append(min(len(order), PER) + 3)
        over += len(order) > PER
        pick = sa.follow_up.meaning(sa.follow_up.choice)
        if pick not in C.FIXED and pick not in order:
            lost.append("%s r%d" % (p["cell"], p["run"]))
    sizes.sort()
    print("| %s%s | %d%s | %d / %d | %d |" % (t, " (now)" if t == 0.01 else "", len(lost),
                                             (" (" + ", ".join(lost) + ")") if lost else "", sizes[len(sizes) // 2],
                                             sizes[-1], over))

# (b) width, and validation at w = 3
print("\n## C(b) speculative width (carry 0.01)")
print("| width | follow-ups with spec questions | pick's next step speculated (= call saved) | follow-ups picking a piece | tokens added: median / max | sent in full-text form |")
print("|---|---|---|---|---|---|")
valid = 0
for w in (1, 2, 3, 4, 5):
    n_spec = saved = piece_picks = fell = 0
    added = []
    for p, sa in fus:
        cell = C.cell(p["cell"])
        order, _ = carried(sa.chunks, 0.01)
        spec, extra, form = speculation(cell, sa.piece, order, w)
        if w == 3:
            rec = [q for q in sa.fu_call["request"]["questions"] if q.startswith("spec_")]
            recorded = [C.Choice(sa.fu_call, q).piece for q in rec]
            valid += recorded == spec
        n_spec += bool(spec)
        fell += form == "full"
        added.append(extra)
        pick = sa.follow_up.meaning(sa.follow_up.choice)
        if pick not in C.FIXED:
            piece_picks += 1
            saved += pick in spec
    added.sort()
    print("| %d%s | %d | %d | %d | %d / %d | %d |" % (w, " (now)" if w == 3 else "", n_spec, saved, piece_picks,
                                                      added[len(added) // 2], added[-1], fell))
print("\nvalidation: width 3 reproduces the recorded speculated list in %d of %d follow-ups" % (valid, len(fus)))

# (c) ties by document order
print("\n## C(c) ties broken by document order (width 3)")
diff_set, diff_saved, ties_top = 0, 0, 0
rows = []
for p, sa in fus:
    cell = C.cell(p["cell"])
    o1, m = carried(sa.chunks, 0.01)
    o2, _ = carried(sa.chunks, 0.01, doc_ties=True, piece=sa.piece)
    if o1[:3] != o2[:3]:
        ties_top += 1
    s1, _, _ = speculation(cell, sa.piece, o1, 3)
    s2, _, _ = speculation(cell, sa.piece, o2, 3)
    pick = sa.follow_up.meaning(sa.follow_up.choice)
    if set(s1) != set(s2):
        diff_set += 1
        a, b = pick in s1, pick in s2
        if a != b:
            diff_saved += 1
        rows.append("%s r%d: pick %s; speculated now %s → doc order %s" % (
            p["cell"], p["run"], "keep/nothing/ask" if pick in C.FIXED else C.short(pick, 18),
            "has pick" if a else "no pick", "has pick" if b else "no pick"))
print("follow-ups whose top-3 carried order changes: %d; speculated set changes: %d; pick's speculation status changes: %d"
      % (ties_top, diff_set, diff_saved))
for r in rows:
    print("- " + r)
