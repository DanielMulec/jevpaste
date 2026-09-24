"""Free-text spike: does Jev reliably tell free-text places from value fields?

Usage (key must already be exported, never printed):
    set -a; . ~/.config/jevpaste/env; set +a
    python3 run.py smoke          # 1 call, S01a
    python3 run.py main [ids...]  # 3 runs per situation, three questions per call
    python3 run.py ablation       # S01a and S08 once more without app_name/window_title
    python3 run.py baseline       # two-question calls (paste + contains_value) for latency
    python3 run.py report         # summarise results/raw.jsonl

Every response is appended verbatim to results/raw.jsonl.
"""

import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "abstention"))

import candidates  # noqa: E402  (reused as is from spikes/abstention)
import jev  # noqa: E402

import situations  # noqa: E402

MAX_CALLS = 58  # process-local guard; overall budget is 60 billed calls
RUNS = 3
RAW_PATH = os.path.join(HERE, "results", "raw.jsonl")

# verbatim from spikes/abstention/run.py, `target_field` -> `target_context`
CHOICE_INSTRUCTIONS = (
    "The user copied `source_document` and is pasting into `target_context`. Every "
    "option is an exact contiguous excerpt of `source_document`. Choose the single "
    "excerpt that is exactly the value belonging in that field, as the user would "
    "type it. Do not choose an excerpt that is merely related to the field."
)

GATE_POSITIVE = (
    "Does `source_document` contain some exact contiguous excerpt that is the value "
    "belonging in `target_context`? Answer true only if such an excerpt exists and "
    "could be inserted verbatim into the field."
)

NONE_OF_THESE = (
    "None of the listed excerpts is the value that belongs in the target "
    "field. Choose this when the source document does not contain the "
    "value, or when no single excerpt is right."
)

FREE_TEXT_INSTRUCTIONS = (
    "Judge only the place described by `target_context`, not `source_document`. "
    "Is `target_context` a free-text place — a chat or message composer, a "
    "document or text editor, a code editor, a terminal — where the user would "
    "paste whatever they copied, as it is? Or is it a field that expects one "
    "specific value, such as a name, an email address, a phone number, an "
    "address line or a single short entry?"
)

FREE_TEXT_CRITERIA = {
    "true": "A free-text place: the user would paste whatever they copied, whole.",
    "false": "A field for one specific value.",
}


def build_state(target_context):
    context = {}
    for key, value in target_context.items():
        if value is None or value == "" or value == []:
            continue  # production omits absent/empty fields
        context[key] = value
    return {"source_document": situations.SOURCE_DOCUMENT, "target_context": context}


def paste_question(excerpts):
    # production option ids: "c" + 3-digit zero-based index
    criteria = {}
    for index, excerpt in enumerate(excerpts):
        description = excerpt.replace("\n", " ")
        if len(description) > candidates.MAX_DESCRIPTION:
            description = description[: candidates.MAX_DESCRIPTION - 3] + "..."
        criteria["c%03d" % index] = description
    criteria["none_of_these"] = NONE_OF_THESE
    return {"type": "choice", "instructions": CHOICE_INSTRUCTIONS, "criteria": criteria}


def contains_value_question():
    return {
        "type": "boolean",
        "instructions": GATE_POSITIVE,
        "criteria": {
            "true": "An exact excerpt of the document is the value for this field.",
            "false": "No excerpt of the document is the value for this field.",
        },
    }


def free_text_question():
    return {"type": "boolean", "instructions": FREE_TEXT_INSTRUCTIONS, "criteria": FREE_TEXT_CRITERIA}


def questions(excerpts, with_free_text=True):
    batch = {"paste": paste_question(excerpts), "contains_value": contains_value_question()}
    if with_free_text:
        batch["free_text"] = free_text_question()
    return batch


def log(record):
    os.makedirs(os.path.dirname(RAW_PATH), exist_ok=True)
    with open(RAW_PATH, "a") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def call(kind, situation_id, run, target_context, with_free_text=True):
    excerpts = candidates.derive(situations.SOURCE_DOCUMENT)
    state = build_state(target_context)
    batch = questions(excerpts, with_free_text)
    payload, latency = jev.evaluate(state, batch, MAX_CALLS)
    answers = payload.get("answers") or {}
    record = {
        "kind": kind,
        "situation": situation_id,
        "run": run,
        "latency_ms": round(latency, 1),
        "context_keys": sorted(state["target_context"]),
        "candidate_map": {"c%03d" % i: t for i, t in enumerate(excerpts)},
        "response": payload,  # verbatim
        "timestamp": time.time(),
    }
    log(record)
    free = (answers.get("free_text") or {}).get("probability")
    gate = (answers.get("contains_value") or {}).get("probability")
    choice = (answers.get("paste") or {}).get("choice")
    print(
        "%-28s %-9s run%d %6.0fms free_text=%s contains_value=%s paste=%s %r"
        % (
            situation_id, kind, run, latency,
            "n/a" if free is None else "%.3f" % free,
            "n/a" if gate is None else "%.3f" % gate,
            choice, record["candidate_map"].get(choice, "")[:40],
        )
    )
    return record


def run_main(only=None):
    for situation_id, _, _, context in situations.SITUATIONS:
        if only and situation_id not in only:
            continue
        for run in range(RUNS):
            call("main", situation_id, run, context)
    print("calls this process: %d, throttles: %d" % (jev.calls_made(), jev.throttles()))


def run_ablation():
    for situation_id in ("S01a_chatgpt_placeholder", "S08_email_field"):
        context = dict(situations.BY_ID[situation_id][3])
        context.pop("app_name")
        context.pop("window_title")
        call("no_app_title", situation_id, 0, context)
    print("calls this process: %d, throttles: %d" % (jev.calls_made(), jev.throttles()))


def run_baseline():
    for situation_id in ("S01a_chatgpt_placeholder", "S05_textedit", "S08_email_field", "S09_street_field"):
        call("baseline2q", situation_id, 0, situations.BY_ID[situation_id][3], with_free_text=False)
    print("calls this process: %d, throttles: %d" % (jev.calls_made(), jev.throttles()))


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "report"
    if command == "smoke":
        call("smoke", "S01a_chatgpt_placeholder", 0, situations.BY_ID["S01a_chatgpt_placeholder"][3])
    elif command == "main":
        run_main(only=set(sys.argv[2:]) or None)
    elif command == "ablation":
        run_ablation()
    elif command == "baseline":
        run_baseline()
    elif command == "report":
        import analyze

        analyze.report()
    else:
        raise SystemExit("unknown command %r" % command)
