"""Candidate-excerpt derivation strategies for the granularity spike.

Every candidate must be an exact contiguous substring of the source text
(the hard product rule), so each strategy verifies that before returning.
"""

import re

LABEL_VALUE = re.compile(r"^([A-Za-z][A-Za-z0-9 /&.\-]{0,40}):\s+(\S.*)$")
SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+")


def by_line(text):
    """(a) One candidate per non-blank line."""
    return [line.strip() for line in text.split("\n") if line.strip()]


def by_paragraph(text):
    """(b) One candidate per blank-line separated block."""
    return [block.strip() for block in re.split(r"\n\s*\n", text) if block.strip()]


def by_field_like(text):
    """(c) Lines, plus `Label: value` lines split so the value is its own candidate."""
    out = []
    for line in by_line(text):
        match = LABEL_VALUE.match(line)
        if match:
            out.append(match.group(2).strip())
            out.append(line)
        else:
            out.append(line)
    return out


def dense(text, include_words=False, max_words_per_line=8, max_ngram=3):
    """Over-generating strategy used for the >50 candidate stress test.

    Lines + paragraphs + sentences + bullet bodies + comma-separated pieces,
    optionally plus every 1-3 word run of short lines.
    """
    out = list(by_line(text))
    out.extend(by_paragraph(text))
    for line in by_line(text):
        body = line[1:].strip() if line.startswith("•") else line
        out.append(body)
        for sentence in SENTENCE_SPLIT.split(body):
            out.append(sentence.strip().rstrip("."))
        if "," in body:
            out.extend(piece.strip() for piece in body.split(","))
        if " – " in body:
            out.extend(piece.strip() for piece in body.split(" – "))
    if include_words:
        for line in by_line(text):
            words = line.split()
            if len(words) <= max_words_per_line:
                for size in range(1, max_ngram + 1):
                    for start in range(len(words) - size + 1):
                        out.append(" ".join(words[start:start + size]))
    return out


def deduplicate_verbatim(items, text):
    """Keep order, drop duplicates and anything that is not a verbatim substring."""
    seen = set()
    out = []
    for item in items:
        candidate = item.strip()
        if not candidate or candidate in seen:
            continue
        if candidate not in text:
            continue
        seen.add(candidate)
        out.append(candidate)
    return out


STRATEGIES = {
    "lines": by_line,
    "paragraphs": by_paragraph,
    "field_like": by_field_like,
    "dense": dense,
    "dense_words": lambda text: dense(text, include_words=True),
    "dense_max": lambda text: dense(text, include_words=True, max_words_per_line=14, max_ngram=4),
}

OPTION_CEILING = 255  # Jev's documented maximum number of choice options


def build(strategy_name, text):
    return deduplicate_verbatim(STRATEGIES[strategy_name](text), text)[:OPTION_CEILING]
