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
RAW_PATH = os.path.join(HERE, "results", "raw.jsonl")
MAX_DESCRIPTION = 255
CONTAINS_VALUE_THRESHOLD = 0.5  # production Core
FREE_TEXT_THRESHOLD = 0.8  # production Core
CONTAINS_MORE_THRESHOLD = 0.5  # new gate: stage 2 runs at or above

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

STAGE2_CHOICE = (
    "The user copied `source_document` and is pasting into `target_context`. Every option is an exact "
    "contiguous excerpt of `source_document`, cut at word and punctuation boundaries. Choose the single excerpt "
    "that is exactly the value belonging in that field, as the user would type it: nothing of the value "
    "missing, and no neighbouring words, labels or other values included."
)
STAGE2_NONE = "None of the listed excerpts is exactly the value that belongs in the target field."

# J' (per-span boolean), used only if the batched stage-2 choice is unreliable.
JPRIME_INSTRUCTIONS = (
    "The user copied `source_document` and is pasting into `target_context`. Is the exact text {span} the value "
    "belonging in that field — complete, with nothing extra — as the user would type it?"
)


# --------------------------------------------------------------------------------------------------- plumbing
def billed_so_far():
    if not os.path.exists(RAW_PATH):
        return 0
    with open(RAW_PATH) as handle:
        return sum(1 for line in handle if line.strip() and json.loads(line).get("billed"))


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
def run_j(item_id, cell, run):
    item = fixtures.ITEMS[item_id]
    state = state_for(item_id, cell)
    candidates = spans.derive(item)
    ids, criteria = option_map(candidates, STAGE1_NONE)
    questions = {
        "paste": {"type": "choice", "instructions": STAGE1_CHOICE, "criteria": criteria},
        "contains_value": GATE_CONTAINS_VALUE,
        "free_text": FREE_TEXT,
        "contains_more": CONTAINS_MORE,
    }
    meta = {"kind": "j_stage1", "cell": cell["id"], "item": item_id, "run": run, "option_map": ids}
    answers, latency1, _ = evaluate(state, questions, meta)
    paste = answers.get("paste") or {}
    choice = paste.get("choice")
    probs = paste.get("probabilities") or {}
    p_value = (answers.get("contains_value") or {}).get("probability")
    p_free = (answers.get("free_text") or {}).get("probability")
    p_more = (answers.get("contains_more") or {}).get("probability")
    chosen = ids.get(choice)

    result = {
        "kind": "j_result", "cell": cell["id"], "item": item_id, "run": run, "billed": False,
        "expected": cell["expected"], "accept": cell["accept"], "borderline": cell["borderline"],
        "expected_is_candidate": cell["expected"] in candidates if cell["expected"] is not None else None,
        "stage1_choice": choice, "stage1_text": chosen, "stage1_prob": probs.get(choice),
        "stage1_none_prob": probs.get("none_of_these"), "stage1_confidence": paste.get("confidence"),
        "contains_value": p_value, "free_text": p_free, "contains_more": p_more,
        "stage1_latency_ms": round(latency1, 1), "stage2_ran": False, "calls": 1,
    }

    # production order: free text first, then choice + contains_value gate, then (new) contains_more
    if p_free is not None and p_free >= FREE_TEXT_THRESHOLD:
        final, path = item, "free_text_whole_item"
    elif chosen is None or p_value is None or p_value < CONTAINS_VALUE_THRESHOLD:
        final, path = None, "no_suitable_match"
    elif p_more is not None and p_more >= CONTAINS_MORE_THRESHOLD:
        offered, total = spans.spans(chosen)
        sids, scriteria = option_map(offered, STAGE2_NONE)
        squestions = {"span": {"type": "choice", "instructions": STAGE2_CHOICE, "criteria": scriteria}}
        smeta = {"kind": "j_stage2", "cell": cell["id"], "item": item_id, "run": run, "option_map": sids,
                 "parent": chosen, "spans_before_cap": total}
        sanswers, latency2, _ = evaluate(state, squestions, smeta)
        span = sanswers.get("span") or {}
        schoice = span.get("choice")
        sprobs = span.get("probabilities") or {}
        stext = sids.get(schoice)
        noise = spans.same_type_alternatives(stext, offered) if stext is not None else []
        result.update({
            "stage2_ran": True, "stage2_choice": schoice, "stage2_text": stext, "stage2_prob": sprobs.get(schoice),
            "stage2_none_prob": sprobs.get("none_of_these"), "stage2_confidence": span.get("confidence"),
            "span_count": len(offered), "spans_before_cap": total,
            "expected_offered": cell["expected"] in offered if cell["expected"] is not None else None,
            "winner_type": spans.candidate_type(stext) if stext else None,
            "chooser_noise": max(0, len(noise) - 1),
            "chooser_noise_spans": [n for n in noise if n != stext],
            "stage2_latency_ms": round(latency2, 1), "calls": 2,
        })
        final, path = stext, ("stage2_span" if stext is not None else "stage2_none")
    else:
        final, path = chosen, "stage1_candidate"
        alternatives = spans.same_type_alternatives(chosen, candidates)
        result["stage1_chooser_alternatives"] = max(0, len(alternatives) - 1)

    result.update({"final": final, "path": path, "hit": is_hit(cell, final),
                   "hit_note": ("accept" if final in cell["accept"] else "expected" if final == cell["expected"]
                                else None)})
    if cell["expect_free_text"]:
        result["hit"] = path == "free_text_whole_item"
    log(result)
    print("%-22s r%d s1=%-5s p=%.2f more=%.2f val=%.2f free=%.2f | %s -> %r %s"
          % (cell["id"], run, choice, probs.get(choice) or 0, p_more or 0, p_value or 0, p_free or 0,
             path, (final or "")[:40], "HIT" if result["hit"] else "MISS"))
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
            "instructions": JPRIME_INSTRUCTIONS.format(span=json.dumps(text, ensure_ascii=False)),
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
        for item_id, cell in fixtures.all_cells():
            if only and cell["id"] not in only and item_id not in only:
                continue
            run_j(item_id, cell, run)
        print("billed so far: %d, throttles this process: %d" % (billed_so_far(), jev.throttles()))
    elif command == "tune":
        variant = sys.argv[2]
        for cell_id in sys.argv[3:]:
            item_id, cell = find_cell(cell_id)
            candidates = spans.derive(fixtures.ITEMS[item_id])
            ids, criteria = option_map(candidates, STAGE1_NONE)
            questions = {
                "paste": {"type": "choice", "instructions": STAGE1_CHOICE, "criteria": criteria},
                "contains_value": GATE_CONTAINS_VALUE,
                "free_text": FREE_TEXT,
                "contains_more": CONTAINS_MORE_VARIANTS[variant],
            }
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
    elif command == "report":
        import analyze

        analyze.report()
    else:
        raise SystemExit("unknown command %r" % command)
