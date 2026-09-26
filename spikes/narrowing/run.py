"""Narrowing spike: choice-only Narrowing on the any-field matrix and the new cells (ticket #49).

Usage (key exported, never printed):
    set -a; . ~/.config/jevpaste/env; set +a
    python3 run.py reach                     # offline: reachability, options and calls per paste (no Jev)
    python3 run.py wordings                  # print every wording verbatim
    python3 run.py smoke CELL...             # run index -1, one paste per listed cell
    python3 run.py matrix RUN [CELL|GROUP...] # run index RUN (0 or 1); resumes: skips (cell, run) already logged
    python3 run.py probe                     # too-big: find the size where Jev starts refusing

Every request and response is appended verbatim to results/raw.jsonl.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.append(os.path.join(HERE, "..", "abstention"))

import jev  # noqa: E402  (endpoint, model id, SSL context reused from spikes/abstention)

import cells  # noqa: E402
import cuts  # noqa: E402

RAW_PATH = os.path.join(HERE, "results", "raw.jsonl")
BUDGET = 900          # billed Jev calls for the whole spike (brief)
MAX_STEPS = 10        # safety net; every step strictly shrinks the piece, so this is never reached in practice
PACING_SECONDS = 0.7  # free tier
TIMEOUT_SECONDS = 60

# ============================================================================================== WORDINGS
# Place-neutral: no field types, no place types, no examples. The same wording at every step; the first step has no
# `current_piece` (it would be the whole copy again) and its "unchanged" option is "everything that was copied".

INSTRUCTIONS_FIRST = (
    "The user copied `source_document` and is pasting into the place described by `target_context`. "
    "One option is everything that was copied, as it is. Every other excerpt option is an exact excerpt cut from "
    "`source_document`; its description is that excerpt, character for character. "
    "Choose the option that is exactly what the user means to paste into `target_context`. "
    "If no option is exactly that, choose the smallest option that contains all of it."
)
INSTRUCTIONS_LATER = (
    "The user copied `source_document` and is pasting into the place described by `target_context`. "
    "`current_piece` is an exact excerpt of `source_document`. "
    "One option is `current_piece` kept as it is. Every other excerpt option is a smaller exact excerpt cut from "
    "`current_piece`; its description is that excerpt, character for character. "
    "Choose the option that is exactly what the user means to paste into `target_context`. "
    "If no option is exactly that, choose the smallest option that contains all of it."
)
KEEP_WHOLE = "Everything that was copied, as it is: all of `source_document`, nothing cut away."
KEEP_PIECE = "`current_piece` as it is, nothing cut away."
NOTHING_FITS = (
    "Nothing that was copied belongs in `target_context`: no part of `source_document` is what the user means "
    "to paste there."
)
ASK_USER = (
    "Two or more different excerpts could each be what the user means to paste into `target_context`, and "
    "nothing in `target_context` says which one; the user has to pick."
)
KEEP, NOTHING, ASK = "keep", "nothing_fits", "ask_user"


def question(piece, is_first, pieces):
    """One choice: `piece` unchanged, `pieces` (full text), nothing fits, ask the user. Returns (ids, question)."""
    ids = {KEEP: piece}
    criteria = {KEEP: KEEP_WHOLE if is_first else KEEP_PIECE}
    for index, text in enumerate(pieces):
        oid = "e%03d" % index
        ids[oid] = text
        criteria[oid] = text
    criteria[NOTHING] = NOTHING_FITS
    criteria[ASK] = ASK_USER
    instructions = INSTRUCTIONS_FIRST if is_first else {"current_piece": piece, "question": INSTRUCTIONS_LATER}
    return ids, {"type": "choice", "instructions": instructions, "criteria": criteria}


def state_for(cell):
    return {"source_document": cell["item"], "target_context": cell["context"]}


def budget_for(cell, piece):
    """Size budget of one step: the state, plus per question the instructions (with `current_piece` after step 1) and
    the three fixed options."""
    first = piece == cell["item"]
    fixed = (INSTRUCTIONS_FIRST if first else INSTRUCTIONS_LATER + piece) + (KEEP_WHOLE if first else KEEP_PIECE) \
        + NOTHING_FITS + ASK_USER
    return cuts.Budget(cuts.est_tokens(json.dumps(state_for(cell), ensure_ascii=False)),
                       cuts.QUESTION_TOKENS + cuts.est_tokens(fixed) + 3 * cuts.OPTION_TOKENS)


def children_for(cell, piece):
    return cuts.children(piece, budget_for(cell, piece))


def chunks_for(cell, piece, kids):
    return budget_for(cell, piece).chunk(kids)


# ============================================================================================== PLUMBING
def rows():
    if not os.path.exists(RAW_PATH):
        return []
    with open(RAW_PATH) as handle:
        return [json.loads(line) for line in handle if line.strip()]


def billed_so_far():
    return sum(1 for r in rows() if r.get("billed"))


def log(record):
    os.makedirs(os.path.dirname(RAW_PATH), exist_ok=True)
    with open(RAW_PATH, "a") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


_last_call_at = 0.0
_process_calls = 0


class Stop(Exception):
    pass


def post(state, questions, attempts=8):
    """POST one evaluation. Returns (status, body_text, latency_ms, waits). 429/529/5xx are retried after
    `retry-after`; the latency covers only the successful (or final) attempt; waits are reported separately."""
    global _last_call_at
    key = os.environ.get("AI_GATEWAY_API_KEY")
    if not key:
        raise Stop("AI_GATEWAY_API_KEY is not set: set -a; . ~/.config/jevpaste/env; set +a")
    body = json.dumps({"model": jev.MODEL, "state": state, "questions": questions}).encode("utf-8")
    waits = []
    for attempt in range(attempts):
        gap = time.monotonic() - _last_call_at
        if gap < PACING_SECONDS:
            time.sleep(PACING_SECONDS - gap)
        request = urllib.request.Request(jev.ENDPOINT, data=body, method="POST", headers={
            "Authorization": "Bearer " + key, "Content-Type": "application/json"})
        started = time.monotonic()
        _last_call_at = started
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS, context=jev.SSL_CONTEXT) as response:
                text = response.read().decode("utf-8")
            return 200, text, (time.monotonic() - started) * 1000.0, waits, len(body)
        except urllib.error.HTTPError as error:
            latency = (time.monotonic() - started) * 1000.0
            text = error.read().decode("utf-8", "replace")
            if error.code == 401:
                raise Stop("HTTP 401: " + text[:300])
            if error.code in (429, 529, 500, 502, 503) and attempt < attempts - 1:
                retry_after = error.headers.get("retry-after") if error.headers else None
                delay = float(retry_after) if retry_after else min(60.0, 2.0 * 2 ** attempt)
                waits.append({"status": error.code, "retry_after": retry_after, "slept_s": delay,
                              "body": text[:300]})
                print("  %d, waiting %.0f s" % (error.code, delay), flush=True)
                time.sleep(delay)
                continue
            return error.code, text, latency, waits, len(body)
        except Exception as error:  # network / timeout
            waits.append({"status": None, "error": "%s: %s" % (type(error).__name__, error)})
            if attempt < attempts - 1:
                time.sleep(3.0 * (attempt + 1))
                continue
            return None, "%s: %s" % (type(error).__name__, error), 0.0, waits, len(body)
    raise RuntimeError("unreachable")


def evaluate(state, questions, meta):
    """One call, logged verbatim. Returns (status, payload_or_text, record)."""
    global _process_calls
    if billed_so_far() >= BUDGET:
        raise Stop("budget of %d billed Jev calls reached" % BUDGET)
    status, text, latency, waits, request_bytes = post(state, questions)
    cold = _process_calls == 0
    _process_calls += 1
    try:
        payload = json.loads(text)
    except Exception:
        payload = None
    record = dict(meta)
    record.update({
        "kind": "call", "billed": status == 200, "status": status, "cold": cold, "latency_ms": round(latency, 1),
        "waits": waits, "request_bytes": request_bytes,
        "request": {"model": jev.MODEL, "state": state, "questions": questions},
        "response": payload if payload is not None else text, "timestamp": time.time(),
    })
    log(record)
    return status, payload if payload is not None else text, record


# ============================================================================================== NARROWING
def probabilities_text(ids, answer):
    probs = answer.get("probabilities") or {}
    return sorted(((p, oid, ids.get(oid)) for oid, p in probs.items()), key=lambda x: -x[0])


def one_step(cell, run, step, piece):
    """Ask Jev one Narrowing step for `piece`. Returns (winner_id, winner_text, step_record, calls, error)."""
    first = piece == cell["item"]
    kids, how = children_for(cell, piece)
    chunks = chunks_for(cell, piece, kids)
    state = state_for(cell)
    meta = {"cell": cell["id"], "run": run, "step": step}
    step_record = {"step": step, "piece": piece, "how": how, "options": len(kids) + 1, "choices": len(chunks),
                   "calls": []}
    questions, id_maps = {}, {}
    for k, part in enumerate(chunks):
        ids, q = question(piece, first, part)
        qid = "narrow" if len(chunks) == 1 else "narrow_%d" % k
        questions[qid] = q
        id_maps[qid] = ids
    status, payload, rec = evaluate(state, questions, dict(meta, sub="choice", option_maps=id_maps))
    step_record["calls"].append({"sub": "choice", "status": status, "latency_ms": rec["latency_ms"],
                                 "cold": rec["cold"], "questions": len(questions),
                                 "request_bytes": rec["request_bytes"]})
    if status != 200:
        return None, None, step_record, 1, {"status": status, "body": payload}
    answers = payload.get("answers") or {}

    if len(chunks) == 1:
        ids = id_maps["narrow"]
        answer = answers.get("narrow") or {}
        return _decide(ids, answer, step_record) + (1, None)

    # several choices in one request -> follow-up among their winners
    per_chunk, carried = [], {}
    for qid, ids in id_maps.items():
        answer = answers.get(qid) or {}
        ranked = probabilities_text(ids, answer)
        per_chunk.append({"question": qid, "choice": answer.get("choice"),
                          "choice_text": ids.get(answer.get("choice")),
                          "top": [(p, o, t) for p, o, t in ranked[:5]]})
        for p, oid, text in ranked:
            if oid in (KEEP, NOTHING, ASK) or p < 0.01:
                continue
            carried[text] = max(carried.get(text, 0), p)
    step_record["chunk_winners"] = per_chunk
    winners = {c["choice"] for c in per_chunk}
    if len(winners) == 1 and next(iter(winners)) in (KEEP, NOTHING, ASK):
        # every choice agrees on the same non-piece option: no follow-up needed
        ids = id_maps["narrow_0"]
        answer = answers.get("narrow_0") or {}
        step_record["follow_up"] = "skipped (all choices agree)"
        return _decide(ids, answer, step_record) + (1, None)
    order = sorted(carried, key=lambda t: -carried[t])[:cuts.PIECES_PER_CHOICE - 1]
    step_record["carried"] = len(carried)
    step_record["carried_cut"] = len(carried) - len(order)  # must stay 0; reported in FINDINGS if not
    if step_record["carried_cut"]:
        print("  WARNING: follow-up carry list cut by %d" % step_record["carried_cut"], flush=True)
    order = sorted(order, key=lambda t: (piece.find(t), -len(t)))  # document order again
    ids, q = question(piece, first, order)
    status, payload, rec = evaluate(state, {"narrow": q}, dict(meta, sub="follow_up", option_maps={"narrow": ids}))
    step_record["calls"].append({"sub": "follow_up", "status": status, "latency_ms": rec["latency_ms"],
                                 "cold": rec["cold"], "questions": 1, "request_bytes": rec["request_bytes"],
                                 "options": len(order) + 3})
    if status != 200:
        return None, None, step_record, 2, {"status": status, "body": payload}
    answer = (payload.get("answers") or {}).get("narrow") or {}
    return _decide(ids, answer, step_record) + (2, None)


def _decide(ids, answer, step_record):
    choice = answer.get("choice")
    probs = answer.get("probabilities") or {}
    ranked = probabilities_text(ids, answer)
    step_record.update({
        "choice": choice, "choice_text": ids.get(choice), "p": probs.get(choice),
        "p_keep": probs.get(KEEP), "p_nothing": probs.get(NOTHING), "p_ask": probs.get(ASK),
        "confidence": answer.get("confidence"),
        "top": [(p, o, t) for p, o, t in ranked[:5]],
        # what the Candidate Chooser would list: every option with any probability, most likely first
        "chooser_list": [t for p, o, t in ranked if p > 0 and o not in (NOTHING, ASK)],
    })
    return choice, ids.get(choice), step_record


def narrow(cell, run):
    """One paste. Returns the result record (also logged)."""
    copy = cell["item"]
    piece, step, steps, calls, started = copy, 0, [], 0, time.monotonic()
    outcome, final, chooser, error = None, None, None, None
    while step < MAX_STEPS:
        kids, _ = children_for(cell, piece)
        if not kids:
            outcome, final = "paste", piece  # nothing smaller to cut: final without a call
            break
        choice, text, record, n, error = one_step(cell, run, step, piece)
        steps.append(record)
        calls += n
        if error is not None:
            outcome = "error"
            break
        if choice == KEEP:
            outcome, final = "paste", piece
            break
        if choice == NOTHING:
            outcome = "nothing"
            break
        if choice == ASK:
            outcome, chooser = "ask", record["chooser_list"]
            break
        if text is None or text not in copy or text not in piece:  # byte-exact check at every step
            outcome, error = "error", {"invalid_pick": choice}
            break
        piece, step = text, step + 1
    wall_ms = (time.monotonic() - started) * 1000.0
    if outcome == "paste" and final == copy:
        final = copy.strip("\r\n")  # outer line-break stripping for every whole-item paste
    latency_ms = sum(c["latency_ms"] for s in steps for c in s["calls"])
    hit = score(cell, outcome, final)
    result = {
        "kind": "paste", "billed": False, "cell": cell["id"], "group": cell["group"], "run": run,
        "expected": cell["expected"], "accept": cell["accept"], "expected_outcome": cell["outcome"],
        "borderline": cell["borderline"], "outcome": outcome, "final": final, "hit": hit,
        "byte_exact": final is None or final in copy, "chooser": chooser, "calls": calls,
        "latency_ms": round(latency_ms, 1), "wall_ms": round(wall_ms, 1), "steps": steps, "error": error,
        "timestamp": time.time(),
    }
    log(result)
    show = (final if outcome == "paste" else outcome) or ""
    print("%-24s r%-2d %-8s calls=%d %6.0f ms  %s -> %r" % (
        cell["id"], run, "HIT" if hit else "MISS", calls, latency_ms,
        " > ".join("%s(%d%s)%s" % (s.get("choice"), s["options"], "/%d" % s["choices"] if s["choices"] > 1 else "",
                                    "%.2f" % s["p"] if s.get("p") is not None else "") for s in steps),
        show[:60]), flush=True)
    return result


def score(cell, outcome, final):
    if cell["outcome"] == "too_long":
        return outcome == "error"
    if outcome != cell["outcome"]:
        return False
    if outcome == "paste":
        return final == cell["expected"] or final in cell["accept"]
    return True


# ============================================================================================== OFFLINE
def reach():
    print("%-24s %-5s %-5s %s" % ("cell", "reach", "calls", "steps: options/choices [how] -> pick"))
    worst = []
    for cell in cells.CELLS:
        def fn(piece, cell=cell):
            kids, how = children_for(cell, piece)
            return kids, how, len(chunks_for(cell, piece, kids))
        targets = []
        if cell["outcome"] == "paste":
            targets = [cell["expected"]] + cell["accept"]
        elif cell["outcome"] == "ask":
            targets = cell["accept"]
        if not targets:
            kids, how, ch = fn(cell["item"])
            print("%-24s %-5s %-5d %d/%d [%s] -> %s" % (cell["id"], "-", 1 + (ch > 1), len(kids) + 1, ch, how,
                                                       cell["outcome"]))
            continue
        for t_index, target in enumerate(targets):
            steps, ok = cuts.path_to(cell["item"], target, children_fn=fn)
            calls = cuts.calls_for(steps)
            label = cell["id"] if t_index == 0 else "  (accept)"
            desc = " | ".join("%d/%d [%s] -> %s" % (n, c, how, (repr(pick[:24]) if pick else pick))
                              for _, n, c, how, pick in steps)
            print("%-24s %-5s %-5d %s" % (label, "yes" if ok else "NO", calls, desc), flush=True)
            if not ok:
                worst.append((cell["id"], target))
    print("\nunreachable:", worst or "none")


def print_wordings():
    for name in ("INSTRUCTIONS_FIRST", "INSTRUCTIONS_LATER", "KEEP_WHOLE", "KEEP_PIECE", "NOTHING_FITS", "ASK_USER"):
        print("%s:\n%s\n" % (name, globals()[name]))


# ============================================================================================== PROBE (too big)
def probe():
    """Send prefixes of the too-big copy (whole lines) with a minimal step-1 question (unchanged, nothing fits, ask)
    and bisect where Jev starts refusing. Logs every response verbatim; accepted calls report `usage.inputTokens`."""
    cell = cells.BY_ID["N04_too_big"]
    all_lines = cell["item"].split("\n")
    lo, hi = 300, len(all_lines)  # 300 lines are known to fit (N03)
    results = {}

    def attempt(n):
        copy = "\n".join(all_lines[:n])
        c = dict(cell, item=copy)
        ids, q = question(copy, True, [])  # minimal question: unchanged, nothing fits, ask -> the state decides
        status, payload, rec = evaluate(state_for(c), {"narrow": q}, {
            "cell": "N04_probe", "run": -1, "step": 0, "sub": "probe", "lines": n, "copy_chars": len(copy),
            "option_maps": {"narrow": ids}})
        usage = payload.get("usage") if isinstance(payload, dict) else None
        results[n] = (status, rec["request_bytes"], usage)
        print("lines=%d chars=%d bytes=%d -> %s %s" % (n, len(copy), rec["request_bytes"], status,
                                                       usage or str(payload)[:200]), flush=True)
        return status == 200

    if attempt(hi):
        print("the full too-big copy was accepted; make it bigger")
        return
    while hi - lo > 10:
        mid = (lo + hi) // 2
        if attempt(mid):
            lo = mid
        else:
            hi = mid
    print("accepted up to %d lines, refused from %d lines" % (lo, hi))


def probe_total():
    """Is the 64k request budget counted with the state once, or once per question? State = the 300-line log
    (~12.8k tokens); each question = unchanged + 35 windows of 10 lines (~15k tokens). 3 questions: 58k tokens if the
    state counts once, 83k if per question. 4 questions: 73k even if once (should be refused)."""
    cell = cells.BY_ID["N03_list_300_lines"]
    ls = cell["item"].split("\n")
    windows = ["\n".join(ls[i:i + 10]) for i in range(0, 300, 10)]
    windows += ["\n".join(ls[i:i + 10]) for i in range(5, 55, 10)]  # 35 options
    for n_questions in (3, 4):
        questions, maps = {}, {}
        for k in range(n_questions):
            ids, q = question(cell["item"], True, windows[k:] + windows[:k])
            questions["narrow_%d" % k] = q
            maps["narrow_%d" % k] = ids
        status, payload, rec = evaluate(state_for(cell), questions, {
            "cell": "N04_probe_total", "run": -1, "step": 0, "sub": "probe_total", "questions_n": n_questions,
            "option_maps": maps})
        usage = payload.get("usage") if isinstance(payload, dict) else None
        print("questions=%d bytes=%d -> %s %s" % (n_questions, rec["request_bytes"], status,
                                                  usage or str(payload)[:300]), flush=True)


# ============================================================================================== MAIN
def select(args):
    groups = {c["group"] for c in cells.CELLS}
    if not args:
        return [c for c in cells.CELLS if c["id"] != "N04_too_big"] + [cells.BY_ID["N04_too_big"]]
    out = []
    for a in args:
        if a in groups:
            out += [c for c in cells.CELLS if c["group"] == a]
        else:
            out.append(cells.BY_ID[a])
    return out


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "reach"
    try:
        if command == "reach":
            reach()
        elif command == "wordings":
            print_wordings()
        elif command == "smoke":
            for cell in select(sys.argv[2:]):
                narrow(cell, -1)
        elif command == "matrix":
            run = int(sys.argv[2])
            done = {(r["cell"], r["run"]) for r in rows() if r.get("kind") == "paste" and r.get("outcome") != "error"
                    or (r.get("kind") == "paste" and r["cell"] == "N04_too_big")}
            for cell in select(sys.argv[3:]):
                if (cell["id"], run) in done:
                    continue  # resume: every (cell, run) is recorded once
                result = narrow(cell, run)
                if result["outcome"] == "error" and cell["outcome"] != "too_long":
                    print("  error, retrying the cell once after 60 s: %s" % str(result["error"])[:200])
                    time.sleep(60)
                    narrow(cell, run)
            print("billed so far: %d" % billed_so_far())
        elif command == "probe":
            probe()
        elif command == "probe_total":
            probe_total()
        else:
            raise SystemExit("unknown command %r" % command)
    except Stop as stop:
        print("STOP:", stop)
        sys.exit(2)


if __name__ == "__main__":
    main()
