"""Stage 3 of Engine J — recursive refinement below the token (supervisor addition, replaces the `@ . - _` test).

When stage 2's chosen span is a single token (or stage 1's Candidate already is one, so stage 2 would offer only
itself) and the same `contains_more` gate (v7 wording, unchanged) says yes for that piece, offer ALL character
substrings of the piece (byte-exact, deduplicated, <= 254, longest dropped first) + none_of_these with the unchanged
stage-2 choice wording, then gate the pick again; stop when the gate says no. No boundary list, no new wording.

The gate on a piece is asked with `source_document` = that piece (the v7 question looks at "the line it sits on";
the piece is then that line). The choice keeps the full item as `source_document`, like stage 2.

Usage:
    python3 stage3.py cells                      # N01-N03 (fixtures.STAGE3_CELLS): stage 1 -> (2) -> 3
    python3 stage3.py continue B02_city          # continue a matrix run-0 paste whose stage-2 pick is one token
"""

import json
import sys

import fixtures
import run
import spans

VARIANT = "v7"
MAX_LEVELS = 4


def substrings(piece, cap=spans.CAP):
    found = sorted({(i, j) for i in range(len(piece)) for j in range(i + 1, len(piece) + 1)},
                   key=lambda ij: (ij[0], ij[1] - ij[0]))
    seen, unique = set(), []
    for i, j in found:
        text = piece[i:j]
        if text.strip() != text or not text:
            continue
        key = text.encode("utf-8")
        if key not in seen:
            seen.add(key)
            unique.append((i, j - i, text))
    total = len(unique)
    if total > cap:
        order = sorted(range(total), key=lambda k: (-unique[k][1], -unique[k][0]))
        dropped = set(order[: total - cap])
        unique = [u for k, u in enumerate(unique) if k not in dropped]
    return [u[2] for u in unique], total


def gate_on(item_id, cell, piece, level):
    state = {"source_document": piece, "target_context": fixtures.target_context(cell)}
    questions = {"contains_more": run.contains_more_question(VARIANT, [piece])}
    answers, latency, _ = run.evaluate(state, questions, {
        "kind": "stage3_gate", "cell": cell["id"], "item": item_id, "variant": VARIANT, "level": level,
        "piece": piece})
    return (answers.get("contains_more") or {}).get("probability"), latency


def choose_substring(item_id, cell, piece, level):
    offered, total = substrings(piece)
    ids, criteria = run.option_map(offered, run.STAGE2_NONE)
    questions = {"span": {"type": "choice", "instructions": run.STAGE2_CHOICE, "criteria": criteria}}
    answers, latency, _ = run.evaluate(run.state_for(item_id, cell), questions, {
        "kind": "stage3_choice", "cell": cell["id"], "item": item_id, "variant": VARIANT, "level": level,
        "parent": piece, "option_map": ids, "options_before_cap": total})
    span = answers.get("span") or {}
    choice = span.get("choice")
    return ids.get(choice), (span.get("probabilities") or {}).get(choice), len(offered), total, latency


def refine(item_id, cell, piece, level, known_gate=None, known_latency=None):
    """Levels from `level` on. Returns (final text, [level records], billed calls)."""
    levels, calls = [], 0
    while level < 3 + MAX_LEVELS:
        if known_gate is None:
            gate, gate_latency = gate_on(item_id, cell, piece, level)
            calls += 1
        else:
            gate, gate_latency = known_gate, known_latency
            known_gate = None
        record = {"level": level, "piece": piece, "gate": gate, "gate_latency_ms": round(gate_latency or 0, 1)}
        levels.append(record)
        if gate is None or gate < run.CONTAINS_MORE_THRESHOLD or len(spans.tokens(piece)) > 1 or len(piece) < 2:
            record["stop"] = "gate says no" if gate is not None and gate < run.CONTAINS_MORE_THRESHOLD else \
                "not a single token" if len(spans.tokens(piece)) > 1 else "nothing to cut"
            return piece, levels, calls
        pick, prob, count, total, latency = choose_substring(item_id, cell, piece, level)
        calls += 1
        record.update({"options": count, "options_before_cap": total, "pick": pick, "pick_prob": prob,
                       "choice_latency_ms": round(latency, 1)})
        if pick is None:
            record["stop"] = "none_of_these"
            return None, levels, calls
        if pick == piece:
            record["stop"] = "picked the whole piece"
            return piece, levels, calls
        piece, level = pick, level + 1
    return piece, levels, calls


def log_result(cell, item_id, start, final, levels, calls, prior):
    result = {"kind": "stage3_result", "cell": cell["id"], "item": item_id, "billed": False, "variant": VARIANT,
              "start": start, "levels": levels, "final": final, "hit": run.is_hit(cell, final),
              "calls_stage3": calls, "calls_per_paste": prior + calls,
              "latency_ms_per_paste": None}
    run.log(result)
    print(json.dumps(result, ensure_ascii=False, indent=1))
    return result


def run_cell(item_id, cell):
    """Full paste: stage 1, stage 2 when the Candidate has several tokens, stage 3 when the piece is one token."""
    candidates = spans.derive(fixtures.ITEMS[item_id])
    ids, questions = run.stage1_questions(candidates, VARIANT)
    answers, latency1, _ = run.evaluate(run.state_for(item_id, cell), questions, {
        "kind": "j_stage1", "cell": cell["id"], "item": item_id, "run": 0, "variant": VARIANT, "option_map": ids,
        "stage3_cell": True})
    chosen = ids.get((answers.get("paste") or {}).get("choice"))
    p_more = (answers.get("contains_more") or {}).get("probability")
    p_value = (answers.get("contains_value") or {}).get("probability")
    p_free = (answers.get("free_text") or {}).get("probability")
    prior, lat = 1, latency1
    head = {"stage1_text": chosen, "contains_more": p_more, "contains_value": p_value, "free_text": p_free,
            "stage1_latency_ms": round(latency1, 1)}
    print(head)
    if chosen is None or (p_value or 0) < run.CONTAINS_VALUE_THRESHOLD or (p_free or 0) >= run.FREE_TEXT_THRESHOLD:
        return log_result(cell, item_id, head, None if chosen is None else chosen, [], 0, prior)
    if (p_more or 0) < run.CONTAINS_MORE_THRESHOLD:
        return log_result(cell, item_id, head, chosen, [], 0, prior)
    offered, _ = spans.spans(chosen)
    if offered == [chosen]:
        # one-token Candidate: stage 2 would offer only itself; the stage-1 gate already judged this very text
        final, levels, calls = refine(item_id, cell, chosen, 3, known_gate=p_more, known_latency=0)
    else:
        sids, scriteria = run.option_map(offered, run.STAGE2_NONE)
        squestions = {"span": {"type": "choice", "instructions": run.STAGE2_CHOICE, "criteria": scriteria}}
        sanswers, latency2, _ = run.evaluate(run.state_for(item_id, cell), squestions, {
            "kind": "j_stage2", "cell": cell["id"], "item": item_id, "run": 0, "variant": VARIANT,
            "option_map": sids, "parent": chosen, "stage3_cell": True})
        prior += 1
        stext = sids.get((sanswers.get("span") or {}).get("choice"))
        head.update({"stage2_text": stext, "stage2_latency_ms": round(latency2, 1)})
        if stext is None or len(spans.tokens(stext)) > 1:
            return log_result(cell, item_id, head, stext, [], 0, prior)
        final, levels, calls = refine(item_id, cell, stext, 3)
    return log_result(cell, item_id, head, final, levels, calls, prior)


def continue_matrix(cell_id):
    item_id, cell = run.find_cell(cell_id)
    with open(run.RAW_PATH) as handle:
        rows = [json.loads(line) for line in handle if line.strip()]
    r = [x for x in rows if x.get("kind") == "j_result" and x["cell"] == cell_id and x["run"] == 0
         and x.get("variant") == VARIANT][-1]
    piece = r["j_final"]
    head = {"from_matrix_run": 0, "stage1_text": r["stage1_text"], "stage2_text": piece,
            "stage1_latency_ms": r["stage1_latency_ms"], "stage2_latency_ms": r.get("stage2_latency_ms")}
    if piece is None or len(spans.tokens(piece)) > 1:
        print("not a single-token pick:", piece)
        return None
    final, levels, calls = refine(item_id, cell, piece, 3)
    return log_result(cell, item_id, head, final, levels, calls, r["production_calls"])


if __name__ == "__main__":
    if sys.argv[1] == "cells":
        for item_id, cells in fixtures.STAGE3_CELLS.items():
            for c in cells:
                if len(sys.argv) > 2 and c["id"] not in sys.argv[2:]:
                    continue
                run_cell(item_id, c)
    elif sys.argv[1] == "continue":
        for cid in sys.argv[2:]:
            continue_matrix(cid)
