"""Synthetic fixtures for the any-field spike. All names and data are invented.

Each item is an Active Item (multi-line, so it never takes the single-line Direct Paste) plus a list of cells.
A cell is one paste of that item into one field: the field's Target Context (production keys, absent = omitted)
and the expected excerpt.

Cell keys:
  id              unique cell id
  field_label     production `field_label`
  siblings        production `sibling_field_labels`
  section         production `section_heading`
  expected        the exact excerpt that belongs in the field, or None (-> none_of_these)
  accept          other excerpts that also count as a hit (noted separately, e.g. `EUR 129,90`)
  whole           True when `expected` is itself a structural Candidate (gate `contains_more` should be low);
                  computed by run.py from candidates.derive, stored here only for reading
  borderline      free-text note when the expectation itself is debatable
  placeholder     production `placeholder` (optional)
  form            key into FORMS (window title + surrounding text)
"""

# --------------------------------------------------------------------------------------------------------------
# Items
# --------------------------------------------------------------------------------------------------------------

ADDRESS = (
    "Mira Holzner\n"
    "Prankergasse 77\n"
    "Top 11\n"
    "8020 Graz\n"
    "Österreich\n"
    "mira.holzner@example.org\n"
    "https://www.miraholzner.example\n"
    "06608405534"
)

SIGNATURE = (
    "Kind regards,\n"
    "Jonas Prell · Product Lead\n"
    "Phone +43 1 2345678 · Mobile +43 660 1112233\n"
    "jonas.prell@example.com | www.prell.example\n"
    "IBAN AT61 1904 3002 3457 3201"
)

RESUME = (
    "Anna Reisinger\n"
    "Born 14 March 1991 in Linz\n"
    "Nationality: Austrian\n"
    "\n"
    "Data engineer with eight years of experience building batch and streaming pipelines\n"
    "for logistics and retail. Led the migration of a nightly warehouse load to event\n"
    "streaming and mentors two junior engineers. Looking for a remote-first team.\n"
    "\n"
    "EXPERIENCE\n"
    "Senior Data Engineer, Voestra Analytics, Graz, Austria (2019–present)\n"
    "Data Engineer, Kerbl Logistics, Wels (2015–2019)"
)

RESUME_ABOUT = (
    "Data engineer with eight years of experience building batch and streaming pipelines\n"
    "for logistics and retail. Led the migration of a nightly warehouse load to event\n"
    "streaming and mentors two junior engineers. Looking for a remote-first team."
)

ORDER = (
    "Order 4711 for wren.castellan@example.net\n"
    "Ship to: Lise Adler, Hauptstr. 5, 4020 Linz\n"
    "Total EUR 129,90\n"
    "Tracking DHL 00340434161234567890"
)

BIO_P1 = (
    "Hi, I'm Lena Vogt, a ceramicist working out of a small studio in Innsbruck.\n"
    "I post new glazes and kiln experiments as @mira_h and teach weekend wheel classes."
)
BIO_P2 = (
    "Born in 1994 and raised on a farm in the Tyrolean Alps, I started throwing pots at sixteen.\n"
    "These days I split my time between restaurant commissions and a small online shop."
)
BIO = BIO_P1 + "\n\n" + BIO_P2

COVER_P1 = (
    "I am writing to apply for the Junior Landscape Architect position at Grünraum Studio.\n"
    "I graduated in landscape planning this summer and spent two internships designing school gardens."
)
COVER_P2 = (
    "What draws me to Grünraum is your work on climate-resilient streets and shaded courtyards.\n"
    "I want to learn how planting plans survive real budgets, and your mixed teams are the place to do it."
)
COVER_P3 = (
    "I can start on 1 December 2026 and am available for interviews on any weekday afternoon.\n"
    "I am happy to relocate for the role."
)
COVER_BODY = COVER_P1 + "\n\n" + COVER_P2 + "\n\n" + COVER_P3
COVER = "Dear Ms Hofer,\n\n" + COVER_BODY + "\n\nKind regards,\nTheo Brandner"

# The case that surfaced the original ticket: two lines, each a prefix plus an email.
TICKETS = (
    "Ticket 4711 wren.castellan@example.net\n"
    "Ticket 4712 lise.adler@example.net"
)

ITEMS = {
    "address": ADDRESS,
    "signature": SIGNATURE,
    "resume": RESUME,
    "order": ORDER,
    "bio": BIO,
    "tickets": TICKETS,
    "cover": COVER,
}

# --------------------------------------------------------------------------------------------------------------
# Forms (Target surroundings). Surrounding text is what an accessibility read of the page would show near the
# field: headings, labels, hints. It never contains the item's values.
# --------------------------------------------------------------------------------------------------------------

FORMS = {
    "shop_de": {
        "window_title": "Kundenkonto anlegen – Keramikhaus Online",
        "surrounding_text": (
            "Keramikhaus Online\nKundenkonto anlegen\n"
            "Mit einem Kundenkonto bestellen Sie schneller, sehen Ihre Bestellungen und verwalten Ihre Adressen.\n"
            "Rechnungsadresse\nVorname *\nNachname *\nStraße *\nHausnummer *\n"
            "Adresszusatz (Stiege, Stock, Tür)\nPLZ *\nOrt *\nLand *\nBitte wählen\n"
            "Kontakt\nE-Mail *\nWir senden Ihnen die Bestellbestätigung an diese Adresse.\n"
            "Telefon\nFür Rückfragen des Paketdienstes.\nWebsite (optional)\nFax (optional)\n"
            "Zugang\nPasswort *\nMindestens 10 Zeichen, eine Zahl und ein Sonderzeichen.\n"
            "Ich habe die AGB und die Datenschutzerklärung gelesen.\nKonto erstellen\n"
            "Pflichtfelder sind mit * markiert."
        ),
        "sections": {
            "Rechnungsadresse": ["Vorname", "Nachname", "Straße", "Hausnummer", "Adresszusatz", "PLZ", "Ort", "Land"],
            "Kontakt": ["E-Mail", "Telefon", "Website", "Fax"],
            "Zugang": ["Passwort"],
        },
    },
    "parcel_de": {
        "window_title": "Paket versenden – Empfängeradresse | PaketPost",
        "surrounding_text": (
            "PaketPost\nPaket versenden\nSchritt 2 von 4: Empfänger\n"
            "Empfängeradresse\nName *\nStraße und Hausnummer *\nz. B. Musterweg 12\n"
            "PLZ *\nOrt *\nLand\nÖsterreich\n"
            "Die Adresse wird vor dem Versand automatisch geprüft. Postfächer sind nur für Päckchen möglich.\n"
            "Zustellhinweis (optional)\nz. B. beim Nachbarn abgeben\n"
            "Zurück\nWeiter zur Paketgröße"
        ),
        "sections": {"Empfängeradresse": ["Name", "Straße und Hausnummer", "PLZ", "Ort", "Land"]},
    },
    "crm_en": {
        "window_title": "New contact – Northwind CRM",
        "surrounding_text": (
            "Northwind CRM\nContacts / New contact\nCreate a contact from an email signature or business card.\n"
            "Person\nFirst name *\nLast name *\nJob title\nCompany\n"
            "Reach\nEmail *\nPhone\nMobile\nFax\nWebsite\n"
            "Billing\nIBAN\nUsed only for refunds and supplier payouts. We never charge this account.\n"
            "Tags\nAdd tag\nOwner\nAssign to me\nCancel\nSave contact"
        ),
        "sections": {
            "Person": ["First name", "Last name", "Job title", "Company"],
            "Reach": ["Email", "Phone", "Mobile", "Fax", "Website"],
            "Billing": ["IBAN"],
        },
    },
    "jobs_en": {
        "window_title": "Apply: Senior Data Engineer – Talentgrid",
        "surrounding_text": (
            "Talentgrid\nSenior Data Engineer · Remote (EU)\nApply for this job\n"
            "Personal details\nFull name *\nDate of birth\nDD Month YYYY\nPlace of birth\nNationality\n"
            "Country of residence\nLinkedIn URL\n"
            "About you\nTell the hiring team about yourself in a few sentences (max. 600 characters).\n"
            "Upload CV (PDF, max. 5 MB)\nBy applying you agree to our privacy notice.\nSubmit application"
        ),
        "sections": {
            "Personal details": ["Full name", "Date of birth", "Place of birth", "Nationality", "Country of residence",
                                 "LinkedIn URL"],
            "About you": ["About"],
        },
    },
    "returns_en": {
        "window_title": "Start a return – Hollow Oak Outfitters",
        "surrounding_text": (
            "Hollow Oak Outfitters\nHelp centre / Returns\nStart a return\n"
            "Find your order\nOrder number *\nYou find it in your confirmation email.\nEmail used for the order *\n"
            "Where should we pick it up?\nRecipient name\nStreet\nPostal code\nCity\n"
            "Refund\nAmount paid\nCoupon code (if any)\nShipment\nTracking number of the original parcel\n"
            "Returns are free within 30 days. Refunds go to the original payment method.\nContinue"
        ),
        "sections": {
            "Find your order": ["Order number", "Email"],
            "Where should we pick it up?": ["Recipient name", "Street", "Postal code", "City"],
            "Refund": ["Amount", "Coupon code"],
            "Shipment": ["Tracking number"],
        },
    },
    "market_en": {
        "window_title": "Seller profile – Kilnmarket",
        "surrounding_text": (
            "Kilnmarket\nSeller settings\nYour public profile\nBuyers see this on your shop page.\n"
            "Profile\nShop name\nInstagram handle\n@yourname\nCity\nBirth year\nOnly used to verify you are 18+.\n"
            "Bio\nA few sentences about you and your work. Line breaks are kept.\n"
            "Contact\nPhone\nShown only to buyers after a purchase.\nSave changes"
        ),
        "sections": {
            "Profile": ["Shop name", "Handle", "City", "Birth year", "Bio"],
            "Contact": ["Phone"],
        },
    },
    "helpdesk_en": {
        "window_title": "Reply to customer – Supportly",
        "surrounding_text": (
            "Supportly\nInbox / Escalations\nForward ticket to customer\n"
            "Choose who receives this ticket. Internal notes stay hidden; only the public thread is forwarded.\n"
            "Recipient\nEmail *\nThe customer receives a copy of the ticket thread.\nCC\n"
            "Separate several addresses with a comma.\n"
            "Subject\nRe: your enquiry\nMessage\nWrite a short note to go above the forwarded thread.\n"
            "Priority\nNormal\nCancel\nSend"
        ),
        "sections": {"Recipient": ["Email", "CC", "Subject"]},
    },
    "portal_en": {
        "window_title": "Edit profile – CareerHarbor",
        "surrounding_text": (
            "CareerHarbor\nMy profile\nRecruiters search profiles by headline, summary and skills.\n"
            "Basics\nFull name\nHeadline\ne.g. Backend engineer · Python · Kafka\n"
            "Profile summary\nDescribe your experience and what you are looking for. 2–4 sentences work best.\n"
            "Skills\nAdd up to 15 skills\nVisibility\nVisible to recruiters\nSave profile"
        ),
        "sections": {"Basics": ["Full name", "Headline", "Profile summary", "Skills"]},
    },
    "speaker_en": {
        "window_title": "Call for speakers – DataCraft Vienna 2027",
        "surrounding_text": (
            "DataCraft Vienna 2027\nCall for speakers closes 15 January\nSubmit a talk\n"
            "About the speaker\nSpeaker name\nCompany\nBiography\n"
            "Printed in the programme. Third person reads best, around 80 words.\n"
            "About the talk\nTalk title\nAbstract\nLevel\nBeginner\nIntermediate\nAdvanced\n"
            "Travel support needed\nWe cover travel within Europe for accepted speakers.\nSubmit proposal"
        ),
        "sections": {
            "About the speaker": ["Speaker name", "Company", "Biography"],
            "About the talk": ["Talk title", "Abstract", "Level"],
        },
    },
    "freelance_en": {
        "window_title": "Your listing – Freelancehub",
        "surrounding_text": (
            "Freelancehub\nDashboard / Your listing\nClients see your listing in search results.\n"
            "Listing\nDisplay name\nTitle\nDescription\nWhat do you do, for whom, and how do you work?\n"
            "Hourly rate (EUR)\nAvailability\nFull time\nPart time\nSkills\n"
            "Listings with a clear description get three times more enquiries. Contact details are hidden until "
            "a client books you.\nPublish listing"
        ),
        "sections": {"Listing": ["Display name", "Title", "Description", "Hourly rate", "Skills"]},
    },
    "community_en": {
        "window_title": "Edit your profile – Makers Guild Forum",
        "surrounding_text": (
            "Makers Guild Forum\nAccount settings\nPublic profile\nOther members see this next to your posts.\n"
            "Username\nLocation\nAbout me\nMarkdown is supported.\nSignature\n"
            "Shown under every post, max. 2 lines.\nAvatar\nUpload image\n"
            "Be kind. Profiles that advertise without taking part in discussions may be hidden by moderators.\nSave"
        ),
        "sections": {"Public profile": ["Username", "Location", "About me", "Signature"]},
    },
    "zine_en": {
        "window_title": "Contributor details – Clay & Kiln Quarterly",
        "surrounding_text": (
            "Clay & Kiln Quarterly\nContributor details for issue 14\n"
            "We print your name and a short bio under your article.\n"
            "Contributor\nName as printed\nShort bio\nOne or two sentences, max. 280 characters.\n"
            "Website or social link\nPayment\nFee is paid after publication. "
            "We send the proof of your article two weeks before print.\nSend details"
        ),
        "sections": {"Contributor": ["Name as printed", "Short bio", "Website or social link"]},
    },
    "apply_en": {
        "window_title": "Application – Junior Landscape Architect – Grünraum Studio",
        "surrounding_text": (
            "Grünraum Studio\nJunior Landscape Architect (Salzburg)\nYour application\n"
            "Applicant\nName *\nEmail *\n"
            "Letter\nCover letter *\nPaste your cover letter here.\n"
            "Motivation\nWhy Grünraum? (max. 500 characters)\n"
            "Availability\nEarliest start date and interview availability\n"
            "Notes\nAnything else you want us to know? Links, questions, remarks.\n"
            "Portfolio (PDF)\nSubmit application"
        ),
        "sections": {
            "Applicant": ["Name", "Email"],
            "Letter": ["Cover letter", "Motivation", "Availability", "Notes"],
        },
    },
}


def _cell(cid, form, section, field, expected, accept=(), borderline=None, placeholder=None, label=None):
    labels = FORMS[form]["sections"][section]
    siblings = [name for sec in FORMS[form]["sections"].values() for name in sec if name != field]
    return {
        "id": cid,
        "form": form,
        "section": section,
        "field_label": label or field,
        "siblings": siblings,
        "placeholder": placeholder,
        "expected": expected,
        "accept": list(accept),
        "borderline": borderline,
        "_labels": labels,
    }


CELLS = {
    "address": [
        _cell("A01_vorname", "shop_de", "Rechnungsadresse", "Vorname", "Mira"),
        _cell("A02_nachname", "shop_de", "Rechnungsadresse", "Nachname", "Holzner"),
        _cell("A03_strasse", "shop_de", "Rechnungsadresse", "Straße", "Prankergasse",
              borderline="Straße next to a separate Hausnummer field: street name only; `Prankergasse 77` is the "
                         "combined form"),
        _cell("A04_hausnummer", "shop_de", "Rechnungsadresse", "Hausnummer", "77"),
        _cell("A05_adresszusatz", "shop_de", "Rechnungsadresse", "Adresszusatz", "Top 11",
              placeholder="Stiege, Stock, Tür"),
        _cell("A06_plz", "shop_de", "Rechnungsadresse", "PLZ", "8020"),
        _cell("A07_ort", "shop_de", "Rechnungsadresse", "Ort", "Graz"),
        _cell("A08_land", "shop_de", "Rechnungsadresse", "Land", "Österreich"),
        _cell("A09_email", "shop_de", "Kontakt", "E-Mail", "mira.holzner@example.org"),
        _cell("A10_website", "shop_de", "Kontakt", "Website", "https://www.miraholzner.example"),
        _cell("A11_telefon", "shop_de", "Kontakt", "Telefon", "06608405534"),
        _cell("A12_strasse_hnr", "parcel_de", "Empfängeradresse", "Straße und Hausnummer", "Prankergasse 77",
              placeholder="z. B. Musterweg 12"),
        _cell("A13_passwort_NEG", "shop_de", "Zugang", "Passwort", None),
        _cell("A14_fax_NEG", "shop_de", "Kontakt", "Fax", None),
    ],
    "signature": [
        _cell("S01_first_name", "crm_en", "Person", "First name", "Jonas"),
        _cell("S02_last_name", "crm_en", "Person", "Last name", "Prell"),
        _cell("S03_job_title", "crm_en", "Person", "Job title", "Product Lead"),
        _cell("S04_phone", "crm_en", "Reach", "Phone", "+43 1 2345678"),
        _cell("S05_mobile", "crm_en", "Reach", "Mobile", "+43 660 1112233"),
        _cell("S06_email", "crm_en", "Reach", "Email", "jonas.prell@example.com"),
        _cell("S07_website", "crm_en", "Reach", "Website", "www.prell.example"),
        _cell("S08_iban", "crm_en", "Billing", "IBAN", "AT61 1904 3002 3457 3201",
              borderline="`IBAN AT61 …` (the whole line) keeps the label; expected is the number only"),
        _cell("S09_fax_NEG", "crm_en", "Reach", "Fax", None),
    ],
    "resume": [
        _cell("R01_full_name", "jobs_en", "Personal details", "Full name", "Anna Reisinger"),
        _cell("R02_birthdate", "jobs_en", "Personal details", "Date of birth", "14 March 1991",
              placeholder="DD Month YYYY"),
        _cell("R03_birthplace", "jobs_en", "Personal details", "Place of birth", "Linz"),
        _cell("R04_nationality", "jobs_en", "Personal details", "Nationality", "Austrian"),
        _cell("R05_about", "jobs_en", "About you", "About", RESUME_ABOUT,
              placeholder="Tell the hiring team about yourself in a few sentences"),
        _cell("R06_country", "jobs_en", "Personal details", "Country of residence", "Austria",
              borderline="only `Austria` in the current job line and `Austrian` as nationality point to a country"),
        _cell("R07_linkedin_NEG", "jobs_en", "Personal details", "LinkedIn URL", None),
        _cell("R08_summary", "portal_en", "Basics", "Profile summary", RESUME_ABOUT),
        _cell("R09_biography", "speaker_en", "About the speaker", "Biography", RESUME_ABOUT, accept=[RESUME],
              borderline="About paragraph or the whole item — record which (section/whole item/paragraph)"),
        _cell("R10_description", "freelance_en", "Listing", "Description", RESUME_ABOUT,
              borderline="a freelance listing description; the About paragraph is the closest excerpt"),
    ],
    "order": [
        _cell("O01_email", "returns_en", "Find your order", "Email", "wren.castellan@example.net",
              label="Email used for the order"),
        _cell("O02_order_number", "returns_en", "Find your order", "Order number", "4711"),
        _cell("O03_recipient", "returns_en", "Where should we pick it up?", "Recipient name", "Lise Adler"),
        _cell("O04_street", "returns_en", "Where should we pick it up?", "Street", "Hauptstr. 5"),
        _cell("O05_postal_code", "returns_en", "Where should we pick it up?", "Postal code", "4020"),
        _cell("O06_city", "returns_en", "Where should we pick it up?", "City", "Linz"),
        _cell("O07_amount", "returns_en", "Refund", "Amount", "129,90", accept=["EUR 129,90"],
              label="Amount paid",
              borderline="`129,90` or `EUR 129,90` — both counted as hit, which one Jev picks is noted"),
        _cell("O08_tracking", "returns_en", "Shipment", "Tracking number", "00340434161234567890",
              label="Tracking number of the original parcel"),
        _cell("O09_coupon_NEG", "returns_en", "Refund", "Coupon code", None, label="Coupon code (if any)"),
    ],
    "bio": [
        _cell("B01_handle", "market_en", "Profile", "Handle", "@mira_h", label="Instagram handle",
              placeholder="@yourname"),
        _cell("B02_city", "market_en", "Profile", "City", "Innsbruck"),
        _cell("B03_bio", "market_en", "Profile", "Bio", BIO_P1, accept=[BIO],
              placeholder="A few sentences about you and your work",
              borderline="paragraph 1 or both paragraphs — both counted as hit, which one Jev picks is noted"),
        _cell("B04_birth_year", "market_en", "Profile", "Birth year", "1994"),
        _cell("B05_phone_NEG", "market_en", "Contact", "Phone", None),
        _cell("B06_biography", "speaker_en", "About the speaker", "Biography", BIO_P1, accept=[BIO],
              borderline="paragraph 1 or both paragraphs — record which"),
        _cell("B07_about_me", "community_en", "Public profile", "About me", BIO_P1, accept=[BIO],
              borderline="paragraph 1 or both paragraphs — record which"),
        _cell("B08_short_bio", "zine_en", "Contributor", "Short bio", BIO_P1, accept=[BIO],
              borderline="paragraph 1 or both paragraphs — record which (280-char hint on the page)"),
    ],
    "tickets": [
        _cell("T01_email_two_lines", "helpdesk_en", "Recipient", "Email", "wren.castellan@example.net",
              accept=["lise.adler@example.net"],
              borderline="two prefix+email lines (the case that surfaced the ticket): either email is a hit; "
                         "the same-type chooser should open with both"),
    ],
    "cover": [
        _cell("C01_cover_letter", "apply_en", "Letter", "Cover letter", COVER_BODY, accept=[COVER],
              borderline="the three paragraphs are not a structural Candidate; whole item (with greeting and "
                         "sign-off) counted as hit too — record what Jev takes"),
        _cell("C02_motivation", "apply_en", "Letter", "Motivation", COVER_P2),
        _cell("C03_availability", "apply_en", "Letter", "Availability", COVER_P3),
        _cell("C04_name", "apply_en", "Applicant", "Name", "Theo Brandner"),
        _cell("C05_notes_freetext", "apply_en", "Letter", "Notes", COVER,
              borderline="free-text-like field: expect free_text >= 0.8 (whole item pasted); record it"),
    ],
}


def target_context(cell):
    """Production `target_context` for a cell; absent keys omitted."""
    form = FORMS[cell["form"]]
    context = {
        "app_name": "Google Chrome",
        "window_title": form["window_title"],
        "field_label": cell["field_label"],
        "placeholder": cell["placeholder"],
        "section_heading": cell["section"],
        "sibling_field_labels": cell["siblings"],
        "surrounding_text": form["surrounding_text"],
    }
    return {key: value for key, value in context.items() if value not in (None, "", [])}


def all_cells():
    for item_id, cells in CELLS.items():
        for cell in cells:
            yield item_id, cell


def _self_check():
    for item_id, cell in all_cells():
        item = ITEMS[item_id]
        for text in [cell["expected"]] + cell["accept"]:
            if text is not None:
                assert text in item, (cell["id"], text)
        surrounding = FORMS[cell["form"]]["surrounding_text"]
        assert 300 <= len(surrounding) <= 1200, (cell["form"], len(surrounding))
        if cell["expected"] is not None:
            assert cell["expected"] not in surrounding or len(cell["expected"]) < 5, (cell["id"], "leak")



for _, _c in all_cells():
    _c["expect_free_text"] = _c["id"].endswith("_freetext")



_self_check()
