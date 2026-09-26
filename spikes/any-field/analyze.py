"""Summarise results/raw.jsonl for the any-field spike. Prints Markdown; `python3 analyze.py > results/report.md`."""

import json
import os
import statistics
from collections import Counter, defaultdict

import fixtures
import spans

HERE = os.path.dirname(os.path.abspath(__file__))
RAW_PATH = os.path.join(HERE, "results", "raw.jsonl")
MATRIX_RUNS = (0, 1)
MATRIX_VARIANT = "v7"
GATE = 0.5

# Pass-criteria scope: the fields the brief lists for these three items (supervisor additions R08-R10 are reported
# but outside the fixed criteria).
CRITERIA_CELLS = (
    ["A%02d" % i for i in range(1, 13)] + ["S%02d" % i for i in range(1, 9)] + ["R%02d" % i for i in range(1, 7)]
)


def rows():
    with open(RAW_PATH) as handle:
        return [json.loads(line) for line in handle if line.strip()]


def short(text, n=34):
    if text is None:
        return "∅ (none)"
    text = text.replace("\n", "⏎")
    return "`%s`" % (text if len(text) <= n else text[: n - 1] + "…")


def pct(values, q):
    values = sorted(values)
    if not values:
        return float("nan")
    k = (len(values) - 1) * q
    lo, hi = int(k), min(int(k) + 1, len(values) - 1)
    return values[lo] + (values[hi] - values[lo]) * (k - lo)


def lat(values):
    if not values:
        return "–"
    return "n=%d, median %.0f ms, p90 %.0f ms, max %.0f ms" % (
        len(values), statistics.median(values), pct(values, 0.9), max(values))


def acceptable(cell):
    return [t for t in [cell["expected"]] + cell["accept"] if t is not None]


def whole_expected(cell, item_id):
    """True when some acceptable excerpt is itself a structural Candidate (gate should stay low)."""
    candidates = spans.derive(fixtures.ITEMS[item_id])
    return any(t in candidates for t in acceptable(cell))


def reachability(cell, item_id):
    """(status, reason) of the expected excerpt; a listed accept is noted when the expected one is not a span."""
    status, reason = _reachability(cell, item_id, [cell["expected"]])
    if status not in ("whole Candidate", "span") and cell["accept"]:
        alt, _ = _reachability(cell, item_id, cell["accept"])
        status += " (accept: %s)" % alt
    return status, reason


def _reachability(cell, item_id, texts):
    item = fixtures.ITEMS[item_id]
    candidates = spans.derive(item)
    if any(t in candidates for t in texts):
        return "whole Candidate", ""
    if any(t in spans.spans(c)[0] for c in candidates for t in texts):
        return "span", ""
    t = cell["expected"]
    at = item.find(t)
    reasons = []
    for pos, side in ((at - 1, "before"), (at + len(t), "after")):
        if 0 <= pos < len(item):
            ch = item[pos]
            if not ch.isspace() and ch not in spans.SPAN_DELIMITERS:
                reasons.append("no cut %s: `%s`" % (side, ch))
    if len(spans.tokens(t)) > spans.MAX_SPAN_TOKENS:
        reasons.append("%d tokens > %d" % (len(spans.tokens(t)), spans.MAX_SPAN_TOKENS))
    # with stage 3: a substring of a single-token span of some Candidate (options <= 254 after the cap)
    import stage3
    for c in candidates:
        for s in spans.spans(c)[0]:
            if len(spans.tokens(s)) == 1 and any(t in stage3.substrings(s)[0] for t in texts):
                return "stage-3 substring of `%s`" % s, "; ".join(reasons)
    return "UNREACHABLE", "; ".join(reasons) + " (and not inside one token)"


def report():
    data = rows()
    cells = {c["id"]: (item_id, c) for item_id, c in fixtures.all_cells()}
    results = defaultdict(dict)  # cell -> run -> j_result
    for r in data:
        if r.get("kind") == "j_result" and r.get("run") in MATRIX_RUNS and r.get("variant") == MATRIX_VARIANT:
            results[r["cell"]][r["run"]] = r
    out = []
    p = out.append

    # ------------------------------------------------------------------ per-cell table
    p("## Per-cell results (Engine J, gate %s, threshold %.1f)\n" % (MATRIX_VARIANT, GATE))
    p("Hit = final pasted text byte-equal to the expected excerpt (or a listed accept). `J` = J's own answer; "
      "`prod` = after production's free_text ≥ 0.8 override (whole item). s1 = stage-1 choice (prob), "
      "more = `contains_more` P(true), free = `free_text` P(true), s2 = stage-2 span (prob, spans offered).\n")
    p("| cell | field | expected | run | s1 (prob) | more | free | s2 (prob, #spans) | J | prod | noise |")
    p("|---|---|---|---|---|---|---|---|---|---|---|")
    for cid, (item_id, cell) in cells.items():
        for run in MATRIX_RUNS:
            r = results[cid].get(run)
            if r is None:
                p("| %s | %s | %s | %d | (not run) |||||||" % (cid, cell["field_label"], short(cell["expected"]), run))
                continue
            s2 = "–"
            if r["stage2_ran"]:
                s2 = "%s (%.2f, %d)" % (short(r["stage2_text"], 26), r["stage2_prob"] or 0, r["span_count"])
                if not r.get("stage2_in_production", True):
                    s2 += " †"
            noise = r.get("chooser_noise", r.get("stage1_chooser_noise", 0))
            p("| %s%s | %s | %s | %d | %s (%.2f) | %.2f | %.2f | %s | %s | %s | %s |" % (
                cid, " ⚠" if cell["borderline"] else "", cell["field_label"], short(cell["expected"]), run,
                short(r["stage1_text"], 26), r["stage1_prob"] or 0, r["contains_more"] or 0, r["free_text"] or 0,
                s2, "✅" if r["j_hit"] else "❌", "✅" if r["hit"] else "❌ %s" % short(r["final"], 22),
                noise or ""))
    p("\n⚠ = borderline cell (see fixtures). † = stage 2 would not run in production (free_text override).\n")

    # ------------------------------------------------------------------ hit counts
    p("## Hit counts\n")
    by_item = defaultdict(lambda: Counter())
    for cid, (item_id, cell) in cells.items():
        for run in MATRIX_RUNS:
            r = results[cid].get(run)
            if r is None:
                continue
            c = by_item[item_id]
            c["obs"] += 1
            c["j"] += r["j_hit"]
            c["prod"] += r["hit"]
            c["s1"] += bool(r["stage1_hit"])
    p("| item | observations | J hits | production hits | stage-1 choice already the excerpt |")
    p("|---|---|---|---|---|")
    total = Counter()
    for item_id, c in by_item.items():
        p("| %s | %d | %d | %d | %d |" % (item_id, c["obs"], c["j"], c["prod"], c["s1"]))
        total.update(c)
    p("| **all** | %d | %d | %d | %d |\n" % (total["obs"], total["j"], total["prod"], total["s1"]))

    # ------------------------------------------------------------------ pass criteria
    p("## Pass criteria (fixed by Daniel)\n")
    misses = []
    for cid, (item_id, cell) in cells.items():
        if cid[:3] not in CRITERIA_CELLS:
            continue
        for run in MATRIX_RUNS:
            r = results[cid].get(run)
            if r is None or not r["hit"]:
                misses.append((cid, run, r))
    p("1. Address, signature, résumé — every listed field, both runs: **%s** (%d misses of %d)." % (
        "PASS" if not misses else "FAIL", len(misses), 2 * len([c for c in cells if c[:3] in CRITERIA_CELLS])))
    for cid, run, r in misses:
        if r is None:
            p("   - %s run %d: not run" % (cid, run))
        else:
            p("   - %s run %d: pasted %s via %s (expected %s)%s" % (
                cid, run, short(r["final"], 60), r["path"], short(r["expected"], 40),
                "; borderline" if r["borderline"] else ""))
    gate_rows = []
    for cid, (item_id, cell) in cells.items():
        if cell["expected"] is None:
            continue
        should_fire = not whole_expected(cell, item_id)
        for run in MATRIX_RUNS:
            r = results[cid].get(run)
            if r is None or r["contains_more"] is None:
                continue
            gate_rows.append((cid, run, should_fire, r["contains_more"] >= GATE, r["contains_more"]))
    table = Counter((s, f) for _, _, s, f, _ in gate_rows)
    off = [g for g in gate_rows if g[2] != g[3]]
    p("2. `contains_more` fires correctly on every cell: **%s** (%d wrong of %d observations)." % (
        "PASS" if not off else "FAIL", len(off), len(gate_rows)))
    for cid, run, should, fired, prob in off:
        p("   - %s run %d: P=%.2f, should %s" % (cid, run, prob, "fire" if should else "stay low"))
    negs = []
    for cid, (item_id, cell) in cells.items():
        if cell["expected"] is not None:
            continue
        for run in MATRIX_RUNS:
            r = results[cid].get(run)
            if r is not None:
                negs.append((cid, run, r))
    bad = [(c, run, r) for c, run, r in negs if not r["hit"]]
    p("3. Negative cells end in `none_of_these`/No Suitable Match: **%s** (%d of %d)." % (
        "PASS" if not bad else "FAIL", len(negs) - len(bad), len(negs)))
    for cid, run, r in bad:
        p("   - %s run %d: pasted %s via %s" % (cid, run, short(r["final"], 50), r["path"]))
    p("")

    # ------------------------------------------------------------------ 2x2
    p("## Gate 2×2 (positive cells, both runs; threshold %.1f)\n" % GATE)
    p("| | gate fired (≥ %.1f) | gate low |" % GATE)
    p("|---|---|---|")
    p("| needs a sub-span | %d | %d |" % (table[(True, True)], table[(True, False)]))
    p("| expected is a whole Candidate | %d | %d |\n" % (table[(False, True)], table[(False, False)]))
    fire = sorted(pr for _, _, s, _, pr in gate_rows if s)
    low = sorted(pr for _, _, s, _, pr in gate_rows if not s)
    p("P(contains_more) — needs sub-span: min %.2f, median %.2f; whole Candidate: max %.2f, median %.2f. "
      "Negatives (not in the 2×2): %s.\n" % (
          fire[0] if fire else float("nan"), statistics.median(fire) if fire else float("nan"),
          low[-1] if low else float("nan"), statistics.median(low) if low else float("nan"),
          ", ".join("%s r%d %.2f" % (c, run, r["contains_more"] or 0) for c, run, r in negs)))

    # ------------------------------------------------------------------ tuning history
    p("## Gate tuning history (before the v7 matrix)\n")
    tune = defaultdict(dict)
    for r in data:
        if r.get("kind") == "tune" or (r.get("kind") == "j_stage1" and r.get("run") == -1):
            v = r.get("variant") or "v1"
            tune[r["cell"]][v] = (r["response"].get("answers") or {}).get("contains_more", {}).get("probability")
    variants = ["v1", "v2", "v3", "v4", "v5", "v6"]
    p("P(contains_more) per wording; ▲ = should fire, ▽ = should stay low. v5/v6 withdrawn (named field types).\n")
    p("| cell | | " + " | ".join(variants) + " |")
    p("|---|---|" + "---|" * len(variants))
    for cid in sorted(tune):
        item_id, cell = cells[cid]
        arrow = "▲" if not whole_expected(cell, item_id) else "▽"
        p("| %s | %s | %s |" % (cid, arrow, " | ".join(
            "%.2f" % tune[cid][v] if tune[cid].get(v) is not None else "" for v in variants)))
    p("")

    # ------------------------------------------------------------------ withdrawn v6 matrix + shadow stage 2
    v6 = {}
    for r in data:
        if r.get("kind") == "j_result" and r.get("variant") == "v6" and r.get("run") == 0:
            v6[r["cell"]] = r
    if v6:
        wrong = [c for c, r in v6.items() if cells[c][1]["expected"] is not None and r["contains_more"] is not None
                 and (r["contains_more"] >= GATE) == whole_expected(cells[c][1], cells[c][0])]
        p("## Withdrawn v6 matrix (run 0, %d cells before the stop)\n" % len(v6))
        p("J hits %d/%d, production hits %d/%d; gate wrong on %d: %s.\n" % (
            sum(r["j_hit"] for r in v6.values()), len(v6), sum(r["hit"] for r in v6.values()), len(v6),
            len(wrong), ", ".join(wrong)))
        shadow = [(c, r) for c, r in v6.items() if "shadow_stage2_text" in r]
        if shadow:
            p("Shadow stage 2 during that run (gate low, Candidate ≤ 12 tokens so it is offered whole among its "
              "spans; stage-2 wording has no field vocabulary, so this stays valid): would a gate-free J keep or "
              "cut the Candidate?\n")
            p("| cell | stage-1 Candidate | shadow span (prob) | shadow hit | J hit |")
            p("|---|---|---|---|---|")
            for cid, r in sorted(shadow):
                p("| %s | %s | %s (%.2f) | %s | %s |" % (
                    cid, short(r["stage1_text"], 30), short(r["shadow_stage2_text"], 30),
                    r["shadow_stage2_prob"] or 0, "✅" if r["shadow_hit"] else "❌", "✅" if r["j_hit"] else "❌"))
            p("")

    # ------------------------------------------------------------------ stage 3
    s3 = [r for r in data if r.get("kind") == "stage3_result"]
    if s3:
        p("## Stage 3 — recursive refinement below the token\n")
        p("| cell | start piece | level | gate P | options (before cap) | pick (prob) | stop | final | hit | calls/paste |")
        p("|---|---|---|---|---|---|---|---|---|---|")
        for r in s3:
            start = r["start"].get("stage2_text") or r["start"].get("stage1_text")
            for k, lv in enumerate(r["levels"] or [{}]):
                p("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                    r["cell"] if k == 0 else "", short(start, 26) if k == 0 else "", lv.get("level", "–"),
                    "%.2f" % lv["gate"] if lv.get("gate") is not None else "–",
                    "%d (%d)" % (lv["options"], lv["options_before_cap"]) if "options" in lv else "–",
                    "%s (%.2f)" % (short(lv["pick"], 20), lv["pick_prob"] or 0) if "pick" in lv else "–",
                    lv.get("stop", ""), short(r["final"], 20) if k == 0 else "",
                    ("✅" if r["hit"] else "❌") if k == 0 else "", r["calls_per_paste"] if k == 0 else ""))
        p("")
        lat3 = [lv[key] for r in s3 for lv in r["levels"] for key in ("gate_latency_ms", "choice_latency_ms")
                if lv.get(key)]
        p("Stage-3 call latency: %s.\n" % lat(lat3))

    # ------------------------------------------------------------------ reachability
    p("## Reachability (was the expected excerpt offered at all?)\n")
    p("Offline, from the item alone: every positive cell's expected excerpt (or a listed accept) is a whole "
      "Candidate, a span of some Candidate, or unreachable by the cut rules.\n")
    p("| cell | expected | reachable as | reason if not | offered in the run's stage 2 (r0/r1) |")
    p("|---|---|---|---|---|")
    unreachable = 0
    for cid, (item_id, cell) in cells.items():
        if cell["expected"] is None:
            continue
        status, reason = reachability(cell, item_id)
        unreachable += status.startswith("UNREACHABLE")
        offered = []
        for run in MATRIX_RUNS:
            r = results[cid].get(run)
            offered.append("–" if r is None or not r["stage2_ran"] else
                           ("yes" if any(t in (r.get("_offered") or []) for t in acceptable(cell))
                            or r.get("expected_offered") else "no"))
        p("| %s | %s | %s | %s | %s |" % (cid, short(cell["expected"], 30), status, reason, "/".join(offered)))
    counts = [r["span_count"] for cid in results for r in results[cid].values() if r["stage2_ran"]]
    ext = []
    for cid in results:
        for r in results[cid].values():
            if r["stage2_ran"]:
                ext.append(spans.spans(r["stage1_text"], delimiters=spans.EXTENDED_DELIMITERS)[0].__len__())
    p("\nUnreachable cells: **%d** (counted apart from Jev misses). Spans per stage-2 call: %s; the same parents "
      "with the extended cut set `@ . - _`: %s (both after the 254 cap).\n" % (
          unreachable,
          "min %d, median %d, max %d (n=%d)" % (min(counts), statistics.median(counts), max(counts), len(counts))
          if counts else "–",
          "min %d, median %d, max %d" % (min(ext), statistics.median(ext), max(ext)) if ext else "–"))
    extended = [r for r in data if r.get("kind") == "extended_result"]
    if extended:
        p("Extended cut set runs (`@ . - _`, one call each):\n")
        p("| cell | parent Candidate | spans (before cap) | expected offered | Jev pick (prob) | hit |")
        p("|---|---|---|---|---|---|")
        for r in extended:
            p("| %s | %s | %d (%d) | %s | %s (%.2f) | %s |" % (
                r["cell"], short(r["parent"], 30), r["span_count"], r["spans_before_cap"],
                "yes" if r["expected_offered"] else "no", short(r["text"], 26), r["prob"] or 0,
                "✅" if r["hit"] else "❌"))
        p("")

    # ------------------------------------------------------------------ latency
    p("## Latency (billed calls, client-side round trip)\n")
    kinds = defaultdict(lambda: {"cold": [], "warm": []})
    for r in data:
        if r.get("billed") and r.get("kind") in ("j_stage1", "j_stage2", "j_stage2_shadow", "tune", "jprime") \
                and "latency_ms" in r:
            kinds[r["kind"]]["cold" if r.get("cold") else "warm"].append(r["latency_ms"])
    p("| call | warm | cold |")
    p("|---|---|---|")
    for kind, v in kinds.items():
        p("| %s | %s | %s |" % (kind, lat(v["warm"]), lat(v["cold"])))
    per_paste = []
    per_paste_2 = []
    for cid in results:
        for r in results[cid].values():
            t = r["stage1_latency_ms"]
            if r["stage2_ran"] and r.get("stage2_in_production", True):
                t += r["stage2_latency_ms"]
                per_paste_2.append(t)
            per_paste.append(t)
    p("\nJ total per paste (production calls only): %s. Pastes that needed stage 2: %s.\n" % (
        lat(per_paste), lat(per_paste_2)))

    # ------------------------------------------------------------------ chooser noise
    p("## Chooser noise (same-type spans next to the stage-2 winner)\n")
    p("| cell | run | winner | type | other same-type spans |")
    p("|---|---|---|---|---|")
    any_noise = False
    for cid in results:
        for run, r in sorted(results[cid].items()):
            if r["stage2_ran"]:
                any_noise = True
                p("| %s | %d | %s | %s | %d %s |" % (cid, run, short(r["stage2_text"], 28), r["winner_type"] or "–",
                                                  r["chooser_noise"], " ".join(short(s, 24) for s in
                                                                               r["chooser_noise_spans"])))
            elif r.get("stage1_chooser_noise"):
                p("| %s | %d | %s (stage 1) | %s | %d %s |" % (
                    cid, run, short(r["stage1_text"], 28), spans.candidate_type(r["stage1_text"]) or "–",
                    r["stage1_chooser_noise"], " ".join(short(s, 24) for s in r["stage1_chooser_noise_candidates"])))
    if not any_noise:
        p("| – | | | | |")
    p("")

    # ------------------------------------------------------------------ J'
    jp = [r for r in data if r.get("kind") == "jprime_result"]
    if jp:
        p("## J′ (per-span boolean)\n")
        p("| cell | run | spans (questions) | top span (P) | runner-up | final | hit |")
        p("|---|---|---|---|---|---|---|")
        for r in jp:
            ru = r.get("runner_up")
            p("| %s | %d | %d | %s (%.2f) | %s | %s | %s |" % (
                r["cell"], r["run"], r["span_count"], short(r["top"], 26), r["top_prob"],
                "%s (%.2f)" % (short(ru[1], 20), ru[0]) if ru else "–", short(r["final"], 20),
                "✅" if r["hit"] else "❌"))
        p("")

    # ------------------------------------------------------------------ L
    lr = [r for r in data if r.get("kind") == "l_result"]
    if lr:
        p("## L rescue\n")
        p("| cell | model | route | status | answer | byte-exact substring | hit | latency |")
        p("|---|---|---|---|---|---|---|---|")
        for r in lr:
            p("| %s | %s | %s | %s | %s | %s | %s | %s |" % (
                r["cell"], r["model"], r["route"],
                (r["status"][:44] + "…") if len(r["status"]) > 45 else r["status"], short(r.get("answer"), 30),
                {True: "yes", False: "no", None: "–"}[r.get("verbatim")],
                {True: "✅", False: "❌", None: "–"}[r.get("hit")],
                "%.0f ms" % r["latency_ms"] if r.get("latency_ms") else "–"))
        p("")

    # ------------------------------------------------------------------ calls and cost
    p("## Calls and cost\n")
    billed = Counter(r["kind"] for r in data if r.get("billed"))
    jev_cost = sum(float(((r.get("response") or {}).get("providerMetadata") or {}).get("gateway", {}).get("cost", 0)
                         or 0) for r in data if r.get("billed"))
    tokens = sum(((r.get("response") or {}).get("usage") or {}).get("inputTokens", 0) for r in data if r.get("billed"))
    p("Billed Jev calls logged: %d (%s) + 3 smoke calls reported but not logged. Jev cost (Gateway metadata): "
      "$%.5f for %d input tokens.\n" % (sum(billed.values()), ", ".join("%s %d" % kv for kv in billed.items()),
                                          jev_cost, tokens))
    prod_calls = [r["production_calls"] for cid in results for r in results[cid].values()]
    if prod_calls:
        p("Production calls per paste (matrix): mean %.2f; pastes needing stage 2: %d of %d.\n" % (
            statistics.mean(prod_calls), sum(1 for c in prod_calls if c == 2), len(prod_calls)))
    print("\n".join(out))


if __name__ == "__main__":
    report()
