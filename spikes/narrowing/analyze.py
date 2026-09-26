"""Report for the Narrowing spike from results/raw.jsonl -> results/report.md (and stdout)."""

import json
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import cells  # noqa: E402

RAW = os.path.join(HERE, "results", "raw.jsonl")
REPORT = os.path.join(HERE, "results", "report.md")

WHOLE_CELLS = ["W01_chrome_textarea", "W02_terminal_prompt", "W03_chatgpt_composer", "W04_whatsapp_composer",
               "C05_notes_freetext"]
PARAGRAPH_CELLS = ["R05_about", "R08_summary", "R10_description"]
ASK_CELLS = ["T01_email_two_lines", "K01_three_emails"]
NEW_CELLS = ["N01_address_line_ort", "N02_url_chat", "N03_list_300_lines", "N04_too_big"]
TUNED = set()  # cells re-run with a tuned wording (none so far)


def load():
    with open(RAW) as handle:
        return [json.loads(line) for line in handle if line.strip()]


def short(text, n=34):
    if text is None:
        return "∅"
    text = text.replace("\n", "⏎")
    return "`%s`" % (text if len(text) <= n else text[:n] + "…")


def pct(values, q):
    values = sorted(values)
    if not values:
        return float("nan")
    k = (len(values) - 1) * q
    lo, hi = int(k), min(int(k) + 1, len(values) - 1)
    return values[lo] + (values[hi] - values[lo]) * (k - lo)


def shown(r):
    if r["outcome"] == "paste":
        return short(r["final"])
    if r["outcome"] == "ask":
        return "ask → [%s]" % ", ".join(short(t, 24) for t in (r["chooser"] or [])[:4])
    if r["outcome"] == "error":
        return "error %s" % ((r.get("error") or {}).get("status"))
    return r["outcome"]


def report():
    rows = load()
    pastes = [r for r in rows if r.get("kind") == "paste" and r["run"] in (0, 1)]
    # the latest record per (cell, run) counts (a retried error row is superseded)
    latest = {}
    for r in pastes:
        latest[(r["cell"], r["run"])] = r
    pastes = [latest[k] for k in sorted(latest, key=lambda k: ([c["id"] for c in cells.CELLS].index(k[0]), k[1]))]
    by_cell = {}
    for r in pastes:
        by_cell.setdefault(r["cell"], []).append(r)
    calls = [r for r in rows if r.get("kind") == "call"]
    out = []
    w = out.append

    def both(cid, pred):
        rs = by_cell.get(cid, [])
        return len(rs) == 2 and all(pred(r) for r in rs)

    # ---------------------------------------------------------------- criteria
    matrix = [c for c in cells.CELLS if c["group"] == "matrix"]
    positive = [c for c in matrix if c["outcome"] == "paste" and not c["borderline"]]
    borderline = [c for c in matrix if c["outcome"] == "paste" and c["borderline"]]
    traps = [c for c in matrix if c["outcome"] == "nothing"]
    c1_miss = [(c["id"], r["run"], shown(r)) for c in positive for r in by_cell.get(c["id"], []) if not r["hit"]]
    c1_bl = [(c["id"], r["run"], shown(r)) for c in borderline for r in by_cell.get(c["id"], []) if not r["hit"]]
    c2_miss = [(c["id"], r["run"], shown(r)) for c in traps for r in by_cell.get(c["id"], []) if not r["hit"]]
    c3_cells = WHOLE_CELLS + PARAGRAPH_CELLS
    c3_miss = [(cid, r["run"], shown(r)) for cid in c3_cells for r in by_cell.get(cid, []) if not r["hit"]]
    c4_miss = [(cid, r["run"], shown(r)) for cid in ASK_CELLS for r in by_cell.get(cid, []) if r["outcome"] != "ask"]
    c4_false = [(r["cell"], r["run"], shown(r)) for r in pastes if r["outcome"] == "ask" and r["cell"] not in ASK_CELLS]
    c5_bad = [(r["cell"], r["run"]) for r in pastes if not r["byte_exact"]]
    timed = [r for r in pastes if r["cell"] != "N04_too_big" and r["outcome"] != "error"]
    lat = [r["latency_ms"] for r in timed]
    c6_over = [(r["cell"], r["run"], r["latency_ms"]) for r in timed if r["latency_ms"] > 5000]
    c7 = {cid: [r for r in by_cell.get(cid, [])] for cid in NEW_CELLS}
    counted = lambda rs: sum(1 for r in rs if r["hit"])  # noqa: E731

    w("## Verdict against the 7 fixed criteria (both runs of every cell)\n")
    w("| # | criterion | result |")
    w("|---|---|---|")
    n1 = sum(len(by_cell.get(c["id"], [])) for c in positive)
    w("| 1 | every positive cell hits (borderline reported, not gating) | %s: %d/%d pastes hit; misses: %s. Borderline: %d/%d hit |" % (
        "PASS" if not c1_miss else "**FAIL**", n1 - len(c1_miss), n1,
        ", ".join("%s r%d → %s" % m for m in c1_miss) or "none",
        sum(len(by_cell.get(c["id"], [])) for c in borderline) - len(c1_bl),
        sum(len(by_cell.get(c["id"], [])) for c in borderline)))
    n2 = sum(len(by_cell.get(c["id"], [])) for c in traps)
    w("| 2 | every trap cell ends in No Suitable Match | %s: %d/%d trap pastes (%s)%s |" % (
        "PASS" if not c2_miss else "**FAIL**", n2 - len(c2_miss), n2, ", ".join(c["id"] for c in traps),
        "; misses: " + ", ".join("%s r%d → %s" % m for m in c2_miss) if c2_miss else ""))
    n3 = sum(len(by_cell.get(cid, [])) for cid in c3_cells)
    w("| 3 | whole copy in %s; paragraph in %s | %s: %d/%d%s |" % (
        ", ".join(WHOLE_CELLS), ", ".join(PARAGRAPH_CELLS), "PASS" if not c3_miss else "**FAIL**",
        n3 - len(c3_miss), n3, "; misses: " + ", ".join("%s r%d → %s" % m for m in c3_miss) if c3_miss else ""))
    w("| 4 | chooser opens on two and three emails (%s), nowhere else (incl. S04_phone, S05_mobile) | %s: opened %d/%d; asks elsewhere: %s%s |" % (
        ", ".join(ASK_CELLS), "PASS" if not (c4_miss or c4_false) else "**FAIL**",
        sum(len(by_cell.get(c, [])) for c in ASK_CELLS) - len(c4_miss), sum(len(by_cell.get(c, [])) for c in ASK_CELLS),
        ", ".join("%s r%d" % m[:2] for m in c4_false) or "none",
        "; not opened: " + ", ".join("%s r%d → %s" % m for m in c4_miss) if c4_miss else ""))
    w("| 5 | every paste byte-exact | %s: %d/%d |" % ("PASS" if not c5_bad else "**FAIL**", len(pastes) - len(c5_bad),
                                                   len(pastes)))
    w("| 6 | median < 2 s, nothing > 5 s (summed call latency per paste) | %s: median %.0f ms, p90 %.0f ms, max %.0f ms (n=%d)%s |" % (
        "PASS" if (statistics.median(lat) < 2000 and not c6_over) else "**FAIL**", statistics.median(lat),
        pct(lat, 0.9), max(lat), len(lat),
        "; over 5 s: " + ", ".join("%s r%d %.0f ms" % m for m in c6_over) if c6_over else ""))
    w("| 7 | new cells | %s |" % "; ".join("%s %d/%d (%s)" % (cid, counted(rs), len(rs), " / ".join(shown(r) for r in rs))
                                         for cid, rs in c7.items()))
    w("")

    # ---------------------------------------------------------------- per-cell table
    w("## Per-cell table\n")
    w("Steps: `pick (options[/choices], p)`, `keep` = the current piece unchanged. ⚠ = borderline (not gating), "
      "✎ = tuned.\n")
    w("| cell | expected | run | outcome | hit | calls | ms | steps | p(ask) max | p(nothing) max |")
    w("|---|---|---|---|---|---|---|---|---|---|")
    for c in cells.CELLS:
        for r in by_cell.get(c["id"], []):
            steps = " › ".join("%s (%d%s, %s)" % (
                "keep" if s.get("choice") == "keep" else (short(s.get("choice_text"), 22) if s.get("choice_text")
                                                           else s.get("choice")),
                s["options"], "/%d" % s["choices"] if s["choices"] > 1 else "",
                "%.2f" % s["p"] if s.get("p") is not None else "–") for s in r["steps"])
            pa = max([s.get("p_ask") or 0 for s in r["steps"]] or [0])
            pn = max([s.get("p_nothing") or 0 for s in r["steps"]] or [0])
            exp = {"nothing": "∅ (nothing)", "ask": "ask", "too_long": "too long"}.get(c["outcome"],
                                                                                       short(c["expected"], 26))
            w("| %s%s%s | %s | %d | %s | %s | %d | %.0f | %s | %.2f | %.2f |" % (
                c["id"], " ⚠" if c["borderline"] else "", " ✎" if c["id"] in TUNED else "", exp, r["run"], shown(r),
                "✅" if r["hit"] else "❌", r["calls"], r["latency_ms"], steps, pa, pn))
    w("")

    # ---------------------------------------------------------------- latency and calls
    billed = [c for c in calls if c.get("billed")]
    matrix_calls = [c for c in calls if c.get("run") in (0, 1)]
    per_call_warm = [c["latency_ms"] for c in matrix_calls if c["status"] == 200 and not c["cold"]]
    per_call_cold = [c["latency_ms"] for c in matrix_calls if c["status"] == 200 and c["cold"]]
    waits = [x for c in matrix_calls for x in c.get("waits", [])]
    wait_s = sum(x.get("slept_s") or 0 for x in waits)
    cost = 0.0
    tokens_in = 0
    for c in billed:
        resp = c.get("response")
        if isinstance(resp, dict):
            meta = ((resp.get("providerMetadata") or {}).get("gateway") or {})
            cost += float(meta.get("cost") or 0)
            tokens_in += (resp.get("usage") or {}).get("inputTokens") or 0
    w("## Latency, calls, cost\n")
    w("- Per paste (summed call latency, 429 waits excluded): n=%d, median %.0f ms, p90 %.0f ms, max %.0f ms." % (
        len(lat), statistics.median(lat), pct(lat, 0.9), max(lat)))
    for k in sorted({r["calls"] for r in timed}):
        ls = [r["latency_ms"] for r in timed if r["calls"] == k]
        w("  - %d call(s): n=%d, median %.0f ms, p90 %.0f ms, max %.0f ms" % (k, len(ls), statistics.median(ls),
                                                                          pct(ls, 0.9), max(ls)))
    w("- Per call: warm n=%d median %.0f ms, p90 %.0f ms; cold (first call of a process) n=%d median %.0f ms." % (
        len(per_call_warm), statistics.median(per_call_warm), pct(per_call_warm, 0.9), len(per_call_cold),
        statistics.median(per_call_cold) if per_call_cold else float("nan")))
    w("- Calls per paste (matrix, both runs): mean %.2f; distribution %s." % (
        statistics.mean(r["calls"] for r in pastes),
        ", ".join("%d×%d" % (k, sum(1 for r in pastes if r["calls"] == k)) for k in sorted({r["calls"] for r in pastes}))))
    w("- Retry waits (429/503, pacing excluded) during the matrix: %d waits, %.0f s in total." % (len(waits), wait_s))
    w("- Billed Jev calls for the whole spike: %d (budget 900); input tokens %d; Gateway cost $%.4f." % (
        len(billed), tokens_in, cost))
    carried_cut = [(r["cell"], r["run"], s["carried_cut"]) for r in pastes for s in r["steps"] if s.get("carried_cut")]
    w("- Follow-up carry list cut: %s." % (carried_cut or "never"))
    w("")
    text = "\n".join(out)
    with open(REPORT, "w") as handle:
        handle.write(text + "\n")
    print(text)


if __name__ == "__main__":
    report()
