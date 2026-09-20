"""Two contract probes: the 255-option ceiling, and one raw response for the record."""

import json
import pathlib

import candidates
import jev
from run_probe import FIELDS, QUESTION, build_question

HERE = pathlib.Path(__file__).parent


def instructions_for(field):
    _, label, placeholder, section, _ = field
    return {
        "target_field": {"form": "Product Designer Application", "section": section,
                         "label": label, "placeholder": placeholder},
        "question": QUESTION,
    }


def probe_option_ceiling(document_text, option_count):
    texts = candidates.deduplicate_verbatim(
        candidates.dense(document_text, include_words=True, max_words_per_line=14, max_ngram=4),
        document_text,
    )[:option_count]
    _, criteria, _, _ = build_question("text", texts, FIELDS[0])
    print(f"options sent: {len(criteria)}")
    try:
        body, latency_ms, tokens = jev.evaluate(
            {"copied_text": document_text},
            {"excerpt": {"type": "choice", "instructions": instructions_for(FIELDS[0]),
                         "criteria": criteria}},
        )
        print(f"  accepted: choice={body['answers']['excerpt']['choice']} "
              f"{latency_ms:.0f}ms tokens={tokens}")
    except RuntimeError as error:
        print(f"  rejected: {error}")


def dump_raw_response(document_text):
    texts = candidates.build("lines", document_text)
    _, criteria, _, _ = build_question("text", texts, FIELDS[4])
    body, latency_ms, _ = jev.evaluate(
        {"copied_text": document_text},
        {"excerpt": {"type": "choice", "instructions": instructions_for(FIELDS[4]),
                     "criteria": criteria}},
    )
    target = HERE / "raw_response_example.json"
    target.write_text(json.dumps(body, indent=2, ensure_ascii=False) + "\n")
    print(f"raw response written to {target.name} ({latency_ms:.0f}ms)")


if __name__ == "__main__":
    text = (HERE / "source_resume.txt").read_text()
    probe_option_ceiling(text, 256)
    probe_option_ceiling(text, 300)
    dump_raw_response(text)
    print(f"billed calls: {jev.call_count} (http attempts: {jev.attempt_count})")
