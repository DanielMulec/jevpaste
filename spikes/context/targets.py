"""Target definitions and target-context levels for the jev-context spike.

A target context is a plain dict. Level functions return the subset of that dict
that a hypothetical macOS Accessibility probe would have collected at that level.
The same dict is rendered into `instructions` text (packing A) or embedded as JSON
in `state` (packing B) so that only the packing differs between runs.
"""

from source_doc import SUMMARY

FORM_HEADING = "Product Designer Application"

FORM_FIELDS = [
    {
        "id": "full_name",
        "label": "Full name",
        "placeholder": "Your full name",
        "section": "Personal details",
        "expected": "Marcus Lowe",
    },
    {
        "id": "email",
        "label": "Email address",
        "placeholder": "you@example.com",
        "section": "Personal details",
        "expected": "marcus@anything.com",
    },
    {
        "id": "location",
        "label": "Current location",
        "placeholder": "City, State",
        "section": "Personal details",
        "expected": "San Francisco, CA",
    },
    {
        "id": "twitter",
        "label": "X / Twitter profile",
        "placeholder": "https://x.com/username",
        "section": "Personal details",
        "expected": "https://x.com/marcus_lowe",
    },
    {
        "id": "company",
        "label": "Current company",
        "placeholder": "Company or studio",
        "section": "Professional background",
        "expected": "Skydive",
    },
    {
        "id": "role",
        "label": "Current role",
        "placeholder": "Your title",
        "section": "Professional background",
        "expected": "Co-founder & CEO",
    },
    {
        "id": "summary",
        "label": "Professional summary",
        "placeholder": "A short summary of your experience",
        "section": "Professional background",
        "expected": SUMMARY,
    },
]

SECTION_FIELDS = {
    "Personal details": ["Full name", "Email address", "Current location", "X / Twitter profile"],
    "Professional background": ["Current company", "Current role", "Professional summary"],
}


def form_context(field: dict, level: str) -> dict:
    """L0 nothing, L1 label, L2 label+placeholder, L3 label+placeholder+form+neighbours."""
    if level == "L0":
        return {}
    context = {"field_label": field["label"]}
    if level in ("L2", "L3"):
        context["field_placeholder"] = field["placeholder"]
    if level == "L3":
        context["application"] = "Google Chrome"
        context["form_heading"] = FORM_HEADING
        context["section_heading"] = field["section"]
        context["other_field_labels_in_section"] = [
            label for label in SECTION_FIELDS[field["section"]] if label != field["label"]
        ]
    return context


# Targets whose label alone is genuinely underdetermined against this source: the L1 answer and the
# L3 answer differ. `expected` is the answer the full context implies; `expected_label_only` is what
# the bare label most plausibly implies.
AMBIGUOUS_FIELDS = [
    {
        "id": "edu_name",
        "label": "Name",
        "placeholder": "Institution name",
        "form_heading": "Graduate Fellowship Application",
        "section": "Education history",
        "neighbours": ["Degree", "Graduation year"],
        "expected": "Massachusetts Institute of Technology",
        "expected_label_only": "Marcus Lowe",
    },
    {
        "id": "edu_title",
        "label": "Title",
        "placeholder": "Degree title",
        "form_heading": "Graduate Fellowship Application",
        "section": "Education history",
        "neighbours": ["Name", "Graduation year"],
        "expected": "Bachelor of Science",
        "expected_label_only": "Co-founder & CEO",
    },
    {
        "id": "social_link",
        "label": "Link",
        "placeholder": "https://...",
        "form_heading": "Speaker Profile",
        "section": "Social profiles",
        "neighbours": ["LinkedIn URL", "Company website"],
        "expected": "https://x.com/marcus_lowe",
        "expected_label_only": "https://skydive.com",
    },
]


def ambiguous_context(field: dict, level: str) -> dict:
    if level == "L0":
        return {}
    context = {"field_label": field["label"]}
    if level in ("L2", "L3"):
        context["field_placeholder"] = field["placeholder"]
    if level == "L3":
        context["application"] = "Google Chrome"
        context["form_heading"] = field["form_heading"]
        context["section_heading"] = field["section"]
        context["other_field_labels_in_section"] = field["neighbours"]
    return context


WHATSAPP_CONTEXT = {
    "application": "WhatsApp",
    "window_title": "Priya Raman",
    "recent_messages": [
        "Priya: hey! sending the courier tomorrow",
        "Marcus: perfect, thanks",
        "Priya: What's your address?",
    ],
    "focused_field": "message composer, no label, no placeholder",
}

TERMINAL_CONTEXT = {
    "application": "Ghostty",
    "window_title": "marcus@mbp - gh",
    "visible_output": "$ gh auth login\n? What account do you want to log into? GitHub.com\nEnter GitHub handle: ",
    "focused_field": "terminal prompt, no label, no placeholder",
}

CHATGPT_CONTEXT = {
    "application": "ChatGPT",
    "window_title": "ChatGPT - New chat",
    "recent_messages": [
        "Assistant: I can draft that intro for you. First, what company do you work at?",
    ],
    "focused_field": "chat composer, no label, placeholder 'Ask anything'",
}

SCENARIOS = [
    {
        "id": "whatsapp_address",
        "context": WHATSAPP_CONTEXT,
        "expected": "San Francisco, CA",
        "note": "closest available excerpt; source has no street address",
    },
    {
        "id": "terminal_github",
        "context": TERMINAL_CONTEXT,
        "expected": None,
        "note": "no GitHub handle exists in the source: abstention probe",
    },
    {
        "id": "chatgpt_company",
        "context": CHATGPT_CONTEXT,
        "expected": "Skydive",
        "note": "company asked in conversation, no field label at all",
    },
]
