"""jev-context spike: how much target context does Jev need, and where does it go?

Usage (key from ~/.config/jevpaste/env, never printed):
    set -a; . ~/.config/jevpaste/env; set +a
    python3 run.py core        # 7 form fields x {L1,L2,L3} x {A,B}   = 42 calls
    python3 run.py controls    # L0 x A (7) + A2 L3 (7) + D L3 (7)   = 21 calls
    python3 run.py scenarios   # 3 scenarios x {A,B}                 =  6 calls
    python3 run.py injection   # 7 x {A,B} plain (14) + 3 x A strong =  17 calls
    python3 run.py repeat      # 5 repeats of one case                =  5 calls
    python3 run.py report      # no calls; reads results.jsonl

Results append to results.jsonl (one row per call, no credentials in the file).
"""

import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request

from source_doc import CANDIDATES, INJECTION_PLAIN, INJECTION_STRONG, SOURCE_TEXT, inject, split_candidates
from targets import AMBIGUOUS_FIELDS, FORM_FIELDS, SCENARIOS, ambiguous_context, form_context

ENDPOINT = "https://ai-gateway.vercel.sh/v1/evaluate"
MODEL = "typesafe-ai/jev"
SSL_CONTEXT = ssl.create_default_context(cafile="/etc/ssl/cert.pem")
RESULTS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results.jsonl")
CALL_BUDGET = 120  # rows; ~21 further calls were spent on the first (lost) core run and retries

QUESTION = (
    "The user copied text to the clipboard and pressed smart paste while the destination "
    "described below was focused. Every option is one exact excerpt of the copied text. "
    "Pick the single excerpt that belongs in that destination."
)
QUESTION_NAMED = (
    "`copied_text` is text the user copied to the clipboard. `target_context` describes the "
    "destination that was focused when the user pressed smart paste. Every option is one exact "
    "excerpt of `copied_text`. Pick the single excerpt that belongs in that destination."
)
QUESTION_TARGET_ONLY = (
    "`target_context` describes the destination that was focused when the user pressed smart "
    "paste. Every option is one exact excerpt of the text the user copied. Pick the single "
    "excerpt that belongs in that destination."
)


def render_context(context: dict) -> str:
    if not context:
        return "  (nothing is known about the destination)"
    lines = []
    for key, value in context.items():
        if isinstance(value, list):
            lines.append(f"  {key}:")
            lines.extend(f"    - {item}" for item in value)
        else:
            lines.append(f"  {key}: {value}")
    return "\n".join(lines)


def build_request(packing: str, source_text: str, context: dict, candidates: list[str]) -> dict:
    """packing A: source in state, target context rendered into instructions text.
    packing A2: source in state, target context embedded as JSON inside instructions.
    packing B: source text and target context together in state as a JSON object.
    packing D: target context only in state, no source text sent at all."""
    if packing == "A":
        state = source_text
        instructions = QUESTION + "\n\nDestination:\n" + render_context(context)
    elif packing == "A2":
        state = source_text
        instructions = {"target_context": context, "question": QUESTION_NAMED}
    elif packing == "B":
        state = {"copied_text": source_text, "target_context": context}
        instructions = QUESTION_NAMED
    elif packing == "D":
        state = {"target_context": context}
        instructions = QUESTION_TARGET_ONLY
    else:
        raise ValueError(packing)
    criteria = {f"c{index:02d}": text[:255] for index, text in enumerate(candidates)}
    return {
        "model": MODEL,
        "state": state,
        "questions": {"paste": {"type": "choice", "instructions": instructions, "criteria": criteria}},
    }


def call_jev(body: dict) -> tuple[dict, float]:
    request = urllib.request.Request(
        ENDPOINT,
        data=json.dumps(body).encode(),
        headers={
            "Authorization": "Bearer " + os.environ["AI_GATEWAY_API_KEY"],
            "Content-Type": "application/json",
        },
    )
    for attempt in range(6):
        started = time.time()
        try:
            with urllib.request.urlopen(request, timeout=30, context=SSL_CONTEXT) as response:
                return json.load(response), (time.time() - started) * 1000
        except urllib.error.HTTPError as error:
            if error.code in (429, 529) and attempt < 5:
                delay = 5 * (attempt + 1)
                print(f"    HTTP {error.code}, retry in {delay}s")
                time.sleep(delay)
                continue
            raise RuntimeError(f"HTTP {error.code}: {error.read()[:200]!r}") from None
    raise RuntimeError("unreachable")


def run_case(case: dict, candidates: list[str], source_text: str) -> dict:
    body = build_request(case["packing"], source_text, case["context"], candidates)
    payload, wall_ms = call_jev(body)
    answer = payload["answers"]["paste"]
    probabilities = answer["probabilities"]
    ranked = sorted(probabilities.items(), key=lambda item: -item[1])
    option_text = {f"c{index:02d}": text for index, text in enumerate(candidates)}
    chosen = option_text[answer["choice"]]
    attempt = payload["providerMetadata"]["gateway"]["routing"]["modelAttempts"][0]["providerAttempts"][0]
    row = dict(case)
    row.pop("context", None)
    row.update(
        {
            "context_keys": sorted(case["context"].keys()),
            "chosen": chosen,
            "correct": (chosen == case["expected"]) if case["expected"] is not None else None,
            "verbatim": chosen in source_text,
            "confidence": answer["confidence"],
            "top_probability": ranked[0][1],
            "runner_up": option_text[ranked[1][0]],
            "runner_up_probability": ranked[1][1],
            "top3": [[option_text[oid], prob] for oid, prob in ranked[:3]],
            "wall_ms": round(wall_ms),
            "provider_ms": attempt["endTime"] - attempt["startTime"],
            "input_tokens": payload["usage"]["inputTokens"],
            "model_reported": payload["model"],
            "candidate_count": len(candidates),
        }
    )
    return row


def append_row(row: dict) -> None:
    with open(RESULTS_PATH, "a") as handle:
        handle.write(json.dumps(row) + "\n")


def case_key(case: dict) -> tuple:
    return (
        case["stage"],
        case["target"],
        case["level"],
        case["packing"],
        case["injection"],
        case.get("repeat_index"),
    )


def existing_call_count() -> int:
    if not os.path.exists(RESULTS_PATH):
        return 0
    with open(RESULTS_PATH) as handle:
        return sum(1 for line in handle if line.strip())


def plan(stage: str) -> list[dict]:
    cases: list[dict] = []
    if stage == "core":
        for field in FORM_FIELDS:
            for level in ("L1", "L2", "L3"):
                for packing in ("A", "B"):
                    cases.append(
                        {
                            "stage": stage,
                            "target": field["id"],
                            "level": level,
                            "packing": packing,
                            "injection": None,
                            "expected": field["expected"],
                            "context": form_context(field, level),
                        }
                    )
    elif stage == "controls":
        for field in FORM_FIELDS:
            cases.append(
                {
                    "stage": stage,
                    "target": field["id"],
                    "level": "L0",
                    "packing": "A",
                    "injection": None,
                    "expected": field["expected"],
                    "context": form_context(field, "L0"),
                }
            )
        for packing in ("A2", "D"):
            for field in FORM_FIELDS:
                cases.append(
                    {
                        "stage": stage,
                        "target": field["id"],
                        "level": "L3",
                        "packing": packing,
                        "injection": None,
                        "expected": field["expected"],
                        "context": form_context(field, "L3"),
                    }
                )
    elif stage == "scenarios":
        for scenario in SCENARIOS:
            for packing in ("A", "B"):
                cases.append(
                    {
                        "stage": stage,
                        "target": scenario["id"],
                        "level": "scenario",
                        "packing": packing,
                        "injection": None,
                        "expected": scenario["expected"],
                        "context": scenario["context"],
                    }
                )
    elif stage == "injection":
        for field in FORM_FIELDS:
            for packing in ("A", "B"):
                cases.append(
                    {
                        "stage": stage,
                        "target": field["id"],
                        "level": "L3",
                        "packing": packing,
                        "injection": "plain",
                        "expected": field["expected"],
                        "context": form_context(field, "L3"),
                    }
                )
        for field in FORM_FIELDS[:3]:
            cases.append(
                {
                    "stage": stage,
                    "target": field["id"],
                    "level": "L3",
                    "packing": "A",
                    "injection": "strong",
                    "expected": field["expected"],
                    "context": form_context(field, "L3"),
                }
            )
    elif stage == "ambiguous":
        for field in AMBIGUOUS_FIELDS:
            for level in ("L1", "L2", "L3"):
                for packing in ("A", "B"):
                    cases.append(
                        {
                            "stage": stage,
                            "target": field["id"],
                            "level": level,
                            "packing": packing,
                            "injection": None,
                            "expected": field["expected"],
                            "expected_label_only": field["expected_label_only"],
                            "context": ambiguous_context(field, level),
                        }
                    )
    elif stage == "repeat":
        field = FORM_FIELDS[4]
        for index in range(3):
            cases.append(
                {
                    "stage": stage,
                    "target": field["id"],
                    "level": "L3",
                    "packing": "A",
                    "injection": None,
                    "repeat_index": index,
                    "expected": field["expected"],
                    "context": form_context(field, "L3"),
                }
            )
    else:
        raise SystemExit(f"unknown stage {stage}")
    return cases


def run_stage(stage: str) -> None:
    done = {case_key(row) for row in (load_rows() if os.path.exists(RESULTS_PATH) else [])}
    cases = [case for case in plan(stage) if case_key(case) not in done]
    already = existing_call_count()
    if already + len(cases) > CALL_BUDGET:
        raise SystemExit(f"budget: {already} calls used, {len(cases)} planned, cap {CALL_BUDGET}")
    for index, case in enumerate(cases, 1):
        if case["injection"] == "plain":
            source_text = inject(SOURCE_TEXT, INJECTION_PLAIN)
        elif case["injection"] == "strong":
            source_text = inject(SOURCE_TEXT, INJECTION_STRONG)
        else:
            source_text = SOURCE_TEXT
        candidates = split_candidates(source_text) if case["injection"] else CANDIDATES
        row = run_case(case, candidates, source_text)
        append_row(row)
        flag = "ok " if row["correct"] else ("?? " if row["correct"] is None else "MISS")
        print(
            f"{index:3d}/{len(cases)} {flag} {case['target']:16s} {case['level']:8s} "
            f"{case['packing']:2s} inj={str(case['injection']):6s} conf={row['confidence']:.3f} "
            f"p={row['top_probability']:.3f} {row['provider_ms']:4d}ms tok={row['input_tokens']:5d} "
            f"-> {row['chosen'][:44]!r}"
        )
        time.sleep(0.4)
    print(f"stage {stage}: {len(cases)} calls, total rows now {existing_call_count()}")


def load_rows() -> list[dict]:
    with open(RESULTS_PATH) as handle:
        return [json.loads(line) for line in handle if line.strip()]


def mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else float("nan")


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(fraction * len(ordered)))]


def report() -> None:
    rows = load_rows()
    print(f"rows: {len(rows)}   models: {sorted({row['model_reported'] for row in rows})}")
    print(f"verbatim violations: {sum(1 for row in rows if not row['verbatim'])}")
    print("\n== accuracy by level x packing (form fields, no injection) ==")
    print(f"{'level':8s} {'pack':4s} {'n':>3s} {'acc':>6s} {'conf(hit)':>10s} {'conf(miss)':>11s} {'tokens':>7s} {'ms':>6s}")
    keys = sorted({(row["level"], row["packing"]) for row in rows if row["stage"] in ("core", "controls")})
    for level, packing in keys:
        group = [r for r in rows if r["stage"] in ("core", "controls") and r["level"] == level and r["packing"] == packing]
        hits = [r for r in group if r["correct"]]
        misses = [r for r in group if r["correct"] is False]
        print(
            f"{level:8s} {packing:4s} {len(group):3d} {len(hits)/len(group):6.2f} "
            f"{mean([r['confidence'] for r in hits]):10.3f} {mean([r['confidence'] for r in misses]):11.3f} "
            f"{mean([r['input_tokens'] for r in group]):7.0f} {mean([r['provider_ms'] for r in group]):6.0f}"
        )
    print("\n== per-target detail ==")
    for row in rows:
        if row["stage"] not in ("core", "controls"):
            continue
        if row["correct"]:
            continue
        print(
            f"MISS {row['target']:12s} {row['level']:3s} {row['packing']:3s} conf={row['confidence']:.3f} "
            f"p={row['top_probability']:.3f} chose={row['chosen'][:40]!r} (want {str(row['expected'])[:30]!r}) "
            f"runner_up={row['runner_up'][:30]!r} p={row['runner_up_probability']:.3f}"
        )
    print("\n== ambiguous targets (label alone underdetermined) ==")
    for row in [r for r in rows if r["stage"] == "ambiguous"]:
        label_only = row["chosen"] == row.get("expected_label_only")
        print(
            f"{row['target']:12s} {row['level']:3s} {row['packing']:3s} conf={row['confidence']:.3f} "
            f"p={row['top_probability']:.3f} chose={row['chosen'][:38]!r} "
            f"full_ctx_answer={bool(row['correct'])} label_only_answer={label_only}"
        )

    print("\n== scenarios ==")
    for row in [r for r in rows if r["stage"] == "scenarios"]:
        print(
            f"{row['target']:18s} {row['packing']:3s} conf={row['confidence']:.3f} "
            f"top3={[[t[:26], round(p,3)] for t, p in row['top3']]} correct={row['correct']}"
        )
    print("\n== injection ==")
    for injection_kind in ("plain", "strong"):
        group = [r for r in rows if r.get("injection") == injection_kind]
        if not group:
            continue
        injection_text = INJECTION_PLAIN if injection_kind == "plain" else INJECTION_STRONG
        picked = [r for r in group if r["chosen"] == injection_text]
        print(f"{injection_kind}: n={len(group)} picked_injection={len(picked)} correct={sum(1 for r in group if r['correct'])}")
        for row in group:
            probabilities = dict((text, probability) for text, probability in row["top3"])
            in_top3 = "yes" if injection_text in probabilities else "no"
            print(
                f"  {row['target']:12s} {row['packing']:3s} conf={row['confidence']:.3f} "
                f"p_top={row['top_probability']:.3f} inj_in_top3={in_top3} "
                f"runner_up={row['runner_up'][:26]!r} p={row['runner_up_probability']:.3f}"
            )
    print("\n== packing A vs B, matched pairs (same stage/target/level/injection) ==")
    paired = {}
    for row in rows:
        if row["packing"] in ("A", "B") and row["stage"] != "repeat":
            paired.setdefault((row["stage"], row["target"], row["level"], row["injection"]), {})[row["packing"]] = row
    both = [pair for pair in paired.values() if "A" in pair and "B" in pair]
    deltas = [pair["A"]["confidence"] - pair["B"]["confidence"] for pair in both]
    disagreements = [pair for pair in both if pair["A"]["chosen"] != pair["B"]["chosen"]]
    print(
        f"pairs={len(both)} same_choice={len(both) - len(disagreements)} "
        f"mean conf A-B = {mean(deltas):+.3f} (A higher in {sum(1 for d in deltas if d > 0)}, "
        f"B higher in {sum(1 for d in deltas if d < 0)}, tie {sum(1 for d in deltas if d == 0)})"
    )
    for pair in disagreements:
        print(f"  disagree {pair['A']['target']} {pair['A']['level']}: A={pair['A']['chosen'][:30]!r} B={pair['B']['chosen'][:30]!r}")
    print(
        f"mean input tokens: A {mean([p['A']['input_tokens'] for p in both]):.0f} "
        f"vs B {mean([p['B']['input_tokens'] for p in both]):.0f}"
    )

    print("\n== confidence separation (all scored rows) ==")
    scored = [row for row in rows if row["correct"] is not None]
    hits = [row["confidence"] for row in scored if row["correct"]]
    misses = [row["confidence"] for row in scored if not row["correct"]]
    no_match = [row["confidence"] for row in rows if row["target"] == "terminal_github"]
    print(f"hits   n={len(hits)} min {min(hits):.2f} p05 {percentile(hits, 0.05):.2f} mean {mean(hits):.3f}")
    print(f"misses n={len(misses)} min {min(misses):.2f} max {max(misses):.2f} mean {mean(misses):.3f}")
    print(f"no-match probe n={len(no_match)} values {sorted(no_match)}")
    for threshold in (0.5, 0.75, 0.85, 0.9, 0.95):
        kept_hits = sum(1 for value in hits if value >= threshold)
        kept_misses = sum(1 for value in misses if value >= threshold)
        kept_nomatch = sum(1 for value in no_match if value >= threshold)
        print(
            f"  threshold {threshold:.2f}: auto-insert {kept_hits}/{len(hits)} hits, "
            f"{kept_misses}/{len(misses)} misses, {kept_nomatch}/{len(no_match)} no-match probes"
        )

    print("\n== latency / tokens (all calls) ==")
    wall = [r["wall_ms"] for r in rows]
    provider = [r["provider_ms"] for r in rows]
    print(
        f"provider mean {mean(provider):.0f} ms, p50 {percentile(provider, 0.5):.0f}, p95 {percentile(provider, 0.95):.0f}, max {max(provider)}\n"
        f"wall     mean {mean(wall):.0f} ms, p50 {percentile(wall, 0.5):.0f}, p95 {percentile(wall, 0.95):.0f}, max {max(wall)}"
    )
    print("\n== repeat determinism ==")
    for row in [r for r in rows if r["stage"] == "repeat"]:
        print(f"  repeat {row.get('repeat_index')}: {row['chosen']!r} conf={row['confidence']:.4f} p={row['top_probability']:.4f}")


if __name__ == "__main__":
    stage_name = sys.argv[1] if len(sys.argv) > 1 else "report"
    if stage_name == "report":
        report()
    else:
        run_stage(stage_name)
