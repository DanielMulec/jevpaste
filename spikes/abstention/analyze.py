"""Summarise spikes/abstention/results/raw.jsonl (no API calls)."""

import json
import os
import statistics

RAW_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results", "raw.jsonl")


def _fmt(value):
    return "n/a" if value is None else "%.3f" % value


def load():
    """Read raw.jsonl, relabelling metadata lines (they carry no `answers`)."""
    records = []
    with open(RAW_PATH) as handle:
        for line in handle:
            if not line.strip():
                continue
            record = json.loads(line)
            if "answers" not in record:
                record["kind"] = "meta_score" if "scored_excerpt" in record else "meta"
            records.append(record)
    return records


def report():
    records = load()
    batches = [r for r in records if r["kind"] == "batch"]
    metas = {(r["case"], r["repeat"]): r for r in records if r["kind"] == "meta"}
    scores = [r for r in records if r["kind"] == "score"]
    score_meta = {(r["case"], r["repeat"]): r for r in records if r["kind"] == "meta_score"}

    print("total logged calls: %d (batch=%d score=%d single=%d)" % (
        len([r for r in records if r["kind"].startswith(("batch", "score", "single"))]),
        len(batches),
        len(scores),
        len([r for r in records if r["kind"].startswith("single")]),
    ))
    latencies = [
        r["latency_ms"]
        for r in records
        if "latency_ms" in r and not r["kind"].startswith("meta")
    ]
    tokens = [
        (r.get("usage") or {}).get("inputTokens")
        for r in records
        if r["kind"] in ("batch", "score") and r.get("usage")
    ]
    tokens = [t for t in tokens if t]
    if latencies:
        ordered = sorted(latencies)
        print(
            "latency ms: n=%d min=%.0f median=%.0f p95=%.0f max=%.0f"
            % (
                len(ordered),
                ordered[0],
                statistics.median(ordered),
                ordered[int(0.95 * (len(ordered) - 1))],
                ordered[-1],
            )
        )
    if tokens:
        print(
            "input tokens: min=%d median=%d max=%d"
            % (min(tokens), int(statistics.median(tokens)), max(tokens))
        )

    per_case = {}
    header = (
        "%-20s %-24s %-6s %-6s %-6s %-9s %-6s %-6s %-6s %-6s"
        % ("case", "plain top", "p1", "margin", "conf", "none top", "p_none", "gate+", "gate-", "score")
    )
    print("\n" + header)
    print("-" * len(header))
    for record in batches:
        meta = metas.get((record["case"], record["repeat"]), {})
        index_of = meta.get("candidate_map", {})
        answers = record["answers"] or {}
        plain = answers.get("choice_plain") or {}
        none = answers.get("choice_none") or {}
        probabilities = sorted((plain.get("probabilities") or {}).values(), reverse=True)
        top = plain.get("choice")
        p1 = probabilities[0] if probabilities else float("nan")
        p2 = probabilities[1] if len(probabilities) > 1 else 0.0
        none_probabilities = none.get("probabilities") or {}
        score_record = next(
            (
                s
                for s in scores
                if s["case"] == record["case"] and s["repeat"] == record["repeat"]
            ),
            None,
        )
        score_answer = ((score_record or {}).get("answers") or {}).get("fit_score") or {}
        row = {
            "top": (index_of.get(top, top) or "?").replace("\n", " "),
            "p1": p1,
            "margin": p1 - p2,
            "conf_plain": plain.get("confidence"),
            "none_top": none.get("choice"),
            "conf_none": none.get("confidence"),
            "p_none": none_probabilities.get("none_of_these"),
            "gate_pos": (answers.get("gate_pos") or {}).get("probability"),
            "gate_neg": (answers.get("gate_neg") or {}).get("probability"),
            "score": score_answer.get("score"),
            "score_conf": score_answer.get("confidence"),
        }
        per_case.setdefault(record["case"], []).append(row)
        print(
            "%-20s %-24s %-6.3f %-6.3f %-6.3f %-9s %-6.3f %-6.3f %-6.3f %-6s"
            % (
                record["case"],
                row["top"][:24],
                p1,
                row["margin"],
                row["conf_plain"],
                (row["none_top"] or "?")[:9],
                row["p_none"] if row["p_none"] is not None else float("nan"),
                row["gate_pos"],
                row["gate_neg"],
                _fmt(row["score"]),
            )
        )
    _ = score_meta

    aggregate_header = (
        "%-20s %-24s %-13s %-13s %-13s %-13s %-13s %-9s"
        % ("case", "top pick (all reps)", "p1", "conf_plain", "conf_none", "gate+", "score", "p_none")
    )
    print("\n" + aggregate_header)
    print("-" * len(aggregate_header))
    for case_id, rows in per_case.items():
        tops = {row["top"] for row in rows}
        none_tops = {row["none_top"] for row in rows}
        print(
            "%-20s %-24s %-13s %-13s %-13s %-13s %-13s %-9s"
            % (
                case_id,
                ("|".join(sorted(tops)))[:24],
                _range(rows, "p1"),
                _range(rows, "conf_plain"),
                _range(rows, "conf_none"),
                _range(rows, "gate_pos"),
                _range(rows, "score"),
                _range(rows, "p_none"),
            )
        )
        if len(none_tops) > 1 or tops != {rows[0]["top"]}:
            print("    unstable: plain=%s none=%s" % (sorted(tops), sorted(none_tops)))
    bands(per_case)


# ground truth per case, assigned before the calls were made
TRUTH = {
    "C1_email_control": "exact",
    "C2_name_control": "exact",
    "C3_company_soft": "exact",
    "F_location_nested": "exact",
    "A_email_three": "ambiguous",
    "A2_email_two_peer": "ambiguous",
    "E1_header_name": "ambiguous",
    "E2_header_email": "ambiguous",
    "B1_postal_absent": "no_match",
    "B2_postal_citystate": "no_match",
    "D1_recipe_name": "no_match",
    "D2_recipe_email": "no_match",
}

SIGNALS = ("p1", "conf_plain", "conf_none", "p_none", "gate_pos", "gate_neg", "score")


def bands(per_case):
    """Per-signal value ranges grouped by ground truth, plus overlap checks."""
    grouped = {}
    for case_id, rows in per_case.items():
        grouped.setdefault(TRUTH[case_id], []).extend(rows)
    print("\nsignal ranges by ground truth (n reps per group: %s)" % {
        label: len(rows) for label, rows in grouped.items()
    })
    print(
        "%-11s %-12s %-12s %-12s %-20s %s"
        % ("signal", "exact", "ambiguous", "no_match", "no_match gap", "exact|ambiguous gap")
    )
    for signal in SIGNALS:
        spans = {
            label: [row[signal] for row in rows if row.get(signal) is not None]
            for label, rows in grouped.items()
        }
        answerable = spans["exact"] + spans["ambiguous"]
        print(
            "%-11s %-12s %-12s %-12s %-20s %s"
            % (
                signal,
                "%.2f-%.2f" % (min(spans["exact"]), max(spans["exact"])),
                "%.2f-%.2f" % (min(spans["ambiguous"]), max(spans["ambiguous"])),
                "%.2f-%.2f" % (min(spans["no_match"]), max(spans["no_match"])),
                _gap(spans["no_match"], answerable),
                _gap(spans["ambiguous"], spans["exact"]),
            )
        )

    print("\nfalse-positive risk of choice probability alone (no none_of_these option):")
    no_match_rows = grouped["no_match"]
    for threshold in (0.7, 0.8, 0.9, 0.95):
        hits = [row for row in no_match_rows if row["p1"] >= threshold]
        print(
            "  p1 >= %.2f would auto-insert %d/%d no-match reps: %s"
            % (
                threshold,
                len(hits),
                len(no_match_rows),
                sorted({row["top"][:24] for row in hits}) or "-",
            )
        )


def _gap(left, right):
    """Report the separating interval between two value groups, or 'overlap'."""
    if statistics.mean(left) < statistics.mean(right):
        low, high = left, right
    else:
        low, high = right, left
    if max(low) < min(high):
        return "%.2f < x < %.2f" % (max(low), min(high))
    return "overlap"


def _range(rows, key):
    values = [row[key] for row in rows if row.get(key) is not None]
    if not values:
        return "-"
    if min(values) == max(values):
        return "%.2f" % values[0]
    return "%.2f-%.2f" % (min(values), max(values))


if __name__ == "__main__":
    report()
