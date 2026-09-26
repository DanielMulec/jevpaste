"""Narrowing spike, round 2 (ticket #49): changed design levers D1-D4, runner, exploration screen, matrix.

Usage (key exported, never printed):
    set -a; . ~/.config/jevpaste/env; set +a
    python3 r2.py plan [CELL...]                 # offline: pieces, questions and size per step-1 request
    python3 r2.py reach [DESIGN]                 # offline: every expected excerpt reachable, ideal calls
    python3 r2.py screen PHASE_TAG VARIANTS CELL...   # exploration: step-1 wording variants in parallel questions
    python3 r2.py run TAG DESIGN RUN CELL|GROUP...     # full Narrowing pastes with one design (resumable per cell)
    python3 r2.py wordings DESIGN                # print every wording of a design verbatim

Every request and response is appended verbatim to results/raw.jsonl (round-2 log; round 1 is never touched).
Round-1 modules are imported unchanged: cuts (cutting, size model), cells (round-1 cells), run (plumbing constants).
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROUND1 = os.path.join(HERE, "..")
sys.path.insert(0, ROUND1)
sys.path.append(os.path.join(ROUND1, "..", "abstention"))

import jev  # noqa: E402
import cells  # noqa: E402  (round-1 cells, unchanged)
import cuts  # noqa: E402  (round-1 cutting + size model, unchanged)
import heldout  # noqa: E402

RAW_PATH = os.path.join(HERE, "results", "raw.jsonl")
ROUND2_BUDGET = 700
EXPLORE_BUDGET = 150
PACING_SECONDS = 0.7
TIMEOUT_SECONDS = 60
MAX_STEPS = 10
PIECES_PER_CHOICE = cuts.PIECES_PER_CHOICE - 1  # 252 pieces + "unchanged" + nothing fits + ask the user = 255
MAX_QUESTIONS = 12

ALL_CELLS = cells.CELLS + heldout.HELDOUT
BY_ID = {c["id"]: c for c in ALL_CELLS}

KEEP_KEYS = ("keep", "everything")
NOTHING, ASK = "nothing_fits", "ask_user"

# ============================================================================================== WORDINGS
# Every wording is place-neutral: no field or place types, no value types, no examples.
PRE = "The user copied `source_document` and is pasting into the place described by `target_context`. "
# "cursor" preamble: says which part of `target_context` is the place (the spot at the text cursor), not the page
PRE_CURSOR = ("The user copied `source_document` and pressed paste. `target_context` describes the place where the text "
              "cursor is, and what surrounds that place. ")
# as PRE_CURSOR, plus which keys of `target_context` describe the place itself and which its surroundings
PRE_KEYS = ("The user copied `source_document` and pressed paste. `target_context` describes the place where the text "
            "cursor is, and what surrounds that place: `field_label`, `placeholder` and `section_heading` describe the "
            "place itself; `app_name`, `window_title`, `sibling_field_labels` and `surrounding_text` describe its "
            "surroundings. ")

FORM_FIRST = {
    "full": "One option is everything that was copied, as it is. Every other excerpt option is an exact excerpt cut "
            "from `source_document`; its description is that excerpt, character for character. ",
    "ids": "One option is everything that was copied, as it is. Every other excerpt option is the id of an exact "
           "excerpt cut from `source_document`; `excerpts` gives the text of each id, character for character. ",
}
FORM_LATER = {
    "full": "`current_piece` is an exact excerpt of `source_document`. One option is `current_piece` kept as it is. "
            "Every other excerpt option is a smaller exact excerpt cut from `current_piece`; its description is that "
            "excerpt, character for character. ",
    "ids": "`current_piece` is an exact excerpt of `source_document`. One option is `current_piece` kept as it is. "
           "Every other excerpt option is the id of a smaller exact excerpt cut from `current_piece`; `excerpts` gives "
           "the text of each id, character for character. ",
}

DECIDE = {
    # round 1, verbatim
    "r1": "Choose the option that is exactly what the user means to paste into `target_context`. "
          "If no option is exactly that, choose the smallest option that contains all of it.",
    # "belongs in that place" instead of "the user means to paste"
    "belongs": "Choose the option that is exactly what belongs in that place. "
               "If no option is exactly that, choose the smallest option that contains all of it.",
    # no "smallest ... contains all" sentence; exactness first, least extra text second
    "exact": "Choose the option that is exactly what belongs in that place, with nothing missing and nothing extra. "
             "Only if no option is exactly that, choose the option that contains all of it with the least extra text.",
    # as "exact", plus a sentence that makes "ask the user" the pick when excerpts compete
    "exact_ask": "Choose the option that is exactly what belongs in that place, with nothing missing and nothing "
                 "extra. Only if no option is exactly that, choose the option that contains all of it with the least "
                 "extra text. If two or more different excerpts would each belong there and nothing says which one "
                 "is meant, choose `ask_user` instead of one of them.",
    # "asks for one particular thing": a part only when the place asks for one; else everything / current piece
    "particular": "Choose what will be pasted at the text cursor. If that place asks for one particular thing, choose "
                  "the option that is exactly that thing, with nothing missing and nothing extra; only if no option is "
                  "exactly that, choose the option that contains all of it with the least extra text. If that place "
                  "does not ask for one particular thing, choose {all}. If two or more different excerpts are each "
                  "exactly the thing that place asks for and nothing says which one is meant, choose `ask_user` "
                  "instead of one of them.",
}
ALL_FIRST = "everything that was copied"
ALL_LATER = "`current_piece` as it is"

KEEP_FIRST = {
    "r1": "Everything that was copied, as it is: all of `source_document`, nothing cut away.",
}
KEEP_LATER = "`current_piece` as it is, nothing cut away."

NOTHING_W = {
    "r1": "Nothing that was copied belongs in `target_context`: no part of `source_document` is what the user means "
          "to paste there.",
    "asks": "No part of `source_document` belongs in the place described by `target_context`: that place is for "
            "something that was not copied.",
    "particular": "That place asks for one particular thing, and no part of `source_document` is that thing.",
}
ASK_W = {
    "r1": "Two or more different excerpts could each be what the user means to paste into `target_context`, and "
          "nothing in `target_context` says which one; the user has to pick.",
    "belongs": "Two or more different excerpts would each belong in the place described by `target_context`, and "
               "neither `target_context` nor `source_document` says which one is meant; the user has to pick.",
    "particular": "That place asks for one particular thing, two or more different excerpts of `source_document` are "
                  "each exactly that thing, and nothing says which one is meant; the user has to pick.",
}

# D4: the place choice (measured only). Same request as the first step.
PLACE_Q = {
    "P1": PRE + "What will the user paste there?",
    "P2": PRE + "What belongs in that place?",
    "P3": PRE_CURSOR + "What will be pasted at the text cursor?",
    "P4": PRE_CURSOR + "What will be pasted at the text cursor?",
}
# P3 explains each option in the "particular" terms; P1, P2, P4 use the plain options
PLACE_OPTIONS_P3 = {
    "everything": "Everything that was copied, as it is: that place does not ask for one particular part of it.",
    "one_part": "One part of what was copied: that place asks for one particular thing, and `source_document` "
                "contains it.",
    "nothing": "Nothing of what was copied: that place asks for one particular thing, and `source_document` does not "
               "contain it.",
}
PLACE_OPTIONS = {
    "everything": "Everything that was copied, as it is: all of `source_document`.",
    "one_part": "One part of what was copied: an excerpt of `source_document`, with the rest left out.",
    "nothing": "Nothing of what was copied: no part of `source_document` belongs there.",
}

# A variant = one full set of wordings. `keep_text`: the everything option also carries the copy's text.
VARIANTS = {
    "V0": dict(decide="r1", keep_key="keep", nothing="r1", ask="r1", keep_text=False),
    "V1": dict(decide="belongs", keep_key="everything", nothing="r1", ask="r1", keep_text=False),
    "V2": dict(decide="exact_ask", keep_key="everything", nothing="asks", ask="belongs", keep_text=False),
    "V3": dict(decide="exact_ask", keep_key="everything", nothing="asks", ask="belongs", keep_text=True),
    "V4": dict(decide="exact", keep_key="everything", nothing="asks", ask="belongs", keep_text=False),
    "V5": dict(pre="cursor", decide="particular", keep_key="everything", nothing="particular", ask="particular",
                keep_text=False),
    "V7": dict(pre="keys", decide="particular", keep_key="everything", nothing="particular", ask="particular",
                keep_text=False),
    "V6": dict(pre="cursor", decide="exact_ask", keep_key="everything", nothing="asks", ask="belongs",
                keep_text=False),
}

# A design = variant + D1 (fineness K, layout) + D2 (option form) + D4 place wording + speculation.
DESIGNS = {
    "base": dict(variant="V2", k=8, layout="doc", form="full", place="P1", speculate=3),
    # candidate frozen at GATE A (pending approval)
    "r2": dict(variant="V5", k=8, layout="cont", form="ids", place="P3", speculate=3),
}


def design_of(name):
    """`name` is a DESIGNS key, optionally with overrides: `base+variant=V3+form=ids+k=6`."""
    parts = name.split("+")
    d = dict(DESIGNS[parts[0]])
    for p in parts[1:]:
        key, value = p.split("=")
        d[key] = int(value) if value.isdigit() else value
    d["name"] = name
    return d


def keep_description(v, piece, first):
    if not first:
        return KEEP_LATER
    text = KEEP_FIRST["r1"]
    if v["keep_text"]:
        return {"option": text, "text": piece}
    return text


def instructions(v, form, piece, first):
    pre = {"cursor": PRE_CURSOR, "keys": PRE_KEYS}.get(v.get("pre"), PRE)
    decide_text = DECIDE[v["decide"]].replace("{all}", ALL_FIRST if first else ALL_LATER)
    if first:
        return pre + FORM_FIRST[form] + decide_text
    return {"current_piece": piece, "question": pre + FORM_LATER[form] + decide_text}


# ============================================================================================== CUTTING (D1)
def fine_runs(piece, k):
    """Every run of 1..k consecutive tokens inside one line of `piece` (character classes only)."""
    out = []
    for start, end in cuts.lines(piece):
        toks = cuts.tokens(piece, start, end)
        for i in range(len(toks)):
            for j in range(min(len(toks), i + k) - 1, i - 1, -1):
                out.append(piece[toks[i][0]:toks[j][1]])
    return out


def coarse(piece, budget):
    """Round-1 children without flattening: line runs + edge cuts (or blocks) for several lines; token level for one
    line. Every contiguous non-space-bounded substring stays reachable through these (round-1 self_check)."""
    ls = cuts.lines(piece)
    if len(ls) >= 2:
        return cuts._grouped(piece, ls, cuts.edge_trims(piece), budget, "lines")
    return cuts.children(piece, budget)


def doc_order(piece, pieces):
    return sorted(pieces, key=lambda t: (piece.find(t), -len(t)))


def children2(piece, k, budget=None):
    """(containers, fine, how). containers = round-1 coarse children; fine = short token runs (<= k tokens) not
    already among them. Fine pieces are dropped (grouping only: all stay reachable via containers) when the whole set
    exceeds MAX_QUESTIONS choices or the request size."""
    budget = budget or cuts.Budget()
    cont, how = coarse(piece, budget)
    cont = cuts.dedupe(cont, piece)
    fine = [] if k <= 0 else [p for p in cuts.dedupe(fine_runs(piece, k), piece) if p not in set(cont)]
    total = len(cont) + len(fine)
    if fine and (total > MAX_QUESTIONS * PIECES_PER_CHOICE or not budget.fits(cont + fine)):
        return cont, [], how + " (fine dropped: too big)"
    return cont, fine, how + (" + token runs <= %d" % k if fine else "")


# ============================================================================================== REQUEST BUILDING
class Request:
    """One Jev request: one state, many questions. Excerpt ids (form "ids") are shared across its questions."""

    def __init__(self, cell, form):
        self.cell, self.form = cell, form
        self.questions, self.maps = {}, {}
        self.excerpts = {}  # id -> text (form "ids")
        self._ids = {}      # text -> id

    def excerpt_id(self, text):
        if text not in self._ids:
            oid = "x%04d" % len(self._ids)
            self._ids[text] = oid
            self.excerpts[oid] = text
        return self._ids[text]

    def state(self):
        s = {"source_document": self.cell["item"], "target_context": self.cell["context"]}
        if self.form == "ids" and self.excerpts:
            s["excerpts"] = self.excerpts
        return s

    def add_choice(self, qid, v, piece, first, pieces):
        keep_key = v["keep_key"] if first else "keep"
        ids = {keep_key: piece}
        criteria = {keep_key: keep_description(v, piece, first)}
        for index, text in enumerate(pieces):
            if self.form == "ids":
                oid = self.excerpt_id(text)
                criteria[oid] = None
            else:
                oid = "e%03d" % index
                criteria[oid] = text
            ids[oid] = text
        criteria[NOTHING] = NOTHING_W[v["nothing"]]
        criteria[ASK] = ASK_W[v["ask"]]
        self.questions[qid] = {"type": "choice", "instructions": instructions(v, self.form, piece, first),
                               "criteria": criteria}
        self.maps[qid] = ids

    def add_place(self, qid, wording):
        options = PLACE_OPTIONS_P3 if wording == "P3" else PLACE_OPTIONS
        self.questions[qid] = {"type": "choice", "instructions": PLACE_Q[wording], "criteria": dict(options)}
        self.maps[qid] = {k: k for k in PLACE_OPTIONS}

    def est(self):
        """(total tokens, state + largest question) by the round-1 size model."""
        state = cuts.est_tokens(json.dumps(self.state(), ensure_ascii=False)) + 4 * len(self.excerpts)
        qs = [cuts.QUESTION_TOKENS + cuts.est_tokens(json.dumps(q, ensure_ascii=False))
              + cuts.OPTION_TOKENS * len(q["criteria"]) for q in self.questions.values()]
        return state + sum(qs), state + (max(qs) if qs else 0)

    def fits(self):
        total, largest = self.est()
        return total <= cuts.REQUEST_BUDGET_TOKENS and largest <= cuts.QUESTION_BUDGET_TOKENS


def chunk(piece, cont, fine, layout, per_choice=PIECES_PER_CHOICE, room=None):
    """Split children into choices. layout "doc": all children in document order; "cont": the containers repeated in
    every choice, the fine pieces spread over the choices. `room`: option tokens per choice (full form)."""
    if layout == "cont" and fine and len(cont) <= per_choice // 2:
        size = per_choice - len(cont)
        r = None if room is None else room - sum(cuts.option_tokens(p) for p in cont)
        parts = _split_room(doc_order(piece, fine), size, r)
        return [doc_order(piece, cont + part) for part in parts]
    return _split_room(doc_order(piece, cont + fine), per_choice, room)


def _split_room(items, size, room):
    """Greedy split in order: <= size pieces and (if room) <= room option tokens per choice."""
    out, cur, used = [], [], 0.0
    for p in items:
        c = cuts.option_tokens(p) if room is not None else 0.0
        if cur and (len(cur) >= size or (room is not None and used + c > room)):
            out.append(cur)
            cur, used = [], 0.0
        cur.append(p)
        used += c
    if cur:
        out.append(cur)
    return out or [[]]


def step_chunks(cell, design, piece):
    """The choices of one Narrowing step on `piece` (list of piece lists)."""
    first = piece == cell["item"]
    state_tokens = cuts.est_tokens(json.dumps({"source_document": cell["item"], "target_context": cell["context"]},
                                              ensure_ascii=False))
    fixed = cuts.QUESTION_TOKENS + 900 + (0 if first else cuts.est_tokens(piece))
    if design["form"] == "full":
        budget = cuts.Budget(state_tokens, fixed)
        cont, fine, how = children2(piece, design["k"], budget)
        room = cuts.QUESTION_BUDGET_TOKENS - state_tokens - fixed
        return chunk(piece, cont, fine, design["layout"], room=room if room > 0 else None), how
    # ids: excerpt texts live in the state once; options cost only their id
    budget = cuts.Budget(state_tokens, fixed)
    cont, fine, how = children2(piece, design["k"], budget)
    return chunk(piece, cont, fine, design["layout"]), how


# ============================================================================================== PLUMBING
def rows():
    if not os.path.exists(RAW_PATH):
        return []
    with open(RAW_PATH) as handle:
        return [json.loads(line) for line in handle if line.strip()]


def billed(phase=None):
    return sum(1 for r in rows() if r.get("kind") == "call" and r.get("billed")
               and (phase is None or r.get("phase") == phase))


def log(record):
    os.makedirs(os.path.dirname(RAW_PATH), exist_ok=True)
    with open(RAW_PATH, "a") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


class Stop(Exception):
    pass


_last_call_at = 0.0
_process_calls = 0
_budget_cache = {"all": None, "explore": None}


def post(body_obj, attempts=10):
    global _last_call_at
    key = os.environ.get("AI_GATEWAY_API_KEY")
    if not key:
        raise Stop("AI_GATEWAY_API_KEY is not set: set -a; . ~/.config/jevpaste/env; set +a")
    body = json.dumps(body_obj).encode("utf-8")
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


def send(req, meta):
    """Send one Request, log it verbatim. Returns (status, payload, record)."""
    global _process_calls
    if _budget_cache["all"] is None:
        _budget_cache["all"] = billed()
        _budget_cache["explore"] = billed("explore")
    if _budget_cache["all"] >= ROUND2_BUDGET:
        raise Stop("round-2 budget of %d billed calls reached" % ROUND2_BUDGET)
    if meta.get("phase") == "explore" and _budget_cache["explore"] >= EXPLORE_BUDGET:
        raise Stop("exploration budget of %d billed calls reached" % EXPLORE_BUDGET)
    est_total, est_largest = req.est()
    body = {"model": jev.MODEL, "state": req.state(), "questions": req.questions}
    status, text, latency, waits, request_bytes = post(body)
    cold = _process_calls == 0
    _process_calls += 1
    try:
        payload = json.loads(text)
    except Exception:
        payload = None
    record = dict(meta)
    record.update({
        "kind": "call", "billed": status == 200, "status": status, "cold": cold, "latency_ms": round(latency, 1),
        "waits": waits, "request_bytes": request_bytes, "est_tokens": round(est_total), "est_largest": round(
            est_largest), "questions_n": len(req.questions), "option_maps": req.maps,
        "request": body, "response": payload if payload is not None else text, "timestamp": time.time(),
    })
    log(record)
    if status == 200:
        _budget_cache["all"] += 1
        if meta.get("phase") == "explore":
            _budget_cache["explore"] += 1
    return status, payload if payload is not None else text, record


# ============================================================================================== DECISIONS
def ranked(ids, answer):
    probs = answer.get("probabilities") or {}
    return sorted(((p, oid, ids.get(oid)) for oid, p in probs.items()), key=lambda x: -x[0])


def decide(ids, answer):
    """A step record from one deciding choice."""
    choice = answer.get("choice")
    probs = answer.get("probabilities") or {}
    r = ranked(ids, answer)
    keep_key = next((k for k in KEEP_KEYS if k in ids), "keep")
    return {
        "choice": "keep" if choice in KEEP_KEYS else choice, "choice_text": ids.get(choice), "p": probs.get(choice),
        "p_keep": probs.get(keep_key), "p_nothing": probs.get(NOTHING), "p_ask": probs.get(ASK),
        "confidence": answer.get("confidence"), "top": [(round(p, 4), o, t) for p, o, t in r[:6]],
        "chooser_list": [t for p, o, t in r if p > 0 and o not in (NOTHING, ASK)],
        "options": len(ids) + 2,
    }


def carry(chunk_answers):
    """Follow-up carry list: every excerpt with p >= 0.01 in any choice (round 1 rule). Returns ({text: p}, per_chunk)."""
    carried, per = {}, []
    for ids, answer in chunk_answers:
        r = ranked(ids, answer)
        per.append({"choice": answer.get("choice"), "choice_text": ids.get(answer.get("choice")),
                    "top": [(round(p, 4), o, t) for p, o, t in r[:5]]})
        for p, oid, text in r:
            if oid in KEEP_KEYS + (NOTHING, ASK) or p < 0.01:
                continue
            carried[text] = max(carried.get(text, 0), p)
    return carried, per


def agree(chunk_answers):
    """All choices pick the same non-excerpt option -> that option (no follow-up needed)."""
    picks = {("keep" if a.get("choice") in KEEP_KEYS else a.get("choice")) for _, a in chunk_answers}
    if len(picks) == 1 and next(iter(picks)) in ("keep", NOTHING, ASK):
        return next(iter(picks))
    return None


# ============================================================================================== NARROWING
def narrow(cell, run, design, tag):
    """One paste with the full design (policy A = Narrowing's own result; policy B uses the place choice)."""
    v = VARIANTS[design["variant"]]
    copy = cell["item"]
    piece, steps, requests, place = copy, [], [], None
    answered = {}  # piece -> step record from a speculative question already answered
    outcome = final = chooser = error = None
    step_no = 0
    while step_no < MAX_STEPS:
        first = piece == copy
        if piece in answered:
            rec = answered.pop(piece)
            rec["speculative"] = True
            steps.append(rec)
        else:
            chunks, how = step_chunks(cell, design, piece)
            if chunks == [[]]:
                outcome, final = "paste", piece  # nothing smaller to cut: final without a call
                break
            def build(form):
                r = Request(cell, form)
                for k, part in enumerate(chunks):
                    r.add_choice("narrow_%d" % k, v, piece, first, part)
                if first:
                    r.add_place("place", design["place"])
                return r
            req = build(design["form"])
            if design["form"] == "ids" and not req.fits():
                req = build("full")  # the excerpts would overfill the state: options carry their text instead
            status, payload, rec_call = send(req, {"phase": tag, "cell": cell["id"], "run": run, "step": step_no,
                                                   "sub": "step", "design": design["name"]})
            requests.append({"sub": "step", "form": req.form, "status": status, "latency_ms": rec_call["latency_ms"],
                             "cold": rec_call["cold"], "questions": len(req.questions),
                             "usage": (payload.get("usage") if isinstance(payload, dict) else None)})
            if status != 200:
                outcome, error = "error", {"status": status, "body": str(payload)[:500]}
                break
            answers = payload.get("answers") or {}
            if first:
                pa = answers.get("place") or {}
                place = {"choice": pa.get("choice"), "probabilities": pa.get("probabilities")}
            chunk_answers = [(req.maps["narrow_%d" % k], answers.get("narrow_%d" % k) or {})
                             for k in range(len(chunks))]
            if len(chunks) == 1:
                rec = decide(*chunk_answers[0])
                rec.update({"step": step_no, "piece": piece, "how": how, "choices": 1})
                steps.append(rec)
            else:
                carried, per = carry(chunk_answers)
                agreed = agree(chunk_answers)
                if agreed is not None:
                    ids, answer = chunk_answers[0]
                    rec = decide(ids, answer)
                    rec.update({"step": step_no, "piece": piece, "how": how, "choices": len(chunks),
                                "chunk_winners": per, "follow_up": "skipped (all choices agree)"})
                    steps.append(rec)
                else:
                    order = sorted(carried, key=lambda t: -carried[t])[:PIECES_PER_CHOICE]
                    cut = len(carried) - len(order)
                    candidates = []
                    for text in sorted(carried, key=lambda t: -carried[t])[:design["speculate"]]:
                        s_chunks, s_how = step_chunks(cell, design, text)
                        if len(s_chunks) == 1 and s_chunks != [[]]:
                            candidates.append((text, s_how, s_chunks[0]))

                    def build_fu(form, with_spec):
                        r = Request(cell, form)
                        r.add_choice("follow_up", v, piece, first, doc_order(piece, order))
                        for i, (text, _, kids) in enumerate(candidates if with_spec else []):
                            r.add_choice("spec_%d" % i, v, text, False, kids)
                        return r, [(t, h) for t, h, _ in (candidates if with_spec else [])]
                    tries = [(design["form"], True), ("full", True), (design["form"], False), ("full", False)]
                    for form, with_spec in tries:  # speculative next steps only if they fit
                        fu, spec = build_fu(form, with_spec)
                        if fu.fits():
                            break
                    status, payload, rec_call = send(fu, {"phase": tag, "cell": cell["id"], "run": run,
                                                          "step": step_no, "sub": "follow_up",
                                                          "design": design["name"]})
                    requests.append({"sub": "follow_up", "form": fu.form, "status": status,
                                     "latency_ms": rec_call["latency_ms"],
                                     "cold": rec_call["cold"], "questions": len(fu.questions),
                                     "usage": (payload.get("usage") if isinstance(payload, dict) else None)})
                    if status != 200:
                        outcome, error = "error", {"status": status, "body": str(payload)[:500]}
                        break
                    answers = payload.get("answers") or {}
                    rec = decide(fu.maps["follow_up"], answers.get("follow_up") or {})
                    rec.update({"step": step_no, "piece": piece, "how": how, "choices": len(chunks),
                                "chunk_winners": per, "carried": len(carried), "carried_cut": cut,
                                "follow_up_options": len(order) + 3, "speculated": [t for t, _ in spec]})
                    steps.append(rec)
                    for i, (text, s_how) in enumerate(spec):
                        srec = decide(fu.maps["spec_%d" % i], answers.get("spec_%d" % i) or {})
                        srec.update({"piece": text, "how": s_how, "choices": 1})
                        answered[text] = srec
        rec = steps[-1]
        rec["step"] = step_no
        choice, text = rec["choice"], rec["choice_text"]
        if choice == "keep":
            outcome, final = "paste", piece
            break
        if choice == NOTHING:
            outcome = "nothing"
            break
        if choice == ASK:
            outcome, chooser = "ask", rec["chooser_list"]
            break
        if text is None or text not in copy or text not in piece or text == piece:  # byte-exact at every step
            outcome, error = "error", {"invalid_pick": choice}
            break
        piece, step_no = text, step_no + 1
    if outcome == "paste" and final == copy:
        final = copy.strip("\r\n")  # outer line-break stripping for every whole-item paste
    latency_ms = sum(r["latency_ms"] for r in requests)  # one request per step: the step's slowest call
    hit_a = score(cell, outcome, final)
    # policy B: the place choice decides everything / nothing; one part -> Narrowing's result
    pc = (place or {}).get("choice")
    if pc == "everything":
        b_outcome, b_final, b_calls, b_lat = "paste", copy.strip("\r\n"), 1, requests[0]["latency_ms"] if requests else 0
    elif pc == "nothing":
        b_outcome, b_final, b_calls, b_lat = "nothing", None, 1, requests[0]["latency_ms"] if requests else 0
    else:
        b_outcome, b_final, b_calls, b_lat = outcome, final, len(requests), latency_ms
    result = {
        "kind": "paste", "phase": tag, "design": design["name"], "cell": cell["id"], "group": cell["group"],
        "klass": cell.get("klass"), "run": run, "expected": cell["expected"], "accept": cell["accept"],
        "expected_outcome": cell["outcome"], "borderline": cell["borderline"],
        "outcome": outcome, "final": final, "hit": hit_a, "byte_exact": final is None or final in copy,
        "chooser": chooser, "calls": len(requests), "latency_ms": round(latency_ms, 1),
        "place": place, "b_outcome": b_outcome, "b_final": b_final, "b_hit": score(cell, b_outcome, b_final),
        "b_calls": b_calls, "b_latency_ms": round(b_lat, 1),
        "requests": requests, "steps": steps, "error": error, "timestamp": time.time(),
    }
    log(result)
    show = (final if outcome == "paste" else outcome) or ""
    pp = (place or {}).get("probabilities") or {}
    print("%-26s r%-2d A:%-4s B:%-4s calls=%d %5.0f ms place=%s(%.2f/%.2f/%.2f) %s -> %r" % (
        cell["id"], run, "HIT" if hit_a else "MISS", "HIT" if result["b_hit"] else "MISS", len(requests),
        latency_ms, pc, pp.get("everything", 0), pp.get("one_part", 0), pp.get("nothing", 0),
        " > ".join("%s(%d%s)%.2f" % ((s.get("choice") if s.get("choice") in ("keep", NOTHING, ASK)
                                      else repr((s.get("choice_text") or "")[:18])),
                                     s["options"], "/%d" % s["choices"] if s.get("choices", 1) > 1 else "",
                                     s.get("p") or 0) for s in steps),
        show[:50]), flush=True)
    return result


def score(cell, outcome, final):
    if cell["outcome"] == "too_long":
        return outcome == "error"
    if outcome != cell["outcome"]:
        return False
    if outcome == "paste":
        return final == cell["expected"] or final in cell["accept"]
    return True


# ============================================================================================== SCREEN (exploration)
def screen(tag, variant_names, cell_ids, design_name="base"):
    """Step 1 only, several wording variants as parallel questions in one request (questions are independent per
    TypeSafe docs), plus both place wordings. Multi-choice variants get their follow-ups in one second request."""
    design = design_of(design_name)
    for cid in cell_ids:
        cell = BY_ID[cid]
        copy = cell["item"]
        chunks, how = step_chunks(cell, design, copy)
        reqs = [Request(cell, design["form"])]
        placed = False
        for vn in variant_names:
            v = VARIANTS[vn]
            trial = Request(cell, design["form"])
            for q, m in zip(reqs[-1].questions.items(), reqs[-1].maps.items()):
                trial.questions[q[0]], trial.maps[m[0]] = q[1], m[1]
            trial.excerpts, trial._ids = dict(reqs[-1].excerpts), dict(reqs[-1]._ids)
            for k, part in enumerate(chunks):
                trial.add_choice("%s__c%d" % (vn, k), v, copy, True, part)
            if trial.fits() or not reqs[-1].questions:
                reqs[-1] = trial
            else:
                reqs.append(Request(cell, design["form"]))
                for k, part in enumerate(chunks):
                    reqs[-1].add_choice("%s__c%d" % (vn, k), v, copy, True, part)
        if not placed:
            for pw in PLACE_Q:
                reqs[0].add_place("place__" + pw, pw)
        answers, maps, lat = {}, {}, []
        for req in reqs:
            status, payload, rec = send(req, {"phase": tag, "cell": cid, "run": -1, "step": 0, "sub": "screen",
                                              "design": design["name"], "variants": variant_names})
            if status != 200:
                print(cid, "error", status, str(payload)[:300])
                break
            answers.update(payload.get("answers") or {})
            maps.update(req.maps)
            lat.append(rec["latency_ms"])
        results = {}
        fu = Request(cell, design["form"])
        for vn in variant_names:
            ca = [(maps.get("%s__c%d" % (vn, k)), answers.get("%s__c%d" % (vn, k)) or {}) for k in range(len(chunks))]
            if any(m is None for m, _ in ca):
                continue
            if len(chunks) == 1:
                results[vn] = decide(*ca[0])
                continue
            carried, per = carry(ca)
            agreed = agree(ca)
            if agreed:
                results[vn] = dict(decide(*ca[0]), chunk_winners=per, follow_up="skipped")
                continue
            order = doc_order(copy, sorted(carried, key=lambda t: -carried[t])[:PIECES_PER_CHOICE])
            fu.add_choice("%s__fu" % vn, VARIANTS[vn], copy, True, order)
            results[vn] = {"chunk_winners": per}
        if fu.questions:
            status, payload, rec = send(fu, {"phase": tag, "cell": cid, "run": -1, "step": 0, "sub": "screen_fu",
                                             "design": design["name"], "variants": variant_names})
            if status == 200:
                a = payload.get("answers") or {}
                for q in fu.questions:
                    vn = q.split("__")[0]
                    results[vn].update(decide(fu.maps[q], a.get(q) or {}))
                lat.append(rec["latency_ms"])
        place = {pw: (answers.get("place__" + pw) or {}).get("probabilities") for pw in PLACE_Q}
        log({"kind": "screen", "phase": tag, "cell": cid, "design": design["name"], "how": how,
             "choices": len(chunks), "pieces": sum(len(c) for c in chunks), "results": results, "place": place,
             "latency_ms": lat, "timestamp": time.time()})
        exp = cell["expected"] if cell["outcome"] == "paste" else cell["outcome"]
        print("%s  [%s, %d pieces / %d choices]  expected %r" % (cid, how, sum(len(c) for c in chunks), len(chunks),
                                                                  (exp or "")[:40]))
        for vn, r in results.items():
            print("   %s: %s" % (vn, ", ".join("%s %.2f" % (
                o if o in KEEP_KEYS + (NOTHING, ASK) else repr((t or "")[:28]), p) for p, o, t in r.get("top", [])[:4])))
        for pw, pr in place.items():
            print("   place %s: %s" % (pw, {k: round(x, 2) for k, x in (pr or {}).items()}))


# ============================================================================================== OFFLINE
def plan(cell_ids, design_name="base"):
    design = design_of(design_name)
    for cid in cell_ids or [c["id"] for c in ALL_CELLS]:
        cell = BY_ID[cid]
        if len(cell["item"]) > 30000:
            print("%-26s too big (%d chars)" % (cid, len(cell["item"])))
            continue
        chunks, how = step_chunks(cell, design, cell["item"])
        req = Request(cell, design["form"])
        v = VARIANTS[design["variant"]]
        for k, part in enumerate(chunks):
            req.add_choice("narrow_%d" % k, v, cell["item"], True, part)
        req.add_place("place", design["place"])
        total, largest = req.est()
        print("%-26s %4d pieces in %d choices  est %6.0f tok (largest q+state %6.0f) fits=%s  [%s]" % (
            cid, sum(len(c) for c in chunks), len(chunks), total, largest, req.fits(), how))


def reach(design_name="base"):
    """Offline: every expected excerpt reachable along offered pieces; fewest requests (1 per step, +1 follow-up
    when a step has several choices; a speculative next step saves one request)."""
    design = design_of(design_name)
    bad = []
    for cell in ALL_CELLS:
        if len(cell["item"]) > 30000:
            continue
        targets = ([cell["expected"]] + cell["accept"]) if cell["outcome"] == "paste" else cell["accept"]

        def fn(piece, cell=cell):
            chunks, how = step_chunks(cell, design, piece)
            kids = [] if chunks == [[]] else [p for c in chunks for p in c]
            return cuts.dedupe(kids, piece), how, len(chunks)
        for t in targets[:1]:
            steps, ok = cuts.path_to(cell["item"], t, children_fn=fn)
            print("%-26s %-5s calls=%d  %s" % (cell["id"], "yes" if ok else "NO", cuts.calls_for(steps),
                                              " | ".join("%d/%d" % (n, c) for _, n, c, _, _ in steps)), flush=True)
            if not ok:
                bad.append((cell["id"], t))
    print("unreachable:", bad or "none")


def print_wordings(design_name):
    d = design_of(design_name)
    v = VARIANTS[d["variant"]]
    print("STEP 1 instructions:\n%s\n" % instructions(v, d["form"], "<copy>", True))
    print("LATER instructions (question field; current_piece beside it):\n%s\n" % instructions(
        v, d["form"], "<piece>", False)["question"])
    print("%s (step 1):\n%s\n" % (v["keep_key"], keep_description(v, "<copy>", True)))
    print("keep (later):\n%s\n" % KEEP_LATER)
    print("nothing_fits:\n%s\n" % NOTHING_W[v["nothing"]])
    print("ask_user:\n%s\n" % ASK_W[v["ask"]])
    print("place choice instructions:\n%s" % PLACE_Q[d["place"]])
    for k, t in (PLACE_OPTIONS_P3 if d["place"] == "P3" else PLACE_OPTIONS).items():
        print("  %s: %s" % (k, t))


def select(args):
    groups = {c["group"] for c in ALL_CELLS}
    out = []
    for a in args:
        if a in groups:
            out += [c for c in ALL_CELLS if c["group"] == a]
        else:
            out.append(BY_ID[a])
    return out


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "plan"
    args = sys.argv[2:]
    try:
        if cmd == "plan":
            design = "base"
            if args and args[0].split("+")[0] in DESIGNS:
                design, args = args[0], args[1:]
            plan(args, design)
        elif cmd == "reach":
            reach(args[0] if args else "base")
        elif cmd == "wordings":
            print_wordings(args[0] if args else "base")
        elif cmd == "screen":
            tag, variants = args[0], args[1].split(",")
            design = "base"
            rest = args[2:]
            if rest and rest[0].split("+")[0] in DESIGNS:
                design, rest = rest[0], rest[1:]
            screen(tag, variants, rest, design)
        elif cmd == "run":
            tag, design, run = args[0], design_of(args[1]), int(args[2])
            done = {(r["cell"], r["run"], r["design"]) for r in rows()
                    if r.get("kind") == "paste" and r.get("phase") == tag and r.get("outcome") != "error"}
            for cell in select(args[3:]):
                if (cell["id"], run, design["name"]) in done and tag != "smoke":
                    continue
                result = narrow(cell, run, design, tag)
                if result["outcome"] == "error" and cell["outcome"] != "too_long":
                    print("  error, retrying the cell once after 60 s: %s" % str(result["error"])[:200])
                    time.sleep(60)
                    narrow(cell, run, design, tag)
            print("billed round 2: %d (explore %d)" % (billed(), billed("explore")))
        else:
            raise SystemExit("unknown command %r" % cmd)
    except Stop as stop:
        print("STOP:", stop)
        sys.exit(2)


if __name__ == "__main__":
    main()
