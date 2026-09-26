#!/usr/bin/env python3
"""Extracts the Narrowing test fixtures from the spike branch (issue #49, design `r2b`) into the test targets.

Usage (from the repository root):
    rm -rf /tmp/narrowing-spike && mkdir /tmp/narrowing-spike
    git archive spike/narrowing spikes | tar -x -C /tmp/narrowing-spike
    python3 scripts/extract-narrowing-fixtures.py /tmp/narrowing-spike

Writes, one JSON value per line (the line guard counts lines):
  Tests/SmartPasteCoreTests/Fixtures/narrowing-cells.jsonl
      every round-1 and round-2 cell whose copy fits one request (N04, 216k characters, is left out, as in the
      spike's `reach`): {"id", "item", "context", "targets"}; `context` = the production-shaped `target_context`,
      `targets` = the expected excerpt and the accepted ones.
  Tests/JevGatewayTests/Fixtures/narrowing-replay.jsonl
      run 0 of the recorded `r2b` pastes listed in REPLAY_CELLS: {"cell", "calls": [{"request", "answers"}],
      "outcome", "final", "chooser"}. `request` is the body the spike sent, parsed from `raw.jsonl` and re-serialised
      compact with `json.dumps(ensure_ascii=False, separators=(",", ":"))` — key order kept — after removing the
      measurement-only `place` question; `answers` is the response's `answers` without `place` (usage and
      provider metadata dropped).
All data is synthetic (the spike's own fixtures).
"""

import json
import os
import sys

REPLAY_CELLS = [
    "A04_hausnummer", "S04_phone", "A13_passwort_NEG", "T01_email_two_lines", "R05_about", "C02_motivation",
    "B06_biography", "K01_three_emails", "N01_address_line_ort", "N02_url_chat", "N03_list_300_lines",
    "H06_company_description", "H11_two_emails_catering", "W02_terminal_prompt",
]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELLS_OUT = os.path.join(ROOT, "Tests/SmartPasteCoreTests/Fixtures/narrowing-cells.jsonl")
REPLAY_OUT = os.path.join(ROOT, "Tests/JevGatewayTests/Fixtures/narrowing-replay.jsonl")
TOO_BIG_FOR_ONE_REQUEST = 30000  # characters; the spike's `reach` skipped these as well


def compact(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def load_cells(spikes):
    narrowing = os.path.join(spikes, "narrowing")
    sys.path[:0] = [os.path.join(narrowing, "round2"), narrowing]
    for sub in ("any-field", "free-text", "abstention"):
        sys.path.append(os.path.join(spikes, sub))
    import cells  # noqa: E402
    import heldout  # noqa: E402
    return cells.CELLS + heldout.HELDOUT


def write_cells(all_cells):
    with open(CELLS_OUT, "w") as out:
        for cell in all_cells:
            if len(cell["item"]) > TOO_BIG_FOR_ONE_REQUEST:
                continue
            targets = ([cell["expected"]] if cell["expected"] else []) + list(cell["accept"])
            row = {"id": cell["id"], "item": cell["item"], "context": cell["context"], "targets": targets}
            out.write(compact(row) + "\n")


def replay_rows(raw_path):
    with open(raw_path) as handle:
        rows = [json.loads(line) for line in handle if line.strip()]
    for cell_id in REPLAY_CELLS:
        phase = "matrix2-n03fix" if cell_id == "N03_list_300_lines" else "matrix2"
        paste = next(r for r in rows if r.get("kind") == "paste" and r["phase"] == phase and r["cell"] == cell_id
                     and r["run"] == 0)
        calls = [r for r in rows if r.get("kind") == "call" and r["phase"] == phase and r["cell"] == cell_id
                 and r["run"] == 0 and r["status"] == 200]
        recorded = []
        for call in calls:
            request = call["request"]
            request["questions"].pop("place", None)
            answers = call["response"]["answers"]
            answers.pop("place", None)
            recorded.append({"request": compact(request), "answers": answers})
        yield {"cell": cell_id, "calls": recorded, "outcome": paste["outcome"], "final": paste["final"],
               "chooser": paste["chooser"]}


def main():
    spikes = os.path.join(sys.argv[1], "spikes")
    write_cells(load_cells(spikes))
    with open(REPLAY_OUT, "w") as out:
        for row in replay_rows(os.path.join(spikes, "narrowing", "round2", "results", "raw.jsonl")):
            out.write(compact(row) + "\n")


if __name__ == "__main__":
    main()
