"""Cutting for Narrowing: which pieces are offered next to the current piece. No meaning rules.

The scissors cut at three kinds of cut point, coarse to fine ("units"):

  1. line breaks   -> lines. A line piece is a run of consecutive non-blank lines (blank lines inside a run are
                      kept; a run starts and ends on a non-blank line, its outer spaces trimmed).
  2. spaces and punctuation -> tokens. A token is a maximal run of letters/digits (`str.isalnum`), or one single
                      character that is neither a letter/digit nor white space. A token piece is a run of
                      consecutive tokens of one line, from the first token's start to the last token's end.
  3. characters    -> every substring of a single token.

Every piece is a slice of its parent by index range, and every parent is a slice of the copy, so every piece is a
byte-exact contiguous substring of the copy.

children(P) — the pieces offered next to "P unchanged" (deduplicated by text, P itself excluded):
  * P holds 2+ non-blank lines -> every run of its lines + 4 edge cuts.
    Flattening: if that plus the token runs of every single line fit in ONE choice (<= 252 pieces next to
    "unchanged") and in the size budget, all of them are offered at once (saves a step).
  * P is one line of 2+ tokens  -> every run of its tokens + character edge cuts.
  * P is one token of 2+ chars  -> every substring of it.
  * P is one character          -> no children: final without a call.
  * Too big for one request (size budget below): the units of that level are grouped into blocks of b consecutive
    units (b the smallest that fits) and every run of blocks is offered, plus every single unit (+ edge cuts when they
    still fit); the next step cuts the chosen piece finer.
  More than 252 pieces, or more than one question's size -> several choice questions in one request (run.py).

Edge cuts make substrings reachable that start or end mid-token, or mid-line across a line break:
  one line  -> every cut at a character inside its first token (from the left) and its last token (from the right);
  several lines -> four unit cuts: without its first token / first character / last token / last character.
With them every contiguous substring of the copy that starts and ends on a non-space character is reachable
(`self_check`, exhaustive on sample texts).
"""

import heapq
import json
import re

PIECES_PER_CHOICE = 253  # 255 options per Choice (TypeSafe API reference) minus "nothing fits" and "ask the user"

# Swift `Character.isNewline`: U+000A-U+000D, U+0085, U+2028, U+2029; CRLF is one break.
NEWLINE_RE = re.compile("\r\n|[\n\x0b\x0c\r\x85\u2028\u2029]")

# ------------------------------------------------------------------------------------------------ size model
# TypeSafe Models page: 64k tokens per request; 32k tokens for `state` plus the longest question.
# Jev's tokenizer is not public. Conservative estimate from `usage.inputTokens` of the smoke and probe calls
# (prose 1k-50k tokens: estimate/actual 1.1-1.35; digit-heavy log text 26k-33k tokens: 0.97-1.0):
# 0.25/letter, 1.0/digit, 1.0/other non-space char, 12/option, 250/question.
# Measured limits (probe, results/raw.jsonl): state + one question accepted at 32,869 input tokens and refused one
# step later (806 log lines); three questions over one state accepted at 56,901 tokens (the state counts once),
# four refused. Headroom 8 % (log text is under-estimated by up to 3 %).
QUESTION_BUDGET_TOKENS = int(32_000 * 0.92)  # state + one question
REQUEST_BUDGET_TOKENS = int(64_000 * 0.92)   # state + all questions
OPTION_TOKENS = 12
QUESTION_TOKENS = 250


def est_tokens(text):
    letters = digits = other = 0
    for ch in text:
        if ch.isalpha():
            letters += 1
        elif ch.isdigit():
            digits += 1
        elif not ch.isspace():
            other += 1
    return 0.25 * letters + 1.0 * digits + 1.0 * other


def option_tokens(piece):
    return est_tokens(piece) + OPTION_TOKENS


class Budget:
    """Tokens already committed per question (state + instructions + fixed options) for one step."""

    def __init__(self, state_tokens=0.0, question_tokens=QUESTION_TOKENS + 150):
        self.state = state_tokens
        self.question = question_tokens

    @property
    def room(self):
        return QUESTION_BUDGET_TOKENS - self.state - self.question

    def chunk(self, pieces):
        """Split pieces into choices, in order: <= 252 pieces and <= `room` tokens of options each."""
        size, room = PIECES_PER_CHOICE - 1, self.room
        if room <= 0:
            room = None  # the copy alone is over budget: chunk by count only; Jev will refuse the request
        out, current, used = [], [], 0.0
        for p in pieces:
            c = option_tokens(p)
            if current and (len(current) >= size or (room is not None and used + c > room)):
                out.append(current)
                current, used = [], 0.0
            current.append(p)
            used += c
        if current:
            out.append(current)
        return out or [[]]

    def fits(self, pieces):
        if self.room <= 0 or any(option_tokens(p) > self.room for p in pieces):
            return False
        chunks = self.chunk(pieces)
        total = self.state + sum(self.question + sum(option_tokens(p) for p in c) for c in chunks)
        return total <= REQUEST_BUDGET_TOKENS  # the follow-up choice is a separate, small request

    def fits_estimate(self, total_option_tokens):
        """Quick lower bound before building pieces: can this many option tokens fit in one request at all?"""
        return self.state + total_option_tokens <= REQUEST_BUDGET_TOKENS - self.question


# ------------------------------------------------------------------------------------------------ primitives
def lines(text):
    """Non-blank lines as (start, end), outer spaces trimmed."""
    out, position = [], 0
    bounds = [(m.start(), m.end()) for m in NEWLINE_RE.finditer(text)] + [(len(text), len(text))]
    for brk_start, _brk_end in bounds:
        raw = text[position:brk_start]
        if raw.strip():
            left = len(raw) - len(raw.lstrip())
            right = len(raw) - len(raw.rstrip())
            out.append((position + left, brk_start - right))
        position = _brk_end
    return out


def tokens(text, start=0, end=None):
    """Tokens of text[start:end] as (start, end) in text coordinates."""
    end = len(text) if end is None else end
    out, i = [], start
    while i < end:
        ch = text[i]
        if ch.isspace():
            i += 1
        elif ch.isalnum():
            j = i + 1
            while j < end and text[j].isalnum():
                j += 1
            out.append((i, j))
            i = j
        else:
            out.append((i, i + 1))
            i += 1
    return out


def blocks_of(spans, block):
    return [(spans[k][0], spans[min(k + block, len(spans)) - 1][1]) for k in range(0, len(spans), block)]


def runs(text, spans):
    """Every run of consecutive spans, as text slices, in document order (start asc, longer first)."""
    out = []
    for i in range(len(spans)):
        for j in range(len(spans) - 1, i - 1, -1):
            out.append(text[spans[i][0]:spans[j][1]])
    return out


def runs_total_chars(spans):
    """Characters of all runs of `spans`, without building them."""
    m = len(spans)
    ends = sum(e * (j + 1) for j, (_, e) in enumerate(spans))
    starts = sum(s * (m - i) for i, (s, _) in enumerate(spans))
    return ends - starts


def char_pieces(token_text):
    n = len(token_text)
    return [token_text[i:j] for i in range(n) for j in range(n, i, -1)]


def dedupe(pieces, parent):
    seen, out = set(), []
    for p in pieces:
        if p and p != parent and p not in seen:
            seen.add(p)
            out.append(p)
    return out


def edge_trims(piece):
    ls = lines(piece)
    if not ls:
        return []
    begin, end = ls[0][0], ls[-1][1]
    first_toks = tokens(piece, *ls[0])
    last_toks = tokens(piece, *ls[-1])
    (fs, fe), (ls_, le) = first_toks[0], last_toks[-1]
    if len(ls) >= 2:
        return [piece[first_toks[1][0] if len(first_toks) > 1 else fe:end].strip(), piece[begin + 1:end].strip(),
                piece[begin:last_toks[-2][1] if len(last_toks) > 1 else ls_].strip(), piece[begin:end - 1].strip()]
    return [piece[k:end] for k in range(fs + 1, fe)] + [piece[begin:k] for k in range(le - 1, ls_, -1)]


# ------------------------------------------------------------------------------------------------- children
def _grouped(piece, units, extra, budget, unit_name):
    """All runs of `units` (+ extra) if they fit; else blocks of b units (smallest b that fits) + every single unit
    (+ extra if it still fits)."""
    density = est_tokens(piece) / max(1, len(piece))
    singles = [piece[s:e] for s, e in units]

    def estimate(spans):
        m = len(spans)
        return runs_total_chars(spans) * density + OPTION_TOKENS * m * (m + 1) / 2

    if budget.fits_estimate(estimate(units)):
        pieces = dedupe(runs(piece, units) + extra, piece)
        if budget.fits(pieces):
            return pieces, "%s runs" % unit_name
    for block in range(2, len(units) + 1):
        spans = blocks_of(units, block)
        if not budget.fits_estimate(estimate(spans) + sum(option_tokens(s) for s in singles)):
            continue
        for with_extra in (True, False):
            pieces = dedupe(runs(piece, spans) + singles + (extra if with_extra else []), piece)
            if budget.fits(pieces):
                return pieces, "runs of blocks of %d %s + single %s%s" % (
                    block, unit_name, unit_name, " + edge cuts" if with_extra else "")
    return dedupe(singles, piece), "single %s (over budget)" % unit_name


def children(piece, budget=None):
    """(pieces, how) offered next to `piece` unchanged. `how` names the grouping used (for the log)."""
    budget = budget or Budget()
    ls = lines(piece)
    if len(ls) >= 2:
        trims = edge_trims(piece)
        if budget.fits_estimate(runs_total_chars(ls) * est_tokens(piece) / max(1, len(piece))):
            base = dedupe(runs(piece, ls) + trims, piece)
            flat = list(base)
            for start, end in ls:
                flat.extend(runs(piece, tokens(piece, start, end)))
            flat = dedupe(flat, piece)
            if len(flat) <= PIECES_PER_CHOICE - 1 and budget.fits(flat):
                return flat, "line runs + token runs"
        return _grouped(piece, ls, trims, budget, "lines")
    toks = tokens(piece)
    if len(toks) >= 2:
        return _grouped(piece, toks, edge_trims(piece), budget, "tokens")
    if len(toks) == 1:
        s, e = toks[0]
        inner = piece[s:e]
        if inner != piece:
            return [inner], "the token"
        chars = [(i, i + 1) for i in range(len(inner))]
        return _grouped(piece, chars, [], budget, "characters")
    return [], "none"


# ------------------------------------------------------------------------------------------- reachability
def path_to(copy, target, children_fn=None):
    """The cheapest Narrowing path (fewest Jev calls) from the copy to `target`, following only offered pieces that
    contain it. children_fn(piece) -> (pieces, how, n_choices). Returns (steps, reached);
    steps = [(piece, n_options, n_choices, how, pick)]; the last step picks "unchanged" (omitted when the target has
    nothing smaller to cut: final without a call)."""
    if children_fn is None:
        def children_fn(p):
            kids, how = children(p)
            return kids, how, len(Budget().chunk(kids))
    frontier = [(0, 0, copy)]
    best = {copy: (0, None, None)}
    counter = 0
    while frontier:
        cost, _, piece = heapq.heappop(frontier)
        if cost > best[piece][0]:
            continue
        kids, how, n_choices = children_fn(piece)
        step_cost = 1 + (1 if n_choices > 1 else 0)
        if piece == target:
            steps = [(piece, len(kids) + 1, n_choices, how, "unchanged")] if kids else []
            node = piece
            while best[node][1] is not None:
                steps.insert(0, best[node][2] + (node,))
                node = best[node][1]
            return steps, True
        for k in kids:
            if target in k and (k not in best or best[k][0] > cost + step_cost):
                best[k] = (cost + step_cost, piece, (piece, len(kids) + 1, n_choices, how))
                counter += 1
                heapq.heappush(frontier, (cost + step_cost, counter, k))
    return [], False


def calls_for(steps):
    """Jev calls along a path: 1 per step, +1 follow-up per step that needed more than one choice."""
    return sum(1 + (1 if n_choices > 1 else 0) for _, _, n_choices, _, _ in steps)


def self_check(text):
    """Every substring of `text` that starts and ends on a non-space character must be reachable."""
    missing = []
    for i in range(len(text)):
        if text[i].isspace():
            continue
        for j in range(i + 1, len(text) + 1):
            if text[j - 1].isspace():
                continue
            if not path_to(text, text[i:j])[1]:
                missing.append(text[i:j])
    return missing


if __name__ == "__main__":
    samples = ["Mira Holzner\nPrankergasse77\n\n8020 Graz.", "a@b.c d\ne-f g\nx", "Innsbruck. Hi",
               "ab-cd ef\n\ngh ij.k\nl m"]
    for sample in samples:
        print(repr(sample), "unreachable:", self_check(sample) or "none")
