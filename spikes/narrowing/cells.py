"""Every cell of the Narrowing spike, in one uniform shape. All data synthetic.

Groups:
  matrix   the 56 cells of spikes/any-field/fixtures.py (6 trap cells), unchanged
  whole    whole-copy places (spikes/free-text/situations.py targets) with a multi-line item -> the whole copy
  chooser  three equal emails (spikes/abstention/sources.py case A) -> "ask the user"
  new      single-line address into "Ort", URL into a chat composer, a 300-line list, a copy too big for one call

A cell: id, group, item (the copy), context (production `target_context`), expected (text, or None), accept,
outcome ("paste" | "nothing" | "ask"), borderline (note or None).
Expected values are used only for scoring and never sent to Jev.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
for sub in ("any-field", "free-text", "abstention"):
    sys.path.append(os.path.join(HERE, "..", sub))

import fixtures  # noqa: E402  (spikes/any-field)
import situations  # noqa: E402  (spikes/free-text)
import sources  # noqa: E402  (spikes/abstention)


def _cell(cid, group, item, context, expected, accept=(), outcome="paste", borderline=None):
    return {"id": cid, "group": group, "item": item, "context": context, "expected": expected,
            "accept": list(accept), "outcome": outcome, "borderline": borderline}


def _situation_context(sid):
    return {k: v for k, v in situations.BY_ID[sid][3].items() if v not in (None, "", [])}


CELLS = []

# ---------------------------------------------------------------------------------------------- 1. the matrix
for item_id, c in fixtures.all_cells():
    outcome = "nothing" if c["expected"] is None else "paste"
    borderline = c["borderline"]
    if c["id"] == "T01_email_two_lines":
        outcome = "ask"  # criterion 4: the chooser opens on two emails
        borderline = None
    CELLS.append(_cell(c["id"], "matrix", fixtures.ITEMS[item_id], fixtures.target_context(c), c["expected"],
                       c["accept"], outcome, borderline))

# ------------------------------------------------------------------------------------------ 2. whole-copy places
WHOLE_ITEM = situations.SOURCE_DOCUMENT  # 6 lines: name, email, phone, street, city line, one paragraph
for sid, label in (("S07_comment_box", "W01_chrome_textarea"), ("S02_terminal", "W02_terminal_prompt"),
                   ("S01a_chatgpt_placeholder", "W03_chatgpt_composer"), ("S04_whatsapp", "W04_whatsapp_composer")):
    CELLS.append(_cell(label, "whole", WHOLE_ITEM, _situation_context(sid), WHOLE_ITEM))

# --------------------------------------------------------------------------------------------- 3. chooser cells
APPLICATION_FORM_TEXT = (
    "Northstar Design\nCareers / Product Designer\nProduct Designer Application\n"
    "Tell us who you are. We reply to every application within ten working days.\n"
    "Personal details\nFull name *\nYour full name\nEmail address *\nyou@example.com\n"
    "We send the confirmation and all interview invitations to this address.\n"
    "Current location\nCity, State\nX / Twitter profile\n"
    "Professional background\nCurrent company\nCompany or studio\nCurrent role\nYour title\n"
    "Portfolio link\nUpload CV (PDF)\nSubmit application"
)
CELLS.append(_cell("K01_three_emails", "chooser", sources.RESUME_THREE_EMAILS, {
    "app_name": "Google Chrome",
    "window_title": "Product Designer Application – Northstar Design",
    "field_label": "Email address",
    "placeholder": "you@example.com",
    "section_heading": "Personal details",
    "sibling_field_labels": ["Full name", "Current location", "X / Twitter profile", "Current company",
                             "Current role", "Portfolio link"],
    "surrounding_text": APPLICATION_FORM_TEXT,
}, None, accept=["marcus@anything.com", "m.lowe@skydive.com", "marcus.lowe@alum.mit.edu"], outcome="ask"))

# ------------------------------------------------------------------------------------------------ 4. new cells
ADDRESS_ONE_LINE = "Mira Holzner, Prankergasse 77, 8020 Graz"
_ort = next(c for _, c in fixtures.all_cells() if c["id"] == "A07_ort")
CELLS.append(_cell("N01_address_line_ort", "new", ADDRESS_ONE_LINE, fixtures.target_context(_ort), "Graz"))

URL = "https://www.miraholzner.example/portfolio/kiln-series-2026?view=grid"
CELLS.append(_cell("N02_url_chat", "new", URL, _situation_context("S01a_chatgpt_placeholder"), URL))


def _log_lines(count, special_at, special):
    services = ["auth", "billing", "search", "mailer", "images", "reports", "sync", "cache"]
    verbs = ["request served in", "job finished in", "health check ok after", "batch flushed in",
             "retry succeeded after", "session refreshed in"]
    out = []
    for i in range(count):
        if i == special_at:
            out.append(special)
            continue
        minute, second = divmod(i * 7 + 3, 60)
        out.append("2026-09-12 %02d:%02d:%02d INFO %s-%d %s %d ms (req %05d)" % (
            8 + minute // 60, minute % 60, second, services[i % 8], i % 5 + 1, verbs[i % 6],
            40 + (i * 37) % 900, 10000 + i * 13))
    return "\n".join(out)


VOUCHER = "WINTER-4471-KQ"
LIST_300 = _log_lines(300, 237, "2026-09-12 12:41:02 INFO checkout-2 voucher issued to guest order: %s" % VOUCHER)
CHECKOUT_CONTEXT = {
    "app_name": "Google Chrome",
    "window_title": "Checkout – Nordic Paper Co.",
    "field_label": "Gift card or discount code",
    "section_heading": "Order summary",
    "sibling_field_labels": ["Email", "First name", "Last name", "Street", "City", "Postcode"],
    "surrounding_text": (
        "Checkout – Nordic Paper Co.\n1 Cart  2 Shipping  3 Payment\nOrder summary\n"
        "Linen notebook A5 × 2   CHF 38.00\nSubtotal   CHF 38.00\nShipping   Calculated at next step\n"
        "Gift card or discount code\nApply\nTotal   CHF 38.00\n"
        "Contact\nEmail\nShipping address\nFirst name\nLast name\nStreet\nCity\nPostcode\n"
        "Continue to shipping"
    ),
}
CELLS.append(_cell("N03_list_300_lines", "new", LIST_300, CHECKOUT_CONTEXT, VOUCHER))

TOO_BIG = _log_lines(3000, 2370, "2026-09-12 12:41:02 INFO checkout-2 voucher issued to guest order: %s" % VOUCHER)
CELLS.append(_cell("N04_too_big", "new", TOO_BIG, CHECKOUT_CONTEXT, None, outcome="too_long"))

BY_ID = {c["id"]: c for c in CELLS}


def _self_check():
    assert len([c for c in CELLS if c["group"] == "matrix"]) == 56
    for c in CELLS:
        for text in ([c["expected"]] if c["expected"] else []) + c["accept"]:
            assert text in c["item"], (c["id"], text)
    assert len(LIST_300.splitlines()) == 300 and LIST_300.count(VOUCHER) == 1


_self_check()
