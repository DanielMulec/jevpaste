"""Round-2 matrix report from results/raw.jsonl (phase "matrix") -> results/report.md and stdout.

Policies: A = Narrowing alone; B = the place choice decides "everything" -> whole copy and "nothing" -> No Suitable
Match, "one part" -> Narrowing's result. Round-1 cells and held-out cells are scored separately."""

import json
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import r2  # noqa: E402

REPORT = os.path.join(HERE, "results", "report.md")
PHASE = "matrix2"
PHASES = ("matrix2", "matrix2-n03fix")  # the N03 re-run after the approved fallback fix supersedes its 400 rows

R1_WHOLE = ["W01_chrome_textarea", "W02_terminal_prompt", "W03_chatgpt_composer", "W04_whatsapp_composer",
            "C05_notes_freetext"]
R1_PARAGRAPH = ["R05_about", "R08_summary", "R10_description"]
R1_ASK = ["T01_email_two_lines", "K01_three_emails"]
R1_NEW = ["N01_address_line_ort", "N02_url_chat", "N03_list_300_lines", "N04_too_big"]
H_WHOLE = ["H04_issue_comment", "H05_messages_composer"]
H_PARAGRAPH = ["H06_company_description"]
H_ASK = ["H09_three_emails_webinar", "H10_three_emails_folio", "H11_two_emails_catering"]
H_NEW = ["H07_url_slack", "H08_url_teams"]  # URL into a chat box (the held-out counterpart of criterion 7's N02)
EXPECTATION_QUESTIONS = {"C03_availability": "the fixture expects the 2-line paragraph 3; the second line "
                                              "(`I am happy to relocate for the role.`) is not about availability"}
ORDER = [c["id"] for c in r2.ALL_CELLS]


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


def outcome_of(r, policy):
    return (r["outcome"], r["final"], r["hit"]) if policy == "A" else (r["b_outcome"], r["b_final"], r["b_hit"])


def shown(r, policy="A"):
    outcome, final, _ = outcome_of(r, policy)
    if outcome == "paste":
        return short(final)
    if outcome == "ask":
        return "ask → [%s]" % ", ".join(short(t, 24) for t in (r["chooser"] or [])[:4])
    if outcome == "error":
        return "error %s" % ((r.get("error") or {}).get("status"))
    return outcome


def load():
    rows = r2.rows()
    pastes = [r for r in rows if r.get("kind") == "paste" and r.get("phase") in PHASES and r["run"] in (0, 1)]
    latest = {}
    for r in pastes:
        latest[(r["cell"], r["run"])] = r  # a retried error row is superseded by the retry
    calls = [r for r in rows if r.get("kind") == "call" and r.get("phase") in PHASES]
    return rows, [latest[k] for k in sorted(latest, key=lambda k: (ORDER.index(k[0]), k[1]))], calls


def verdict(pastes, cells, whole, paragraph, ask_cells, new_cells, policy, label):
    by = {}
    for r in pastes:
        by.setdefault(r["cell"], []).append(r)
    hit = lambda r: outcome_of(r, policy)[2]  # noqa: E731
    # criterion 1 as in round 1: the matrix (and held-out) positives; whole-copy and new cells have their own rows
    positive = [c for c in cells if c["outcome"] == "paste" and not c["borderline"]
                and c["group"] in ("matrix", "heldout") and c["id"] not in new_cells + whole]
    borderline = [c for c in cells if c["outcome"] == "paste" and c["borderline"] and c["group"] == "matrix"]
    traps = [c for c in cells if c["outcome"] == "nothing"]
    ids = {c["id"] for c in cells}
    mine = [r for r in pastes if r["cell"] in ids]
    out = []
    w = out.append

    def misses(cs, pred=lambda r: not hit(r)):
        return [(cid, r["run"], shown(r, policy)) for cid in cs for r in by.get(cid, []) if pred(r)]

    def n(cs):
        return sum(len(by.get(c, [])) for c in cs)

    fmt = lambda ms: ", ".join("%s r%d → %s" % m for m in ms)  # noqa: E731
    pos_ids = [c["id"] for c in positive]
    m1, mb = misses(pos_ids), misses([c["id"] for c in borderline])
    m2 = misses([c["id"] for c in traps])
    m3 = misses(whole + paragraph)
    m4 = misses(ask_cells, lambda r: outcome_of(r, policy)[0] != "ask")
    f4 = [(r["cell"], r["run"], shown(r, policy)) for r in mine
          if outcome_of(r, policy)[0] == "ask" and r["cell"] not in ask_cells]
    m5 = [(r["cell"], r["run"]) for r in mine if outcome_of(r, policy)[1] is not None
          and outcome_of(r, policy)[1] not in r2.BY_ID[r["cell"]]["item"]]
    timed = [r for r in mine if r["expected_outcome"] != "too_long" and r["outcome"] != "error"]
    lat = [(r["latency_ms"] if policy == "A" else r["b_latency_ms"]) for r in timed]
    over = [(r["cell"], r["run"], (r["latency_ms"] if policy == "A" else r["b_latency_ms"])) for r in timed
            if (r["latency_ms"] if policy == "A" else r["b_latency_ms"]) > 5000]
    w("### %s — policy %s\n" % (label, policy))
    w("| # | criterion | result |")
    w("|---|---|---|")
    w("| 1 | every positive cell hits (borderline reported, not gating) | %s — %d/%d pastes%s. Borderline: %d/%d%s |" % (
        "PASS" if not m1 else "**FAIL**", n(pos_ids) - len(m1), n(pos_ids), "; misses: " + fmt(m1) if m1 else "",
        n([c["id"] for c in borderline]) - len(mb), n([c["id"] for c in borderline]),
        " (misses: " + fmt(mb) + ")" if mb else ""))
    w("| 2 | every trap cell ends in No Suitable Match | %s — %d/%d%s |" % (
        "PASS" if not m2 else "**FAIL**", n([c["id"] for c in traps]) - len(m2), n([c["id"] for c in traps]),
        "; misses: " + fmt(m2) if m2 else ""))
    w("| 3 | whole copy in %s; paragraph in %s | %s — %d/%d%s |" % (
        ", ".join(whole), ", ".join(paragraph), "PASS" if not m3 else "**FAIL**", n(whole + paragraph) - len(m3),
        n(whole + paragraph), "; misses: " + fmt(m3) if m3 else ""))
    w("| 4 | chooser opens on %s, nowhere else | %s — opened %d/%d; asks elsewhere: %s%s |" % (
        ", ".join(ask_cells), "PASS" if not (m4 or f4) else "**FAIL**", n(ask_cells) - len(m4), n(ask_cells),
        fmt(f4) or "none", "; not opened: " + fmt(m4) if m4 else ""))
    w("| 5 | every paste byte-exact | %s — %d/%d |" % ("PASS" if not m5 else "**FAIL**", len(mine) - len(m5),
                                                    len(mine)))
    if lat:
        w("| 6 | median < 2 s, nothing > 5 s | %s — median %.0f ms, p90 %.0f ms, max %.0f ms (n=%d)%s |" % (
            "PASS" if statistics.median(lat) < 2000 and not over else "**FAIL**", statistics.median(lat),
            pct(lat, 0.9), max(lat), len(lat), "; over 5 s: " + ", ".join("%s r%d %.0f ms" % o for o in over)
            if over else ""))
    if new_cells:
        w("| 7 | new cells | %s |" % "; ".join("%s %d/%d (%s)" % (
            cid, sum(1 for r in by.get(cid, []) if hit(r)), len(by.get(cid, [])),
            " / ".join(shown(r, policy) for r in by.get(cid, []))) for cid in new_cells))
    w("")
    fails = [k for k, v in (("1", m1), ("2", m2), ("3", m3), ("4", m4 or f4), ("5", m5)) if v]
    if lat and (statistics.median(lat) >= 2000 or over):
        fails.append("6")
    if new_cells and any(not hit(r) for cid in new_cells for r in by.get(cid, [])):
        fails.append("7")
    return out, fails


def step_text(s):
    pick = "keep" if s.get("choice") == "keep" else (short(s.get("choice_text"), 22) if s.get("choice_text")
                                                     else s.get("choice"))
    return "%s (%d%s, %.2f%s)" % (pick, s["options"], "/%d" % s["choices"] if s.get("choices", 1) > 1 else "",
                                  s.get("p") or 0, ", spec" if s.get("speculative") else "")


def report():
    rows, pastes, calls = load()
    out = []
    w = out.append
    r1_cells = [c for c in r2.cells.CELLS]
    h_cells = list(r2.heldout.HELDOUT)
    w("# Round-2 matrix report (design `r2b`, frozen at GATE A2; N03 after the approved fallback fix)\n")
    w("Pastes: %d (round-1 cells %d, held-out %d). Both runs of every cell.\n" % (
        len(pastes), sum(1 for r in pastes if r["group"] != "heldout"),
        sum(1 for r in pastes if r["group"] == "heldout")))
    summary = {}
    for policy in ("A", "B"):
        o, f = verdict(pastes, r1_cells, R1_WHOLE, R1_PARAGRAPH, R1_ASK, R1_NEW, policy, "Round-1 cells")
        out.extend(o)
        summary[("round-1", policy)] = f
        o, f = verdict(pastes, h_cells, H_WHOLE, H_PARAGRAPH, H_ASK, H_NEW, policy, "Held-out cells")
        out.extend(o)
        summary[("held-out", policy)] = f
    w("### Summary: failing criteria\n")
    for k, v in summary.items():
        w("- %s, policy %s: %s" % (k[0], k[1], ", ".join(v) if v else "none"))
    w("")

    # ------------------------------------------------------------ every miss
    w("## Every miss, with what Jev chose instead\n")
    w("| cell | run | policy | expected | pasted | steps (pick (options/choices, p)) | place (every/part/nothing) |")
    w("|---|---|---|---|---|---|---|")
    for r in pastes:
        cell = r2.BY_ID[r["cell"]]
        exp = {"nothing": "∅ nothing", "ask": "ask", "too_long": "too long"}.get(cell["outcome"],
                                                                                short(cell["expected"]))
        pp = (r.get("place") or {}).get("probabilities") or {}
        for policy in ("A", "B"):
            if outcome_of(r, policy)[2]:
                continue
            w("| %s%s | %d | %s | %s | %s | %s | %.2f / %.2f / %.2f |" % (
                r["cell"], " ⚠" if cell["borderline"] else "", r["run"], policy, exp, shown(r, policy),
                " › ".join(step_text(s) for s in r["steps"]), pp.get("everything", 0), pp.get("one_part", 0),
                pp.get("nothing", 0)))
    w("")
    w("## Expectation questions for Daniel\n")
    for cid, note in EXPECTATION_QUESTIONS.items():
        for r in [p for p in pastes if p["cell"] == cid]:
            s0 = r["steps"][0] if r["steps"] else {}
            w("- **%s** r%d: pasted %s; step 1 pick %s (p %.2f), then %s. Scored as a miss — %s." % (
                cid, r["run"], shown(r), short(s0.get("choice_text")), s0.get("p") or 0,
                " › ".join(step_text(s) for s in r["steps"][1:]) or "–", note))
    w("")

    # ------------------------------------------------------------ per-paste table
    w("## Per-paste table\n")
    w("Steps: `pick (options[/choices], p)`; `spec` = answered by a speculative question (no extra call). "
      "p(all) = p(everything / keep) of the deciding choice at step 1; max p(nothing) and p(ask) over steps.\n")
    w("| cell | run | A | B | pasted (A) | calls | ms | forms | steps | p(all) s1 | p(nothing) | p(ask) | "
      "place every/part/nothing |")
    w("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in pastes:
        pp = (r.get("place") or {}).get("probabilities") or {}
        s = r["steps"]
        w("| %s | %d | %s | %s | %s | %d | %.0f | %s | %s | %.2f | %.2f | %.2f | %.2f / %.2f / %.2f |" % (
            r["cell"], r["run"], "✅" if r["hit"] else "❌", "✅" if r["b_hit"] else "❌", shown(r), r["calls"],
            r["latency_ms"], ",".join(sorted(set(f for f in r["forms_used"] if f))),
            " › ".join(step_text(x) for x in s), (s[0].get("p_keep") or 0) if s else 0,
            max([x.get("p_nothing") or 0 for x in s] or [0]), max([x.get("p_ask") or 0 for x in s] or [0]),
            pp.get("everything", 0), pp.get("one_part", 0), pp.get("nothing", 0)))
    w("")

    # ------------------------------------------------------------ latency, calls, cost
    w("## Latency, calls, cost\n")
    timed = [r for r in pastes if r["expected_outcome"] != "too_long" and r["outcome"] != "error"]
    for label, sel in (("all", timed), ("round-1 cells", [r for r in timed if r["group"] != "heldout"]),
                       ("held-out", [r for r in timed if r["group"] == "heldout"])):
        for policy, key in (("A", "latency_ms"), ("B", "b_latency_ms")):
            lat = [r[key] for r in sel]
            if lat:
                w("- %s, policy %s: n=%d, median %.0f ms, p90 %.0f ms, max %.0f ms; calls mean %.2f." % (
                    label, policy, len(lat), statistics.median(lat), pct(lat, 0.9), max(lat),
                    statistics.mean(r["calls"] if policy == "A" else r["b_calls"] for r in sel)))
    for k in sorted({r["calls"] for r in timed}):
        ls = [r["latency_ms"] for r in timed if r["calls"] == k]
        w("  - %d call(s): n=%d, median %.0f ms, p90 %.0f ms, max %.0f ms" % (
            k, len(ls), statistics.median(ls), pct(ls, 0.9), max(ls)))
    ok = [c for c in calls if c["status"] == 200]
    warm = [c["latency_ms"] for c in ok if not c["cold"]]
    cold = [c["latency_ms"] for c in ok if c["cold"]]
    w("- Per call: warm n=%d median %.0f ms, p90 %.0f ms, max %.0f ms; cold (first call of a process) n=%d, %s." % (
        len(warm), statistics.median(warm), pct(warm, 0.9), max(warm), len(cold),
        ", ".join("%.0f ms" % x for x in cold)))
    w("- Calls per paste (A): distribution %s; speculative next-step answers used: %d times (each saved one call)." % (
        ", ".join("%d×%d" % (k, sum(1 for r in pastes if r["calls"] == k)) for k in sorted({r["calls"] for r in pastes})),
        sum(r.get("speculative_used") or 0 for r in pastes)))
    forms = {}
    for r in pastes:
        for f in r["forms_used"]:
            forms[f] = forms.get(f, 0) + 1
    w("- Option form per request: %s (full = fallback when the excerpts would overfill the state)." % forms)
    waits = [x for c in calls for x in c.get("waits", [])]
    w("- Retry waits (429/503; pacing excluded): %d waits, %.0f s in total (%d × 429, %d × 503/5xx, %d network)." % (
        len(waits), sum(x.get("slept_s") or 0 for x in waits), sum(1 for x in waits if x.get("status") == 429),
        sum(1 for x in waits if x.get("status") in (500, 502, 503, 529)), sum(1 for x in waits if x.get("status") is None)))
    slow = [c for c in ok if c["latency_ms"] > 3000]
    w("- Single calls over 3 s: %d%s" % (len(slow), ":" if slow else "."))
    for c in slow:
        u = (c["response"].get("usage") if isinstance(c["response"], dict) else None) or {}
        w("  - %s r%d step %d %s: %.0f ms, questions %d, request %d bytes, input tokens %s, form %s" % (
            c["cell"], c["run"], c["step"], c["sub"], c["latency_ms"], c["questions_n"], c["request_bytes"],
            u.get("inputTokens"), "ids" if "excerpts" in c["request"]["state"] else "full"))
    all_billed = [r for r in rows if r.get("kind") == "call" and r.get("billed")]
    cost = tokens = 0.0
    for c in all_billed:
        resp = c.get("response")
        if isinstance(resp, dict):
            meta = ((resp.get("providerMetadata") or {}).get("gateway") or {})
            cost += float(meta.get("cost") or 0)
            tokens += (resp.get("usage") or {}).get("inputTokens") or 0
    mcalls = [c for c in calls if c.get("billed")]
    w("- Billed calls round 2: %d (explore %d, matrix %d; budget 700, stop-and-ask 650); round 1 used 184 → "
      "spike total %d (≤ 900). Round-2 input tokens %.0f; Gateway cost $%.4f." % (
          len(all_billed), sum(1 for c in all_billed if c.get("phase") == "explore"), len(mcalls),
          184 + len(all_billed), tokens, cost))
    w("")
    text = "\n".join(out)
    with open(REPORT, "w") as handle:
        handle.write(text + "\n")
    print(text)


if __name__ == "__main__":
    report()
