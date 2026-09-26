"""Any-field spike: can Jev extract the excerpt for any field in two stages (Engine J)?

Usage (key must already be exported, never printed):
    set -a; . ~/.config/jevpaste/env; set +a
    python3 run.py smoke [cell_id]       # one J paste (stage 1 + stage 2 when triggered)
    python3 run.py matrix [run] [ids...] # J for every cell (or the listed ones), run index `run` (0 or 1)
    python3 run.py jprime ids...         # J' per-span boolean form on the listed cells
    python3 run.py report                # analyze.py

Every request and response is appended verbatim to results/raw.jsonl.
"""

import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "abstention"))

import jev  # noqa: E402  (stdlib client reused unchanged from spikes/abstention)

import fixtures  # noqa: E402
import spans  # noqa: E402

BUDGET = 320  # billed Jev calls for the whole spike, counted across processes from raw.jsonl
# The previous worker reported 17 smoke calls; raw.jsonl holds 14 billed records. Count the 3 unaccounted calls
# against the budget so the ceiling holds even if they were billed but never logged.
UNLOGGED_BILLED = 3
RAW_PATH = os.path.join(HERE, "results", "raw.jsonl")
MAX_DESCRIPTION = 255
CONTAINS_VALUE_THRESHOLD = 0.5  # production Core
FREE_TEXT_THRESHOLD = 0.8  # production Core
CONTAINS_MORE_THRESHOLD = 0.5  # new gate: stage 2 runs at or above (fixed before the matrix)
SHADOW_STAGE2 = False  # ran during the withdrawn v6 matrix; off for v7 to keep the budget

# ------------------------------------------------------------------------------------------------ wording
# Stage 1 choice: production wording, widened to "is, or contains" (the brief: "which belongs in the target, or
# contains what belongs there?").
STAGE1_CHOICE = (
    "The user copied `source_document` and is pasting into `target_context`. Every option is an exact "
    "contiguous excerpt of `source_document`. Choose the single excerpt that is exactly the value belonging in "
    "that field, as the user would type it. If no option is exactly that value, choose the shortest option that "
    "contains it. Do not choose an excerpt that is merely related to the field."
)
STAGE1_NONE = (
    "None of the listed excerpts is or contains the value that belongs in the target field. Choose this when "
    "the source document does not contain the value."
)

# Production, unchanged (Sources/JevGateway/EvaluateRequestBody.swift on main).
GATE_CONTAINS_VALUE = {
    "type": "boolean",
    "instructions": (
        "Does `source_document` contain some exact contiguous excerpt that is the value belonging in "
        "`target_context`? Answer true only if such an excerpt exists and could be inserted verbatim into the "
        "field."
    ),
    "criteria": {
        "true": "An exact excerpt of the document is the value for this field.",
        "false": "No excerpt of the document is the value for this field.",
    },
}
FREE_TEXT = {
    "type": "boolean",
    "instructions": (
        "Judge only the place described by `target_context`, not `source_document`. Is `target_context` a "
        "free-text place — a chat or message composer, a document or text editor, a code editor, a terminal — "
        "where the user would paste whatever they copied, as it is? Or is it a field that expects one specific "
        "value, such as a name, an email address, a phone number, an address line or a single short entry?"
    ),
    "criteria": {
        "true": "A free-text place: the user would paste whatever they copied, whole.",
        "false": "A field for one specific value.",
    },
}

# New boolean (the gate for stage 2). Self-contained: Jev answers each question on its own, so it cannot refer to
# "the option chosen in `paste`"; it names the structural units instead.
CONTAINS_MORE = {
    "type": "boolean",
    "instructions": (
        "Think of `source_document` as its whole lines, the values after `Label:` prefixes, its paragraphs and "
        "the whole document. Take the smallest of these that holds the value belonging in `target_context`. "
        "Does it contain more than that value — other words, a label, a prefix or other values that must be "
        "cut away before pasting into the field?"
    ),
    "criteria": {
        "true": "The value is only part of a line, `Label:` value or paragraph; the rest must be cut away.",
        "false": "The value is exactly a whole line, a `Label:` value, a paragraph or the whole document, or "
                 "the document holds no value for this field.",
    },
}

# Wording variants tried on a small tuning set before the matrix (kind "tune" in raw.jsonl).
CONTAINS_MORE_VARIANTS = {
    "v1": CONTAINS_MORE,
    "v2": {
        "type": "boolean",
        "instructions": (
            "Find where the value belonging in `target_context` appears in `source_document`. Does the line that "
            "holds it (or the value after its `Label:` prefix) contain anything besides that value — other "
            "words, other numbers, a label or a prefix on the same line? If the value spans several lines, "
            "judge its paragraph instead."
        ),
        "criteria": {
            "true": "The line holding the value also holds other text that does not belong in the field.",
            "false": "The value fills its whole line, its `Label:` value or its paragraph on its own, or the "
                     "document holds no value for this field.",
        },
    },
    "v3": {
        "type": "boolean",
        "instructions": (
            "Before pasting into `target_context`, would the user have to delete some words, numbers, a label or "
            "a prefix from the line (or paragraph) of `source_document` that holds the value for this field, "
            "because they share that line with the value but do not belong in the field?"
        ),
        "criteria": {
            "true": "Yes: the line or paragraph holding the value also holds text that must be deleted.",
            "false": "No: the value is a whole line, a `Label:` value or a whole paragraph on its own, or the "
                     "document holds no value for this field.",
        },
    },
}



def contains_more_v4(candidates):
    """The brief's gate as literally as Jev allows: questions are answered independently, so the boolean cannot
    see the `paste` answer; instead it gets the same Candidates embedded and picks "the chosen one" itself."""
    return {
        "type": "boolean",
        "instructions": {
            "excerpts": candidates,
            "question": (
                "Every entry of `excerpts` is an exact excerpt of `source_document`. Take the entry that belongs "
                "in `target_context`: the one that is exactly the value for that field, or else the shortest one "
                "that contains it. Does that entry contain more than what belongs in the field — other words, a "
                "label, a prefix or other values that would have to be cut away before pasting?"
            ),
        },
        "criteria": {
            "true": "That entry holds the value plus other text that must be cut away before pasting.",
            "false": "That entry is exactly what belongs in the field, or the document holds no value for it.",
        },
    }


# v5: v3's everyday framing plus generic worked examples (no fixture values; names, towns and numbers invented).
CONTAINS_MORE_VARIANTS["v5"] = {
    "type": "boolean",
    "instructions": (
        "Find the text in `source_document` that belongs in `target_context`, and look at the line it sits on (or "
        "the value after that line's `Label:` prefix, or its paragraph when the value spans several lines). "
        "Does that line hold more than what belongs in the field, so the user would have to delete part of it "
        "after pasting? Examples: a first-name field and the line `Karl Berger` \u2014 yes, the last name must go; "
        "a postcode field and the line `1010 Wien` \u2014 yes, the town must go; a street field and the line "
        "`Tel. 0512 44 55` \u2014 no value there at all, so no; an email field and a line that is only an email "
        "address \u2014 no; a street-and-number field and the line `Ringstra\u00dfe 3` \u2014 no; a field for a short "
        "text about the person and a paragraph that is exactly that text \u2014 no."
    ),
    "criteria": {
        "true": "The line (or `Label:` value, or paragraph) holding the value also holds text that must be deleted.",
        "false": "The value is that whole line, `Label:` value or paragraph on its own, or the document holds no "
                 "value for this field.",
    },
}


# v6: v5 plus two generic examples for the two v5 misses in tuning (a leading word before an amount; prose
# paragraphs for a bio-like field).
CONTAINS_MORE_VARIANTS["v6"] = dict(CONTAINS_MORE_VARIANTS["v5"], instructions=(
    CONTAINS_MORE_VARIANTS["v5"]["instructions"][:-1] + "; an amount field and the line `Summe 45,00` \u2014 yes, "
    "the word `Summe` must go; a bio or about-me field and one or two paragraphs of prose about the person "
    "\u2014 no, they are pasted whole."
))


# v7: after the supervisor's check (Daniel: no field vocabulary anywhere in J). v5/v6 named field types in their
# examples (first name, postcode, email, ...) and are withdrawn. v7 keeps v5's framing but its examples are about
# shape only, with placeholder letters instead of values or field types.
CONTAINS_MORE_VARIANTS["v7"] = {
    "type": "boolean",
    "instructions": (
        "Find the text in `source_document` that belongs in `target_context`, and look at the line it sits on (or "
        "the value after that line's `Label:` prefix, or its paragraph when the value spans several lines). "
        "Does that line hold more than what belongs in the field, so the user would have to delete part of it "
        "after pasting? Answer yes when the line holds the value plus other words, numbers, a label or a prefix. "
        "Answer no when the line is exactly the value, when the value is a whole paragraph, or when the document "
        "holds nothing for the field. Shapes, with `A` standing for what belongs in the field: the line `A B` "
        "\u2014 yes; the line `B A` \u2014 yes; the line `B A C` \u2014 yes; the line `A` \u2014 no; the "
        "paragraph that is exactly `A` \u2014 no."
    ),
    "criteria": {
        "true": "The line (or `Label:` value, or paragraph) holding the value also holds text that must be deleted.",
        "false": "The value is that whole line, `Label:` value or paragraph on its own, or the document holds no "
                 "value for this field.",
    },
}


def contains_more_question(variant, candidates):
    if variant == "v4":
        return contains_more_v4(candidates)
    return CONTAINS_MORE_VARIANTS[variant]


# The gate wording used by the matrix; fixed after tuning (see FINDINGS.md), never changed mid-matrix.
MATRIX_VARIANT = os.environ.get("CONTAINS_MORE_VARIANT", "v7")

STAGE2_CHOICE = (
    "The user copied `source_document` and is pasting into `target_context`. Every option is an exact "
    "contiguous excerpt of `source_document`, cut at word and punctuation boundaries. Choose the single excerpt "
    "that is exactly the value belonging in that field, as the user would type it: nothing of the value "
    "missing, and no neighbouring words, labels or other values included."
)
STAGE2_NONE = "None of the listed excerpts is exactly the value that belongs in the target field."

# J' (per-span boolean), used only if the batched stage-2 choice is unreliable.
JPRIME_INSTRUCTIONS = (
    "The user copied `source_document` and is pasting into `target_context`. Is the exact text {span} the "
    "{field} — the complete value belonging in that field, with nothing extra, as the user would type it?"
)


# --------------------------------------------------------------------------------------------------- plumbing
def billed_so_far():
    if not os.path.exists(RAW_PATH):
        return UNLOGGED_BILLED
    with open(RAW_PATH) as handle:
        return UNLOGGED_BILLED + sum(1 for line in handle if line.strip() and json.loads(line).get("billed"))


def log(record):
    os.makedirs(os.path.dirname(RAW_PATH), exist_ok=True)
    with open(RAW_PATH, "a") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


_process_calls = 0


def evaluate(state, questions, meta):
    """One billed call; logs request + response verbatim. Returns (answers, latency_ms, record)."""
    global _process_calls
    if billed_so_far() >= BUDGET:
        raise SystemExit("spike budget of %d billed Jev calls reached" % BUDGET)
    cold = _process_calls == 0
    payload, latency = jev.evaluate(state, questions, max_calls=10_000)
    _process_calls += 1
    record = dict(meta)
    record.update({
        "billed": True,
        "cold": cold,
        "latency_ms": round(latency, 1),
        "request": {"model": jev.MODEL, "state": state, "questions": questions},
        "response": payload,
        "timestamp": time.time(),
    })
    log(record)
    return payload.get("answers") or {}, latency, record


def option_map(texts, none_description):
    ids = {"c%03d" % i: t for i, t in enumerate(texts)}
    criteria = {}
    for oid, text in ids.items():
        # production: split at newlines, empty pieces omitted, joined with one space
        description = " ".join(piece for piece in spans._NEWLINE_RE.split(text) if piece)
        criteria[oid] = description[:MAX_DESCRIPTION]
    criteria["none_of_these"] = none_description
    return ids, criteria


def state_for(item_id, cell):
    return {"source_document": fixtures.ITEMS[item_id], "target_context": fixtures.target_context(cell)}


def find_cell(cell_id):
    for item_id, cell in fixtures.all_cells():
        if cell["id"] == cell_id:
            return item_id, cell
    raise SystemExit("unknown cell %r" % cell_id)


def is_hit(cell, text):
    if cell["expected"] is None:
        return text is None
    return text is not None and (text == cell["expected"] or text in cell["accept"])


# -------------------------------------------------------------------------------------------------- engine J
def stage1_questions(candidates, variant):
    ids, criteria = option_map(candidates, STAGE1_NONE)
    questions = {
        "paste": {"type": "choice", "instructions": STAGE1_CHOICE, "criteria": criteria},
        "contains_value": GATE_CONTAINS_VALUE,
        "free_text": FREE_TEXT,
        "contains_more": contains_more_question(variant, candidates),
    }
    return ids, questions


def run_j(item_id, cell, run, variant=None):
    variant = variant or MATRIX_VARIANT
    item = fixtures.ITEMS[item_id]
    state = state_for(item_id, cell)
    candidates = spans.derive(item)
    ids, questions = stage1_questions(candidates, variant)
    meta = {"kind": "j_stage1", "cell": cell["id"], "item": item_id, "run": run, "variant": variant,
            "option_map": ids}
    answers, latency1, record1 = evaluate(state, questions, meta)
    paste = answers.get("paste") or {}
    choice = paste.get("choice")
    probs = paste.get("probabilities") or {}
    p_value = (answers.get("contains_value") or {}).get("probability")
    p_free = (answers.get("free_text") or {}).get("probability")
    p_more = (answers.get("contains_more") or {}).get("probability")
    chosen = ids.get(choice)
    free_override = p_free is not None and p_free >= FREE_TEXT_THRESHOLD

    result = {
        "kind": "j_result", "cell": cell["id"], "item": item_id, "run": run, "variant": variant, "billed": False,
        "expected": cell["expected"], "accept": cell["accept"], "borderline": cell["borderline"],
        "expected_is_candidate": cell["expected"] in candidates if cell["expected"] is not None else None,
        "stage1_choice": choice, "stage1_text": chosen, "stage1_prob": probs.get(choice),
        "stage1_none_prob": probs.get("none_of_these"), "stage1_confidence": paste.get("confidence"),
        "stage1_hit": is_hit(cell, chosen) if chosen is not None else cell["expected"] is None,
        "contains_value": p_value, "free_text": p_free, "contains_more": p_more,
        "free_text_override": free_override,
        "stage1_latency_ms": round(latency1, 1), "stage1_cold": record1["cold"], "stage2_ran": False, "calls": 1,
    }

    # Engine J's own answer (what J returns when the Target is not judged free text)
    if chosen is None or p_value is None or p_value < CONTAINS_VALUE_THRESHOLD:
        j_final, j_path = None, "no_suitable_match"
    elif p_more is not None and p_more >= CONTAINS_MORE_THRESHOLD:
        # Stage 2 also runs when free_text overrides, so J is measured on every cell; such a call would not be made
        # in production (`stage2_in_production` False) and is reported apart in the call counts.
        offered, total = spans.spans(chosen)
        sids, scriteria = option_map(offered, STAGE2_NONE)
        squestions = {"span": {"type": "choice", "instructions": STAGE2_CHOICE, "criteria": scriteria}}
        smeta = {"kind": "j_stage2", "cell": cell["id"], "item": item_id, "run": run, "variant": variant,
                 "option_map": sids, "parent": chosen, "spans_before_cap": total}
        sanswers, latency2, record2 = evaluate(state, squestions, smeta)
        span = sanswers.get("span") or {}
        schoice = span.get("choice")
        sprobs = span.get("probabilities") or {}
        stext = sids.get(schoice)
        noise = spans.same_type_alternatives(stext, offered) if stext is not None else []
        result.update({
            "stage2_ran": True, "stage2_in_production": not free_override,
            "stage2_choice": schoice, "stage2_text": stext, "stage2_prob": sprobs.get(schoice),
            "stage2_none_prob": sprobs.get("none_of_these"), "stage2_confidence": span.get("confidence"),
            "stage2_top3": sorted(((p, sids.get(k, k)) for k, p in sprobs.items()), reverse=True)[:3],
            "span_count": len(offered), "spans_before_cap": total,
            "expected_offered": cell["expected"] in offered if cell["expected"] is not None else None,
            "winner_type": spans.candidate_type(stext) if stext else None,
            "chooser_noise": max(0, len(noise) - 1),
            "chooser_noise_spans": [n for n in noise if n != stext],
            "stage2_latency_ms": round(latency2, 1), "stage2_cold": record2["cold"], "calls": 2,
        })
        j_final, j_path = stext, ("stage2_span" if stext is not None else "stage2_none")
    else:
        j_final, j_path = chosen, "stage1_candidate"
        alternatives = spans.same_type_alternatives(chosen, candidates)
        result["stage1_chooser_noise"] = max(0, len(alternatives) - 1)
        result["stage1_chooser_noise_candidates"] = [a for a in alternatives if a != chosen]
        # Shadow stage 2 (not part of J, never changes its answer): when the gate stayed low but the chosen
        # Candidate is short enough to be offered whole among its own spans, ask stage 2 anyway. Shows whether a
        # gate-free J (stage 2 always) would keep the whole Candidate or cut it.
        offered, total = spans.spans(chosen)
        if SHADOW_STAGE2 and len(offered) > 1 and chosen in offered:
            sids, scriteria = option_map(offered, STAGE2_NONE)
            squestions = {"span": {"type": "choice", "instructions": STAGE2_CHOICE, "criteria": scriteria}}
            smeta = {"kind": "j_stage2_shadow", "cell": cell["id"], "item": item_id, "run": run,
                     "variant": variant, "option_map": sids, "parent": chosen, "spans_before_cap": total}
            sanswers, latency2, _ = evaluate(state, squestions, smeta)
            span = sanswers.get("span") or {}
            stext = sids.get(span.get("choice"))
            result.update({"shadow_stage2_text": stext, "shadow_stage2_prob": (span.get("probabilities") or {})
                           .get(span.get("choice")), "shadow_span_count": len(offered),
                           "shadow_hit": is_hit(cell, stext), "shadow_latency_ms": round(latency2, 1)})

    # Production order: free text first (whole item, DirectPasteRule strips outer line breaks - none here).
    final, path = (item, "free_text_whole_item") if free_override else (j_final, j_path)
    result.update({
        "j_final": j_final, "j_path": j_path, "j_hit": is_hit(cell, j_final),
        "final": final, "path": path, "hit": is_hit(cell, final),
        "hit_note": ("expected" if final is not None and final == cell["expected"]
                     else "accept" if final in cell["accept"] else None),
        "production_calls": 1 + (1 if result["stage2_ran"] and not free_override else 0),
    })
    log(result)
    print("%-22s r%d %s s1=%-5s p=%.2f more=%.2f val=%.2f free=%.2f | %-20s -> %r %s%s"
          % (cell["id"], run, variant, choice, probs.get(choice) or 0, p_more or 0, p_value or 0, p_free or 0,
             path, (final or "")[:40], "HIT" if result["hit"] else "MISS",
             "" if result["j_hit"] == result["hit"] else " (J alone: %s)" % ("HIT" if result["j_hit"] else "MISS")))
    return result


# ------------------------------------------------------------------------------------------------------ J'
def run_jprime(item_id, cell, run, parent):
    """Per-span boolean: one question per span, batched in one call where Jev allows it."""
    state = state_for(item_id, cell)
    offered, total = spans.spans(parent)
    questions = {}
    ids = {}
    for index, text in enumerate(offered):
        qid = "s%03d" % index
        ids[qid] = text
        questions[qid] = {
            "type": "boolean",
            "instructions": JPRIME_INSTRUCTIONS.format(span=json.dumps(text, ensure_ascii=False),
                                                       field=json.dumps(cell["field_label"], ensure_ascii=False)),
            "criteria": {"true": "Exactly this text is the value for the field.",
                         "false": "This text is not exactly the value for the field."},
        }
    meta = {"kind": "jprime", "cell": cell["id"], "item": item_id, "run": run, "option_map": ids,
            "parent": parent}
    answers, latency, _ = evaluate(state, questions, meta)
    scored = sorted(((answers.get(q) or {}).get("probability") or 0, t) for q, t in ids.items())
    top_p, top = scored[-1] if scored else (0, None)
    final = top if top_p >= 0.5 else None
    result = {"kind": "jprime_result", "cell": cell["id"], "item": item_id, "run": run, "billed": False,
              "span_count": len(offered), "top": top, "top_prob": top_p,
              "runner_up": scored[-2] if len(scored) > 1 else None, "final": final,
              "hit": is_hit(cell, final), "latency_ms": round(latency, 1), "calls": 1}
    log(result)
    print("%-22s J' r%d top=%r p=%.2f %s" % (cell["id"], run, top, top_p, "HIT" if result["hit"] else "MISS"))
    return result


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "report"
    if command == "smoke":
        run_j(*find_cell(sys.argv[2] if len(sys.argv) > 2 else "A01_vorname"), run=-1)
    elif command == "matrix":
        run = int(sys.argv[2])
        only = set(sys.argv[3:])
        with open(RAW_PATH) as handle:
            done = {(x["cell"], x["run"]) for x in map(json.loads, filter(str.strip, handle))
                    if x.get("kind") == "j_result" and x.get("variant") == MATRIX_VARIANT}
        for item_id, cell in fixtures.all_cells():
            if only and cell["id"] not in only and item_id not in only:
                continue
            if (cell["id"], run) in done:
                continue  # resume after an interruption; a cell is only ever recorded once per run
            while True:
                try:
                    run_j(item_id, cell, run)
                    break
                except RuntimeError as error:  # persistent 429 "upstream high demand": wait, retry the cell
                    print("retrying %s after: %s" % (cell["id"], str(error)[:80]))
                    time.sleep(90)
        print("billed so far: %d, throttles this process: %d" % (billed_so_far(), jev.throttles()))
    elif command == "tune":
        variant = sys.argv[2]
        for cell_id in sys.argv[3:]:
            item_id, cell = find_cell(cell_id)
            candidates = spans.derive(fixtures.ITEMS[item_id])
            ids, questions = stage1_questions(candidates, variant)
            answers, latency, _ = evaluate(state_for(item_id, cell), questions,
                                           {"kind": "tune", "variant": variant, "cell": cell_id, "item": item_id,
                                            "option_map": ids})
            choice = (answers.get("paste") or {}).get("choice")
            print("%s %-20s more=%.2f choice=%r" % (variant, cell_id, (answers.get("contains_more") or {})
                                                     .get("probability") or 0, ids.get(choice, choice)))
    elif command == "jprime":
        for cell_id in sys.argv[2:]:
            item_id, cell = find_cell(cell_id)
            # parent = the Candidate stage 1 chose in run 0 (from raw.jsonl)
            with open(RAW_PATH) as handle:
                rows = [json.loads(line) for line in handle if line.strip()]
            parents = [r["stage1_text"] for r in rows if r.get("kind") == "j_result" and r["cell"] == cell_id
                       and r["run"] == 0]
            run_jprime(item_id, cell, 0, parents[-1])
    elif command == "extend":
        # Supervisor addition: re-run stage 2 once with the extended cut set `@ . - _` on unreachable cells,
        # over the Candidate stage 1 chose in matrix run 0.
        with open(RAW_PATH) as handle:
            rows = [json.loads(line) for line in handle if line.strip()]
        for cell_id in sys.argv[2:]:
            item_id, cell = find_cell(cell_id)
            parent = [x["stage1_text"] for x in rows if x.get("kind") == "j_result" and x["cell"] == cell_id
                      and x["run"] == 0 and x.get("variant") == MATRIX_VARIANT][-1]
            offered, total = spans.spans(parent, delimiters=spans.EXTENDED_DELIMITERS)
            sids, scriteria = option_map(offered, STAGE2_NONE)
            squestions = {"span": {"type": "choice", "instructions": STAGE2_CHOICE, "criteria": scriteria}}
            answers, latency, _ = evaluate(state_for(item_id, cell), squestions, {
                "kind": "j_stage2_extended", "cell": cell_id, "item": item_id, "run": 0, "variant": MATRIX_VARIANT,
                "option_map": sids, "parent": parent, "spans_before_cap": total, "delimiters": "".join(
                    sorted(spans.EXTENDED_DELIMITERS))})
            span = answers.get("span") or {}
            text = sids.get(span.get("choice"))
            result = {"kind": "extended_result", "cell": cell_id, "billed": False, "parent": parent,
                      "span_count": len(offered), "spans_before_cap": total,
                      "expected_offered": cell["expected"] in offered, "text": text,
                      "prob": (span.get("probabilities") or {}).get(span.get("choice")), "hit": is_hit(cell, text),
                      "latency_ms": round(latency, 1)}
            log(result)
            print(result)
    elif command == "report":
        import analyze

        analyze.report()
    else:
        raise SystemExit("unknown command %r" % command)
