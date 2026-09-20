"""Abstention spike: can Jev's probabilities separate auto-insert / chooser / no-match?

Usage (key must already be exported, never printed):
    set -a; . ~/.config/jevpaste/env; set +a
    python3 run.py main        # batched protocol, all cases x repeats
    python3 run.py unbatched   # same questions asked one per call, 3 cases
    python3 run.py report      # summarise results/raw.jsonl

Every response is appended verbatim to results/raw.jsonl.
"""

import json
import os
import statistics
import sys
import time

import candidates
import jev
import sources

MAX_CALLS = 120  # process-local guard; the spike's overall budget is ~150 calls
REPEATS = 5
RAW_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results", "raw.jsonl")

SCORE_LEVELS = [
    "Unrelated: the excerpt has nothing to do with the target field and must not be inserted.",
    "Wrong kind of value: the excerpt comes from the document but is not the kind of value this field asks for.",
    "Close but not exact: the right kind of value, but incomplete, too long, or only partially correct.",
    "Exact: the excerpt is exactly what a careful person would type into this field, character for character.",
]

CHOICE_INSTRUCTIONS = (
    "The user copied `source_document` and is pasting into `target_field`. Every "
    "option is an exact contiguous excerpt of `source_document`. Choose the single "
    "excerpt that is exactly the value belonging in that field, as the user would "
    "type it. Do not choose an excerpt that is merely related to the field."
)

GATE_POSITIVE = (
    "Does `source_document` contain some exact contiguous excerpt that is the value "
    "belonging in `target_field`? Answer true only if such an excerpt exists and "
    "could be inserted verbatim into the field."
)

GATE_NEGATIVE = (
    "Is `target_field` unanswerable from `source_document`? Answer true if the "
    "document contains no exact contiguous excerpt that is the value belonging in "
    "that field."
)


def build_state(source, target):
    return {
        "target_field": {
            "form_title": sources.FORM_TITLE,
            "section": target["section"],
            "label": target["label"],
            "placeholder": target["placeholder"],
        },
        "source_document": source,
    }


def choice_question(excerpts, include_none):
    return {
        "type": "choice",
        "instructions": CHOICE_INSTRUCTIONS,
        "criteria": candidates.as_criteria(excerpts, include_none),
    }


def gate_question(instructions):
    return {
        "type": "boolean",
        "instructions": instructions,
        "criteria": {
            "true": "An exact excerpt of the document is the value for this field.",
            "false": "No excerpt of the document is the value for this field.",
        },
    }


def score_question(excerpt):
    return {
        "type": "score",
        "instructions": {
            "candidate_excerpt": excerpt,
            "question": (
                "How well does `candidate_excerpt`, taken verbatim from "
                "`source_document`, fit `target_field`?"
            ),
        },
        "criteria": SCORE_LEVELS,
    }


def log(record):
    os.makedirs(os.path.dirname(RAW_PATH), exist_ok=True)
    with open(RAW_PATH, "a") as handle:
        handle.write(json.dumps(record) + "\n")


def call(kind, case_id, repeat, state, questions):
    payload, latency = jev.evaluate(state, questions, MAX_CALLS)
    record = {
        "kind": kind,
        "case": case_id,
        "repeat": repeat,
        "latency_ms": round(latency, 1),
        "questions": sorted(questions),
        "answers": payload.get("answers"),
        "usage": payload.get("usage"),
        "model": payload.get("model"),
        "timestamp": time.time(),
    }
    metadata = payload.get("providerMetadata") or {}
    record["provider_metadata"] = metadata
    log(record)
    return record


def run_main(only=None):
    for case_id, (source, source_label, target_key, expected) in sources.CASES.items():
        if only and case_id not in only:
            continue
        target = sources.TARGETS[target_key]
        excerpts = candidates.derive(source)
        state = build_state(source, target)
        index_of = {("c%02d" % i): text for i, text in enumerate(excerpts, start=1)}
        print("%-22s candidates=%d expected=%r" % (case_id, len(excerpts), expected))
        for repeat in range(REPEATS):
            score_record = None
            batch = {
                "choice_plain": choice_question(excerpts, include_none=False),
                "choice_none": choice_question(excerpts, include_none=True),
                "gate_pos": gate_question(GATE_POSITIVE),
                "gate_neg": gate_question(GATE_NEGATIVE),
            }
            record = call("batch", case_id, repeat, state, batch)
            record["candidate_map"] = index_of
            record["source_label"] = source_label
            record["target"] = target["label"]
            record["expected"] = expected
            answers = record["answers"] or {}
            top_option = (answers.get("choice_plain") or {}).get("choice")
            top_text = index_of.get(top_option, "")
            print(
                "  rep%d %6.0fms plain=%s(%s) none=%s gate+=%.3f gate-=%.3f"
                % (
                    repeat,
                    record["latency_ms"],
                    top_option,
                    _fmt(_prob(answers, "choice_plain", top_option)),
                    (answers.get("choice_none") or {}).get("choice"),
                    (answers.get("gate_pos") or {}).get("probability", float("nan")),
                    (answers.get("gate_neg") or {}).get("probability", float("nan")),
                )
            )
            if top_text:
                score_record = call(
                    "score",
                    case_id,
                    repeat,
                    state,
                    {"fit_score": score_question(top_text)},
                )
                score_record["scored_excerpt"] = top_text
                score_answer = (score_record["answers"] or {}).get("fit_score") or {}
                print(
                    "        score=%s conf=%s for %r"
                    % (
                        _fmt(score_answer.get("score")),
                        _fmt(score_answer.get("confidence")),
                        top_text[:48],
                    )
                )
            _log_metadata(record, score_record)
        print("  calls so far: %d" % jev.calls_made())


def _log_metadata(batch_record, score_record):
    """Append enriched copies (candidate map, expectation) for later analysis.

    These carry no `answers` key; `load()` relabels them so they are never
    counted as API calls.
    """
    for record, kind in ((batch_record, "meta"), (score_record, "meta_score")):
        if not record:
            continue
        copy = {k: v for k, v in record.items() if k != "answers"}
        copy["kind"] = kind
        log(copy)


def run_unbatched():
    """Ask the same questions one per call, to test batching interference."""
    for case_id in ("C1_email_control", "A_email_three", "D1_recipe_name"):
        source, _, target_key, _ = sources.CASES[case_id]
        target = sources.TARGETS[target_key]
        excerpts = candidates.derive(source)
        state = build_state(source, target)
        singles = {
            "choice_plain": choice_question(excerpts, include_none=False),
            "choice_none": choice_question(excerpts, include_none=True),
            "gate_pos": gate_question(GATE_POSITIVE),
        }
        for name, question in singles.items():
            record = call("single_" + name, case_id, 0, state, {name: question})
            answer = (record["answers"] or {}).get(name) or {}
            print(
                "%-22s %-14s %6.0fms %s"
                % (
                    case_id,
                    name,
                    record["latency_ms"],
                    json.dumps({k: v for k, v in answer.items() if k != "probabilities"}),
                )
            )
    print("calls so far: %d" % jev.calls_made())


def _prob(answers, key, option):
    probabilities = (answers.get(key) or {}).get("probabilities") or {}
    return probabilities.get(option)


def _fmt(value):
    return "n/a" if value is None else "%.3f" % value


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "report"
    if command == "main":
        run_main(only=set(sys.argv[2:]) or None)
    elif command == "unbatched":
        run_unbatched()
    elif command == "report":
        import analyze

        analyze.report()
    else:
        raise SystemExit("unknown command %r" % command)
