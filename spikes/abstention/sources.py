"""Source documents and target fields for the abstention spike.

RESUME_BASE reconstructs the demo resume from README.md as plain text, in the
reading order it would have when copied out of `Marcus Lowe Resume.pdf`.
The variants change exactly one thing each so probability shifts are attributable.
"""

RESUME_BASE = """Marcus Lowe
Co-founder & CEO

marcus@anything.com
https://skydive.com
https://x.com/marcus_lowe
San Francisco, CA

Profile
Product-minded technology founder building AI systems that help people turn ideas into working software.

Experience
Co-founder & CEO
Skydive
2021 - Present

Head of Product & Senior Software Engineer
Resource

Product Manager
Google Maps

Education
Massachusetts Institute of Technology
Bachelor of Science, 2014"""

# Case A: three distinct, all plausible email addresses.
RESUME_THREE_EMAILS = RESUME_BASE.replace(
    "marcus@anything.com\n",
    "marcus@anything.com\nm.lowe@skydive.com\nmarcus.lowe@alum.mit.edu\n",
)

# Case A2: two institutional addresses, neither of them an obvious primary.
RESUME_TWO_PEER_EMAILS = RESUME_BASE.replace(
    "marcus@anything.com",
    "m.lowe@skydive.com\nmarcus.lowe@alum.mit.edu",
)

# Case B: no address of any kind (the "San Francisco, CA" line is removed too).
RESUME_NO_ADDRESS = RESUME_BASE.replace("San Francisco, CA\n", "")

# Case D: unrelated document. No person name, but capitalised distractors
# ("San Marzano", "Dutch Oven", "Sea Salt") that a naive candidate extractor
# will happily offer as name-shaped excerpts.
RECIPE = """Slow Tomato Sauce

Warm the olive oil in a Dutch Oven over low heat and let a halved onion soften
without colouring. Add two tins of San Marzano tomatoes, crushed by hand, a
pinch of Sea Salt and a single bay leaf. Simmer uncovered for forty-five
minutes, stirring now and then, until the sauce pulls away from the side of
the pan. Fish out the onion and the bay leaf before serving with rigatoni.
Keeps for four days in the fridge."""

# Case E: structurally symmetric alternatives. Two people, three addresses, no
# document owner to prefer. If Jev ever spreads probability, it should be here.
EMAIL_HEADER = """From: Marcus Lowe <marcus@anything.com>
To: Priya Raman <priya.raman@northstar.design>
Cc: hiring@northstar.design
Subject: Product Designer application
Date: Tue, 16 Sep 2026 09:14:03 -0700

Hi Priya,

Attaching the portfolio as promised.

Marcus"""

FORM_TITLE = "Product Designer Application"

TARGETS = {
    "email": {
        "label": "Email address",
        "placeholder": "you@example.com",
        "section": "Personal details",
    },
    "full_name": {
        "label": "Full name",
        "placeholder": "Your full name",
        "section": "Personal details",
    },
    "company": {
        "label": "Current company",
        "placeholder": "Company or studio",
        "section": "Professional background",
    },
    "postal": {
        "label": "Postal address",
        "placeholder": "Street and number, ZIP, City",
        "section": "Personal details",
    },
    "location": {
        "label": "Current location",
        "placeholder": "City, State",
        "section": "Personal details",
    },
}

# case id -> (source text, source label, target key, expected excerpt or None)
CASES = {
    "C1_email_control": (RESUME_BASE, "resume", "email", "marcus@anything.com"),
    "C2_name_control": (RESUME_BASE, "resume", "full_name", "Marcus Lowe"),
    "C3_company_soft": (RESUME_BASE, "resume", "company", "Skydive"),
    "A_email_three": (RESUME_THREE_EMAILS, "resume_3_emails", "email", None),
    "B1_postal_absent": (RESUME_NO_ADDRESS, "resume_no_address", "postal", None),
    "B2_postal_citystate": (RESUME_BASE, "resume", "postal", None),
    "D1_recipe_name": (RECIPE, "recipe", "full_name", None),
    "D2_recipe_email": (RECIPE, "recipe", "email", None),
    "E1_header_name": (EMAIL_HEADER, "email_header", "full_name", None),
    "E2_header_email": (EMAIL_HEADER, "email_header", "email", None),
    "A2_email_two_peer": (RESUME_TWO_PEER_EMAILS, "resume_2_peer_emails", "email", None),
    "F_location_nested": (RESUME_BASE, "resume", "location", "San Francisco, CA"),
}
