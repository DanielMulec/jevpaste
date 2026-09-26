"""Structural Candidates (mirror of `docs/design/candidate-derivation.md` rules 1-10 and the Swift adapter
`StructuralCandidateExtraction` on main), same-type detection, and the stage-2 span rules of Engine J.

Every excerpt is a slice of the item by index range, so it is a byte-exact contiguous substring.
Python slices by code point, Swift by `Character`; the fixtures contain no combining sequences, so the two agree
here (a Swift port must count indentation, label length and heading length in `Character`s).
"""

import re

CAP = 254  # Jev takes 255 options; none_of_these is one of them

# Swift `Character.isNewline`: U+000A-U+000D, U+0085, U+2028, U+2029; CRLF is one Character.
_NEWLINE_RE = re.compile("\r\n|[\n\x0b\x0c\r\x85\u2028\u2029]")


# ----------------------------------------------------------------------------------------------- lines (1, 2)
class Line:
    def __init__(self, text, start, end):
        # [start, end) is the raw line in the item, without its break
        raw = text[start:end]
        stripped_left = len(raw) - len(raw.lstrip())
        stripped_right = len(raw) - len(raw.rstrip())
        self.indentation = stripped_left
        self.start = start + stripped_left
        self.end = end - stripped_right if raw.strip() else start + stripped_left
        self.trimmed = text[self.start:self.end]

    @property
    def blank(self):
        return self.trimmed == ""


def source_lines(text):
    lines, position = [], 0
    for match in _NEWLINE_RE.finditer(text):
        lines.append(Line(text, position, match.start()))
        position = match.end()
    lines.append(Line(text, position, len(text)))
    return lines


# ------------------------------------------------------------------------------------------ Label: value (3)
def labelled_value_range(line):
    """(start, end) of the value of a `Label: value` line, or None."""
    t = line.trimmed
    for i, ch in enumerate(t):
        if ch == ":" and i + 1 < len(t) and t[i + 1] in " \t":
            label = t[:i]
            if not (1 <= len(label) <= 40) or ":" in label:
                return None
            rest = t[i + 1:]
            value = rest.strip()
            if not value:
                return None
            vstart = line.start + i + 1 + (len(rest) - len(rest.lstrip()))
            return vstart, vstart + len(value)
    return None


# ----------------------------------------------------------------------------------------- heading-like (6)
def is_heading_like(lines, p):
    line = lines[p]
    t = line.trimmed
    if not t or labelled_value_range(line) is not None:
        return False
    markdown = re.fullmatch(r"#{1,6}[ \t].*", t, re.S) is not None
    colon = t.endswith(":") and len(t) <= 60
    upper = sum(c.isalpha() for c in t) >= 2 and not any(c.islower() for c in t) and len(t) <= 60
    nxt = lines[p + 1] if p + 1 < len(lines) and not lines[p + 1].blank else None
    deeper = nxt is not None and nxt.indentation > line.indentation
    starts_paragraph = p == 0 or lines[p - 1].blank
    short = (starts_paragraph and nxt is not None and len(t) <= 60 and len(t.split()) <= 4
             and t[-1] not in ".,;")
    return markdown or colon or upper or deeper or short


# ------------------------------------------------------------------------------------------------ kinds (4, 5)
DROP_RANK = {"whole_item": 0, "section": 1, "paragraph": 2, "whole_labelled_line": 3,
             "plain_line": None, "label_value": None}


def _excerpts(text):
    lines = source_lines(text)
    out = []
    for line in lines:
        if line.blank:
            continue
        value = labelled_value_range(line)
        if value is None:
            out.append((line.start, line.end, "plain_line"))
        else:
            out.append((line.start, line.end, "whole_labelled_line"))
            out.append((value[0], value[1], "label_value"))
    # paragraphs: maximal runs of >= 2 non-blank lines
    run = []
    for line in lines + [None]:
        if line is not None and not line.blank:
            run.append(line)
            continue
        if len(run) >= 2:
            out.append((run[0].start, run[-1].end, "paragraph"))
        run = []
    # sections
    for h in range(len(lines)):
        if not is_heading_like(lines, h):
            continue
        first = h + 1
        if first >= len(lines) or lines[first].blank:
            continue
        end = len(lines)
        for q in range(first + 1, len(lines)):
            if lines[q].blank or is_heading_like(lines, q) or lines[q].indentation < lines[first].indentation:
                end = q
                break
        out.append((lines[h].start, lines[end - 1].end, "section"))
    # whole item
    non_blank = [line for line in lines if not line.blank]
    if len(non_blank) >= 2:
        out.append((non_blank[0].start, non_blank[-1].end, "whole_item"))
    return out


def candidates_with_kinds(text):
    """[(text, kind)] in production order, deduplicated and capped (rules 7, 8, 10)."""
    big = 1 << 30
    ordered = sorted(_excerpts(text),
                     key=lambda e: (e[0], -e[1], -(DROP_RANK[e[2]] if DROP_RANK[e[2]] is not None else big)))
    seen, kept = set(), []
    for start, end, kind in ordered:
        piece = text[start:end]
        key = piece.encode("utf-8")
        if key in seen:
            continue
        seen.add(key)
        kept.append((piece, kind))
    surplus = len(kept) - CAP
    if surplus > 0:
        dropped = set()
        for rank in sorted({r for r in DROP_RANK.values() if r is not None}):
            if surplus <= 0:
                break
            idx = [i for i, (_, k) in enumerate(kept) if DROP_RANK[k] == rank][-surplus:] if surplus else []
            dropped.update(idx)
            surplus -= len(idx)
        kept = [e for i, e in enumerate(kept) if i not in dropped][:CAP]
    return kept


def derive(text):
    return [piece for piece, _ in candidates_with_kinds(text)]


# ------------------------------------------------------------------------------------------ same-type detection
_EMAIL = re.compile(r"[A-Z0-9._%+\-]+@[A-Z0-9\-]+(\.[A-Z0-9\-]+)*\.[A-Z]{2,}", re.I)
_URL = re.compile(r"(https?://|www\.)\S+", re.I)
_HANDLE = re.compile(r"@[A-Z0-9_]{1,30}", re.I)
_PHONE = re.compile(r"\+?\(?[0-9]+\)?([ ./\-]?\(?[0-9]+\)?)*")
_GROUP = re.compile(r"(\([0-9]+\)|[0-9]+)")


def _is_phone(text):
    if not _PHONE.fullmatch(text):
        return False
    digits = sum(c in "0123456789" for c in text)
    groups = len(_GROUP.findall(text))
    return 7 <= digits <= 15 and (text.startswith("+") or groups >= 3 or digits >= 10)


def candidate_type(text):
    if _EMAIL.fullmatch(text):
        return "email"
    if _URL.fullmatch(text):
        return "url"
    if _HANDLE.fullmatch(text):
        return "handle"
    if _is_phone(text):
        return "phone"
    return None


def same_type_alternatives(chosen, offered):
    """Production `sameTypeAlternatives`: all offered with the chosen one's type, or [chosen]."""
    kind = candidate_type(chosen)
    if kind is None or chosen not in offered:
        return [chosen]
    return [o for o in offered if candidate_type(o) == kind]


# ------------------------------------------------------------------------------------------ stage-2 spans (J)
SPAN_DELIMITERS = set(",;:()\"'<>/")
# Supervisor addition (reachability): the extended cut set adds `@ . - _`, used only for unreachable cells.
EXTENDED_DELIMITERS = SPAN_DELIMITERS | set("@.-_")
MAX_SPAN_TOKENS = 12


def tokens(text, delimiters=SPAN_DELIMITERS):
    """[(start, end)] of maximal runs that are neither whitespace nor a delimiter."""
    out, start = [], None
    for i, ch in enumerate(text):
        boundary = ch.isspace() or ch in delimiters
        if boundary and start is not None:
            out.append((start, i))
            start = None
        elif not boundary and start is None:
            start = i
    if start is not None:
        out.append((start, len(text)))
    return out


def spans(candidate, cap=CAP, max_tokens=MAX_SPAN_TOKENS, delimiters=SPAN_DELIMITERS):
    """Every contiguous run of 1..max_tokens tokens of `candidate`, as byte-exact slices.

    Order: by start, shorter first. Dedup by UTF-8 bytes (first wins). While more than `cap` remain, the longest
    (most tokens) go first, within a length the last in document order first. Returns (spans, total_before_cap).
    """
    toks = tokens(candidate, delimiters)
    found = []  # (start, n_tokens, text)
    for i in range(len(toks)):
        for n in range(1, max_tokens + 1):
            j = i + n - 1
            if j >= len(toks):
                break
            found.append((toks[i][0], n, candidate[toks[i][0]:toks[j][1]]))
    found.sort(key=lambda f: (f[0], f[1]))
    seen, unique = set(), []
    for f in found:
        key = f[2].encode("utf-8")
        if key in seen:
            continue
        seen.add(key)
        unique.append(f)
    total = len(unique)
    if total > cap:
        by_drop = sorted(range(total), key=lambda i: (-unique[i][1], -unique[i][0]))
        dropped = set(by_drop[: total - cap])
        unique = [f for i, f in enumerate(unique) if i not in dropped]
    return [f[2] for f in unique], total


if __name__ == "__main__":
    import fixtures

    for item_id, text in fixtures.ITEMS.items():
        cands = candidates_with_kinds(text)
        print("== %s: %d candidates" % (item_id, len(cands)))
        for piece, kind in cands:
            s, total = spans(piece)
            print("  %-20s %3d spans (%3d before cap) type=%-6s %r"
                  % (kind, len(s), total, candidate_type(piece), piece[:70]))
