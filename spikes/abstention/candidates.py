"""Local candidate derivation: exact contiguous verbatim excerpts of the source.

Jev never authors text, so the app must produce the answer space itself. This
extractor is deliberately dumb and generic (it knows nothing about resumes) so
the abstention measurements are not helped by a hand-tuned candidate list.
"""

import re

MAX_CANDIDATES = 20
MAX_DESCRIPTION = 255

EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
URL_RE = re.compile(r"https?://[^\s,;)]+")
CAPS_RUN_RE = re.compile(r"\b[A-Z][A-Za-z.&'-]*(?:[ ]+[A-Z][A-Za-z.&'-]*){1,2}\b")
CITY_STATE_RE = re.compile(r"\b[A-Z][a-z]+(?:[ ]+[A-Z][a-z]+)*,[ ]+[A-Z]{2}\b")
# a terminator only ends a sentence when whitespace or the end follows it, so
# "marcus@anything.com" does not split into "marcus@anything."
SENTENCE_RE = re.compile(r"[^.!?]+[.!?](?=\s|$)")


def _add(out, source, text):
    text = text.strip().strip(",;")
    if not text or len(text) < 2:
        return
    if text not in source or text in out:
        return
    out.append(text)


def derive(source):
    """Return ordered, deduplicated verbatim excerpts of `source`."""
    found = []
    # 1. atoms with strong shape
    for regex in (EMAIL_RE, URL_RE, CITY_STATE_RE):
        for match in regex.finditer(source):
            _add(found, source, match.group(0))
    # 2. whole lines
    for line in source.split("\n"):
        _add(found, source, line)
    # 3. sentences inside long lines/paragraphs
    for block in source.split("\n\n"):
        flat = block.replace("\n", " ")
        if len(flat) < 90:
            continue
        for match in SENTENCE_RE.finditer(flat):
            sentence = match.group(0).strip()
            if len(sentence) < 20:
                continue
            # only keep it if it survives verbatim in the source
            if sentence in source:
                _add(found, source, sentence)
    # 4. capitalised runs (name-shaped distractors)
    for match in CAPS_RUN_RE.finditer(source):
        _add(found, source, match.group(0))

    # stable order: by first occurrence in the source, shorter first on ties
    found.sort(key=lambda t: (source.index(t), len(t)))
    return found[:MAX_CANDIDATES]


def as_criteria(excerpts, include_none):
    """Build the choice `criteria` map: option id -> description (<=255 chars)."""
    criteria = {}
    for index, excerpt in enumerate(excerpts, start=1):
        description = excerpt.replace("\n", " ")
        if len(description) > MAX_DESCRIPTION:
            description = description[: MAX_DESCRIPTION - 3] + "..."
        criteria["c%02d" % index] = description
    if include_none:
        criteria["none_of_these"] = (
            "None of the listed excerpts is the value that belongs in the target "
            "field. Choose this when the source document does not contain the "
            "value, or when no single excerpt is right."
        )
    return criteria
