"""D. Upstream (Gateway finalProvider) of every r2b paste's calls; criteria 1-4 per upstream; misses; run 0 vs run 1."""
import collections
import sys
import common as C

sys.path.insert(0, C.ROUND2)
import analyze_r2 as A  # noqa: E402  (cell sets of the r2b verdict)

pastes = C.load()
for p in pastes:
    p["ups"] = [C.provider(c) for c in p["calls"]]
    p["up"] = "typesafe-ai" if p["ups"] and all(u == "typesafe-ai" for u in p["ups"]) else (
        "any digitalocean" if "digitalocean" in p["ups"] else "no call")

SETS = {"round-1": (A.R1_WHOLE, A.R1_PARAGRAPH, A.R1_ASK, A.R1_NEW), "held-out": (A.H_WHOLE, A.H_PARAGRAPH, A.H_ASK, A.H_NEW)}
print("pastes by upstream:", dict(collections.Counter(p["up"] for p in pastes)))
print("calls by upstream:", dict(collections.Counter(u for p in pastes for u in p["ups"])))
print("\n## D criteria 1–4 per upstream (passing pastes / pastes)")
print("| group | upstream | 1 positives hit | 1b borderline hit | 2 traps → nothing | 3 whole / paragraph | 4 ask cells ask | 4b asks elsewhere |")
print("|---|---|---|---|---|---|---|---|")
for g, (whole, para, ask, new) in SETS.items():
    for up in ("typesafe-ai", "any digitalocean"):
        mine = [p for p in pastes if C.group(p["cell"]) == g and p["up"] == up]
        cell = lambda p: C.cell(p["cell"])  # noqa: E731
        pos = [p for p in mine if cell(p)["outcome"] == "paste" and not cell(p)["borderline"]
               and cell(p)["group"] in ("matrix", "heldout") and p["cell"] not in new + whole]
        bl = [p for p in mine if cell(p)["outcome"] == "paste" and cell(p)["borderline"] and cell(p)["group"] == "matrix"]
        tr = [p for p in mine if cell(p)["outcome"] == "nothing"]
        wp = [p for p in mine if p["cell"] in whole + para]
        ak = [p for p in mine if p["cell"] in ask]
        el = [p for p in mine if p["outcome"] == "ask" and p["cell"] not in ask]
        f = lambda xs: "%d/%d" % (sum(x["hit"] for x in xs), len(xs))  # noqa: E731
        print("| %s | %s | %s | %s | %s | %s | %s | %d |" % (g, up, f(pos), f(bl), f(tr), f(wp),
                                                          "%d/%d" % (sum(x["outcome"] == "ask" for x in ak), len(ak)), len(el)))

print("\n## D every miss with its upstreams")
print("| cell | run | group | pasted | calls: upstream per call (step / follow-up) |")
print("|---|---|---|---|---|")
for p in pastes:
    if not p["hit"]:
        print("| %s | %d | %s | %s | %s |" % (p["cell"], p["run"], C.group(p["cell"]),
                                            C.short(p["final"], 22) if p["outcome"] == "paste" else p["outcome"],
                                            ", ".join("%s:%s" % (c["sub"], C.provider(c)) for c in p["calls"]) or "–"))

print("\n## D cells whose run 0 and run 1 differ (outcome or pasted text)")
print("| cell | group | run 0 | upstreams r0 | run 1 | upstreams r1 |")
print("|---|---|---|---|---|---|")
by = collections.defaultdict(dict)
for p in pastes:
    by[p["cell"]][p["run"]] = p
show = lambda p: (C.short(p["final"], 22) if p["outcome"] == "paste" else p["outcome"]) + ("" if p["hit"] else " ✗")  # noqa: E731
n_diff = 0
for cid in C.ORDER:
    r = by.get(cid, {})
    if 0 in r and 1 in r and (r[0]["outcome"], r[0]["final"]) != (r[1]["outcome"], r[1]["final"]):
        n_diff += 1
        print("| %s | %s | %s | %s | %s | %s |" % (cid, C.group(cid), show(r[0]), ", ".join(r[0]["ups"]),
                                                  show(r[1]), ", ".join(r[1]["ups"])))
same_steps = sum(1 for cid in by if 0 in by[cid] and 1 in by[cid]
                 and [s.get("choice_text") for s in by[cid][0]["steps"]] != [s.get("choice_text") for s in by[cid][1]["steps"]])
print("\ncells with differing outcome: %d; cells whose step picks differ at all: %d" % (n_diff, same_steps))
