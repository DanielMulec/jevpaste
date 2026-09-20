"""Granularity spike: how should copied text be split into candidate excerpts?

One Jev `choice` question per (document, strategy, criteria-arm, target field).
Results append to results.jsonl; `summarize` prints the tables used in FINDINGS.md.

Usage:
  python3 run_probe.py run <experiment> [run_label]
  python3 run_probe.py summarize
"""

import json
import pathlib
import sys
import time

import candidates
import jev

HERE = pathlib.Path(__file__).parent
RESULTS = HERE / "results.jsonl"
CRITERIA_LIMIT = 255

FIELDS = [
    ("full_name", "Full name", "Your full name", "Personal details", "Marcus Lowe"),
    ("email", "Email address", "you@example.com", "Personal details", "marcus@anything.com"),
    ("location", "Current location", "City, State", "Personal details", "San Francisco, CA"),
    ("x_profile", "X / Twitter profile", "https://x.com/username", "Personal details",
     "https://x.com/marcus_lowe"),
    ("company", "Current company", "Company or studio", "Professional background", "Skydive"),
    ("role", "Current role", "Your title", "Professional background", "Co-founder & CEO"),
    ("summary", "Professional summary", "A short summary of your experience",
     "Professional background",
     "Product-minded technology founder building AI systems that help people turn ideas "
     "into working software."),
]

DOCUMENTS = {
    "resume": HERE / "source_resume.txt",
    "resume_labeled": HERE / "source_resume_labeled.txt",
    "resume_ambiguous": HERE / "source_resume_ambiguous.txt",
}

QUESTION = (
    "Which candidate excerpt of `copied_text` is the exact value that belongs in "
    "`target_field`? The chosen excerpt is inserted verbatim into that field, so pick the "
    "one excerpt a careful person would paste there."
)


def option_ids(count):
    return [f"c{index:03d}" for index in range(1, count + 1)]


def build_question(arm, texts, field):
    """Return (state_extra, criteria). `arm` decides what the criteria say."""
    ids = option_ids(len(texts))
    truncated = 0
    criteria = {}
    for index, (option_id, text) in enumerate(zip(ids, texts), start=1):
        if arm == "index":
            criteria[option_id] = f"Candidate excerpt number {index} in `candidate_excerpts`."
        else:
            description = text
            if len(description) > CRITERIA_LIMIT:
                description = description[:CRITERIA_LIMIT - 1] + "…"
                truncated += 1
            criteria[option_id] = description
    state_extra = {}
    if arm in ("index", "text_plus_list", "list_only"):
        state_extra["candidate_excerpts"] = {
            option_id: text for option_id, text in zip(ids, texts)
        }
    return state_extra, criteria, truncated, ids


def ask(document_text, texts, field, arm):
    field_key, label, placeholder, section, expected = field
    state_extra, criteria, truncated, ids = build_question(arm, texts, field)
    state = dict(state_extra) if arm == "list_only" else {"copied_text": document_text, **state_extra}
    instructions = {
        "target_field": {
            "form": "Product Designer Application",
            "section": section,
            "label": label,
            "placeholder": placeholder,
        },
        "question": QUESTION,
    }
    body, latency_ms, input_tokens = jev.evaluate(
        state, {"excerpt": {"type": "choice", "instructions": instructions, "criteria": criteria}}
    )
    chosen, probabilities, confidence = jev.choice_answer(body, "excerpt")
    by_text = dict(zip(ids, texts))
    ranked = sorted(probabilities.items(), key=lambda pair: pair[1], reverse=True)
    top1 = ranked[0][1] if ranked else None
    top2 = ranked[1][1] if len(ranked) > 1 else 0.0
    chosen_text = by_text.get(chosen)
    return {
        "field": field_key,
        "expected": expected,
        "n_candidates": len(texts),
        "expected_reachable": expected in texts,
        "criteria_truncated": truncated,
        "chosen_id": chosen,
        "chosen_text": chosen_text,
        "exact": chosen_text == expected,
        "contains": bool(chosen_text) and expected in chosen_text,
        "top1_prob": top1,
        "top2_prob": top2,
        "margin": None if top1 is None else round(top1 - top2, 6),
        "confidence": confidence,
        "probabilities_returned": len(probabilities),
        "top5": [[by_text.get(option_id), probability] for option_id, probability in ranked[:5]],
        "latency_ms": round(latency_ms, 1),
        "input_tokens": input_tokens,
        "model": body.get("model"),
    }


EXPERIMENTS = {
    # (document, strategy, arm)
    "matrix": [("resume", strategy, arm)
               for strategy in ("lines", "paragraphs", "field_like")
               for arm in ("text", "index")],
    "control": [("resume", "lines", "text_plus_list")],
    "dense": [("resume", "dense", "text"), ("resume", "dense_words", "text"),
              ("resume", "dense_max", "text")],
    "labeled": [("resume_labeled", "lines", "text"), ("resume_labeled", "field_like", "text")],
    "repeat": [("resume", "field_like", "text"), ("resume", "lines", "text")],
    "ambiguity": [("resume_ambiguous", "lines", "text")],
    "ambiguity_paragraphs": [("resume_ambiguous", "paragraphs", "text")],
    # Does the surrounding document need to be in the state at all?
    "no_document": [("resume", "lines", "list_only")],
    "no_document_ambiguous": [("resume_ambiguous", "lines", "list_only")],
}


def already_done(run_label):
    if not RESULTS.exists():
        return set()
    done = set()
    for line in RESULTS.read_text().splitlines():
        row = json.loads(line)
        done.add((row["run"], row["document"], row["strategy"], row["arm"], row["field"]))
    return done


def run(experiment, run_label):
    cells = EXPERIMENTS[experiment]
    done = already_done(run_label)
    with RESULTS.open("a") as sink:
        for document_name, strategy, arm in cells:
            document_text = DOCUMENTS[document_name].read_text()
            texts = candidates.build(strategy, document_text)
            for field in FIELDS:
                if (run_label, document_name, strategy, arm, field[0]) in done:
                    continue
                record = ask(document_text, texts, field, arm)
                record.update({
                    "run": run_label,
                    "experiment": experiment,
                    "document": document_name,
                    "strategy": strategy,
                    "arm": arm,
                })
                sink.write(json.dumps(record, ensure_ascii=False) + "\n")
                sink.flush()
                print(f"{document_name}/{strategy}/{arm}/{record['field']}: "
                      f"n={record['n_candidates']} exact={record['exact']} "
                      f"top1={record['top1_prob']} margin={record['margin']} "
                      f"conf={record['confidence']} {record['latency_ms']}ms "
                      f"tok={record['input_tokens']} -> {record['chosen_text']!r}")
                time.sleep(1.0)
    print(f"billed calls this process: {jev.call_count} (http attempts: {jev.attempt_count})")


def summarize():
    rows = [json.loads(line) for line in RESULTS.read_text().splitlines() if line.strip()]
    groups = {}
    for row in rows:
        key = (row["document"], row["strategy"], row["arm"], row["run"])
        groups.setdefault(key, []).append(row)
    header = (f"{'document':<18}{'strategy':<13}{'arm':<16}{'run':<7}{'n':>4}"
              f"{'exact':>7}{'cont':>6}{'top1':>7}{'marg':>7}{'conf':>7}{'ms':>7}{'tok':>7}"
              f"{'reach':>7}")
    print(header)
    print("-" * len(header))
    for key in sorted(groups):
        items = groups[key]
        count = len(items)
        mean = lambda name: sum(item[name] or 0 for item in items) / count
        print(f"{key[0]:<18}{key[1]:<13}{key[2]:<16}{key[3]:<7}"
              f"{items[0]['n_candidates']:>4}"
              f"{sum(i['exact'] for i in items):>4}/{count}"
              f"{sum(i['contains'] for i in items):>4}/{count}"
              f"{mean('top1_prob'):>7.3f}{mean('margin'):>7.3f}{mean('confidence'):>7.3f}"
              f"{mean('latency_ms'):>7.0f}{mean('input_tokens'):>7.0f}"
              f"{sum(i.get('expected_reachable', True) for i in items):>5}/{count}")
    print(f"\ntotal records: {len(rows)}")
    print("\nmisses (exact=False):")
    for row in rows:
        if not row["exact"]:
            print(f"  {row['document']}/{row['strategy']}/{row['arm']}/{row['run']} "
                  f"{row['field']}: chose {row['chosen_text']!r} "
                  f"(p={row['top1_prob']}, conf={row['confidence']}) "
                  f"expected {row['expected']!r}")


if __name__ == "__main__":
    if sys.argv[1] == "summarize":
        summarize()
    else:
        run(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "r1")
