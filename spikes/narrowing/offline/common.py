"""Shared loading and replay for the offline analyses (no Jev calls; reads round2/results/raw.jsonl only)."""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROUND2 = os.path.join(HERE, "..", "round2")
sys.path.insert(0, ROUND2)
import r2  # noqa: E402  (imports cuts, cells, heldout; no network at import)
import cuts  # noqa: E402

PHASES = ("matrix2", "matrix2-n03fix")
NOTHING, ASK = "nothing_fits", "ask_user"
FIXED = ("keep", NOTHING, ASK)
HELDOUT = {c["id"] for c in r2.ALL_CELLS if c["group"] == "heldout"}
ORDER = [c["id"] for c in r2.ALL_CELLS]


def group(cell_id):
    return "held-out" if cell_id in HELDOUT else "round-1"


def load():
    """Latest r2b paste per (cell, run) with its status-200 calls attached (`calls`), in cell order."""
    buffers, latest = {}, {}
    with open(os.path.join(ROUND2, "results", "raw.jsonl")) as handle:
        for line in handle:
            row = json.loads(line)
            if row.get("phase") not in PHASES:
                continue
            key = (row["phase"], row["cell"], row["run"])
            if row.get("kind") == "call":
                buffers.setdefault(key, []).append(row)
            elif row.get("kind") == "paste" and row["run"] in (0, 1):
                row["calls"] = [c for c in buffers.pop(key, []) if c.get("status") == 200]
                latest[(row["cell"], row["run"])] = row
    return [latest[k] for k in sorted(latest, key=lambda k: (ORDER.index(k[0]), k[1]))]


def provider(call):
    resp = call.get("response") or {}
    return ((resp.get("providerMetadata") or {}).get("gateway") or {}).get("routing", {}).get("finalProvider")


class Choice:
    """One answered choice question: option id -> text, probabilities, Jev's choice, confidence."""

    def __init__(self, call, qid):
        self.qid = qid
        self.ids = dict(call["option_maps"][qid])
        self.keep_key = self.ids.pop("__keep__")
        self.piece = self.ids[self.keep_key]
        resp = call["response"]
        ans = resp["answers"][qid]
        self.probs = ans["probabilities"]  # listing order kept
        self.choice = ans["choice"]
        conf = ans.get("confidence")
        if conf is None:
            conf = ((resp.get("providerMetadata") or {}).get("typesafe") or {}).get("confidence", {}).get(qid)
        self.confidence = conf
        self.provider = provider(call)

    def meaning(self, oid):
        if oid == self.keep_key or oid in ("keep", "everything"):
            return "keep"
        if oid in (NOTHING, ASK):
            return oid
        return self.ids.get(oid)

    def pieces(self):
        """[(text, p)] of offered pieces (not keep / nothing / ask)."""
        out = []
        for oid, text in self.ids.items():
            if oid == self.keep_key or oid in (NOTHING, ASK):
                continue
            out.append((text, self.probs.get(oid, 0.0)))
        return out

    def p_of(self, meaning):
        for oid in self.probs:
            if self.meaning(oid) == meaning:
                return self.probs[oid]
        return 0.0


class StepAnswers:
    """Everything recorded for one piece in one paste."""

    def __init__(self, piece):
        self.piece = piece
        self.chunks = []        # [Choice] of the step request
        self.follow_up = None   # Choice
        self.spec = None        # Choice (speculative, from a follow-up request)
        self.fu_call = None
        self.step_call = None

    def deciding(self):
        if self.chunks:
            if len(self.chunks) == 1:
                return self.chunks[0]
            picks = {c.meaning(c.choice) for c in self.chunks}
            if len(picks) == 1 and next(iter(picks)) in FIXED:
                return self.chunks[0]
            return self.follow_up
        return self.spec


def answers_of(paste):
    """piece text -> StepAnswers, from the paste's calls."""
    out = {}
    for call in paste["calls"]:
        qids = [q for q in call["request"]["questions"] if q != "place"]
        if call["sub"] == "step":
            ch = [Choice(call, q) for q in sorted(qids, key=lambda q: int(q.split("_")[1]))]
            sa = out.setdefault(ch[0].piece, StepAnswers(ch[0].piece))
            sa.chunks, sa.step_call = ch, call
        elif call["sub"] == "follow_up":
            fu = Choice(call, "follow_up")
            out[fu.piece].follow_up, out[fu.piece].fu_call = fu, call
            for q in qids:
                if q.startswith("spec_"):
                    s = Choice(call, q)
                    out.setdefault(s.piece, StepAnswers(s.piece)).spec = s
    return out


def cell(cell_id):
    return r2.BY_ID[cell_id]


def accepted(c):
    return [c["expected"]] + list(c["accept"] or [])


def step_class(c, piece, decision):
    """exact / path / miss for one decision on `piece` (decision = 'keep', NOTHING, ASK or a piece text)."""
    if decision == NOTHING:
        return "exact" if c["outcome"] == "nothing" else "miss"
    if decision == ASK:
        return "exact" if c["outcome"] == "ask" else "miss"
    if c["outcome"] != "paste":
        return "miss"
    text = piece if decision == "keep" else decision
    if decision == "keep" and piece == c["item"]:
        text = piece.strip("\r\n")
    if text in accepted(c):
        return "exact"
    if decision != "keep" and any(e and e in text for e in accepted(c)):
        return "path"
    return "miss"


def replay(paste, rule):
    """Walk the paste with `rule(choice) -> 'keep' | NOTHING | ASK | piece text`.
    Returns dict(outcome, final, known, steps=[(piece, decision, Choice)], stop_class)."""
    c = cell(paste["cell"])
    answers = answers_of(paste)
    piece, steps = c["item"], []
    for _ in range(12):
        sa = answers.get(piece)
        ch = sa.deciding() if sa else None
        if ch is None:
            # no recorded answer for this piece: unknown; score the decision that led here
            prev_piece, prev_dec, _ = steps[-1]
            return dict(outcome=None, final=None, known=False, steps=steps,
                        stop_class=step_class(c, prev_piece, prev_dec))
        dec = rule(ch)
        steps.append((piece, dec, ch))
        if dec == "keep":
            final = piece.strip("\r\n") if piece == c["item"] else piece
            return dict(outcome="paste", final=final, known=True, steps=steps, stop_class=None)
        if dec in (NOTHING, ASK):
            return dict(outcome="nothing" if dec == NOTHING else "ask", final=None, known=True, steps=steps,
                        stop_class=None)
        if dec not in piece or dec == piece:
            return dict(outcome="error", final=None, known=True, steps=steps, stop_class=None)
        piece = dec
    raise RuntimeError("too many steps")


def jev_rule(ch):
    return ch.meaning(ch.choice)


def score(paste, result):
    return r2.score(cell(paste["cell"]), result["outcome"], result["final"])


def short(text, n=30):
    if text is None:
        return "∅"
    text = text.replace("\n", "⏎")
    return "`%s`" % (text if len(text) <= n else text[:n] + "…")
