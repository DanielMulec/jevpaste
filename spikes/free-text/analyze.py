"""Summarise spikes/free-text/results/raw.jsonl (no API calls). Prints Markdown."""

import json
import os
import statistics

import situations

HERE = os.path.dirname(os.path.abspath(__file__))
RAW_PATH = os.path.join(HERE, "results", "raw.jsonl")


def load():
    with open(RAW_PATH) as handle:
        return [json.loads(line) for line in handle if line.strip()]


def _answers(record):
    return (record.get("response") or {}).get("answers") or {}


def _free(record):
    return (_answers(record).get("free_text") or {}).get("probability")


def _gate(record):
    return (_answers(record).get("contains_value") or {}).get("probability")


def _choice(record):
    choice = (_answers(record).get("paste") or {}).get("choice")
    text = record["candidate_map"].get(choice)
    return "none_of_these" if choice == "none_of_these" else "%s `%s`" % (choice, (text or "")[:28])


def _lat(values):
    ordered = sorted(values)
    return "n=%d min=%.0f median=%.0f mean=%.0f max=%.0f" % (
        len(ordered), ordered[0], statistics.median(ordered), statistics.mean(ordered), ordered[-1])


def report():
    records = load()
    main = [r for r in records if r["kind"] == "main"]
    print("calls logged: %d (%s)" % (
        len(records),
        ", ".join("%s=%d" % (k, sum(1 for r in records if r["kind"] == k))
                  for k in ("smoke", "main", "no_app_title", "baseline2q"))))
    cost = sum(float(((r["response"].get("providerMetadata") or {}).get("gateway") or {}).get("marketCost", 0))
               for r in records)
    billed = sum(float(((r["response"].get("providerMetadata") or {}).get("gateway") or {}).get("cost", 0))
                 for r in records)
    print("marketCost total $%.6f, billed cost $%.6f\n" % (cost, billed))

    print("| Situation | expect | free_text runs | min | max | pass | contains_value runs | paste choice runs |")
    print("|---|---|---|---|---|---|---|---|")
    verdicts = []
    for situation_id, group, label, _ in situations.SITUATIONS:
        runs = sorted((r for r in main if r["situation"] == situation_id), key=lambda r: r["run"])
        free = [_free(r) for r in runs]
        ok = all(p >= 0.8 for p in free) if group == "free" else all(p <= 0.2 for p in free)
        verdicts.append(ok)
        print("| %s (%s) | %s | %s | %.2f | %.2f | %s | %s | %s |" % (
            situation_id, label, "≥ 0.8" if group == "free" else "≤ 0.2",
            " / ".join("%.2f" % p for p in free), min(free), max(free), "yes" if ok else "**NO**",
            " / ".join("%.2f" % _gate(r) for r in runs),
            " / ".join(_choice(r) for r in runs)))
    print("\nsituations passing: %d/%d\n" % (sum(verdicts), len(verdicts)))

    print("ablation (no app_name/window_title) vs main-run mean:")
    for r in (r for r in records if r["kind"] == "no_app_title"):
        base = [_free(m) for m in main if m["situation"] == r["situation"]]
        print("  %s: free_text %.2f (with: mean %.3f), contains_value %.2f, paste %s, keys %s" % (
            r["situation"], _free(r), statistics.mean(base), _gate(r), _choice(r), r["context_keys"]))

    three = [r["latency_ms"] for r in records if r["kind"] in ("smoke", "main", "no_app_title")]
    two = [r["latency_ms"] for r in records if r["kind"] == "baseline2q"]
    same = {r["situation"] for r in records if r["kind"] == "baseline2q"}
    three_same = [r["latency_ms"] for r in main if r["situation"] in same]
    print("\nlatency ms, 3 questions (all):          %s" % _lat(three))
    print("latency ms, 3 questions (same 4 sits.): %s" % _lat(three_same))
    print("latency ms, 2 questions baseline:       %s" % _lat(two))
    for kind in ("main", "baseline2q"):
        usage = [r["response"].get("usage") or {} for r in records if r["kind"] == kind and r["situation"] in same]
        print("tokens %-10s (same sits.): input mean %.0f, output mean %.0f" % (
            kind, statistics.mean(u["inputTokens"] for u in usage), statistics.mean(u["outputTokens"] for u in usage)))


if __name__ == "__main__":
    report()
