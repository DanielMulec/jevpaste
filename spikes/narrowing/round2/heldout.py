"""Held-out cells for Narrowing round 2 (ticket #49). All names, addresses and data are invented.

Written and committed BEFORE any round-2 Jev call. No round-1 run has seen these texts or target contexts. They are
scored separately and are NEVER used for tuning (exploration runs only on round-1 cells).

Same cell shape as spikes/narrowing/cells.py: id, group ("heldout"), item (the copy), context (production-shaped
`target_context`: app_name, window_title, field_label, placeholder, section_heading, sibling_field_labels,
surrounding_text; absent keys omitted), expected, accept, outcome ("paste" | "nothing" | "ask"), borderline.
Extra key `klass` = which round-1 failure class (or "positive" / "trap") the cell probes. Surrounding text never
contains the expected value. Expected values are used only for scoring and never sent to Jev.

Failure classes (round 1):
  1 containment   the exact value sits inside a long piece; Jev kept the big piece
  2 whole_vs_part chat box / comment textarea should get the whole copy; a description field the paragraph
  3 url_chat      a lone URL into a chat composer should be pasted, not "nothing fits"
  4 multi_email   several emails of one person, nothing in the place says which -> "ask the user"
  5 street_line   street + house number field: the street line, not street + the next line
"""


def _cell(cid, klass, item, context, expected, accept=(), outcome="paste", borderline=None):
    context = {k: v for k, v in context.items() if v not in (None, "", [])}
    return {"id": cid, "group": "heldout", "klass": klass, "item": item, "context": context, "expected": expected,
            "accept": list(accept), "outcome": outcome, "borderline": borderline}


def _ctx(app, title, surrounding, field=None, placeholder=None, section=None, siblings=()):
    return {"app_name": app, "window_title": title, "field_label": field, "placeholder": placeholder,
            "section_heading": section, "sibling_field_labels": list(siblings), "surrounding_text": surrounding}


# ================================================================================================= copies
RENTAL_P1 = (
    "I am writing about the two-room flat on Rennweg that you advertised last week. I work as a physiotherapist "
    "at a clinic in Hötting and have lived here for six years."
)
RENTAL_P2 = (
    "I am looking for a quiet place close to my work and would like to move in on 1 March 2027. I do not smoke, "
    "have no pets, and can send references from my current landlord."
)
RENTAL_P3 = "I would be glad to view the flat on any weekday after 17:00."
RENTAL = ("Dear Mr Aigner,\n\n" + RENTAL_P1 + "\n\n" + RENTAL_P2 + "\n\n" + RENTAL_P3
          + "\n\nBest regards,\nKatrin Lechner")

MARKET = (
    "Spring Pottery Market 2027\n"
    "Our spring market takes place on Saturday 17 April 2027 in the Kulturhaus in Villach, from 10:00 to 17:00. "
    "Around forty makers from Carinthia and Friuli sell tableware, planters and sculpture. Entry is free, and "
    "children's wheel sessions run every hour."
)

COMPANY_ABOUT = (
    "Family carpentry workshop in its third generation, building timber frames, roof structures and staircases "
    "for private homes across the Inn valley. Twelve carpenters, two apprentices, and our own sawmill for local "
    "larch and spruce."
)
COMPANY = (
    "Brunner Holzbau GmbH\n"
    "office@brunner-holzbau.example\n"
    "+43 5223 41877\n"
    "Gewerbepark 4\n"
    "6060 Hall in Tirol\n"
    + COMPANY_ABOUT
)

URL_RUNBOOK = "https://docs.northbeam.example/runbooks/deploy-rollback?env=staging#step-4"
URL_SHOP = "https://www.kofler-keramik.example/shop/teller-set-6?farbe=salbei"

THREE_EMAILS_A = (
    "Dr. Elif Sommer\n"
    "Senior Researcher, Alpine Climate Lab\n"
    "elif.sommer@climatelab.example\n"
    "e.sommer@uni-graz.example\n"
    "elif.sommer.home@example.net\n"
    "+43 316 555 2041"
)
THREE_EMAILS_B = (
    "Nikolai Varga\n"
    "Illustrator & motion designer\n"
    "nikolai@vargastudio.example\n"
    "n.varga@freelance-mail.example\n"
    "nikolai.varga.art@example.org\n"
    "Vienna, Austria\n"
    "\n"
    "Selected clients\n"
    "Donau Verlag, Kleinkunst Festival, Radio Mur"
)
TWO_EMAILS = (
    "Rosa Hainz\n"
    "Head of Events, Stadtsaal Wels\n"
    "rosa.hainz@stadtsaal-wels.example\n"
    "rosa.hainz@mailbox.example\n"
    "Direct line +43 7242 3301 12"
)

ADDRESS_EN = (
    "Florian Mair\n"
    "Kirchgasse 9\n"
    "Hof 2, Tür 4\n"
    "6020 Innsbruck\n"
    "Austria"
)
ADDRESS_DE = (
    "Sabine Gruber\n"
    "Leopoldstraße 41\n"
    "2. Stock, Tür 12\n"
    "4020 Linz"
)

INVOICE = (
    "Rechnung Nr. 2027-0142\n"
    "Brunner Holzbau GmbH\n"
    "Betrag: EUR 1.840,00\n"
    "Zahlbar bis 28.02.2027\n"
    "IBAN AT48 3600 0000 0412 7788\n"
    "BIC RZTIAT22"
)

SIGNATURE = (
    "Best,\n"
    "Tobias Winkler\n"
    "Head of Logistics · Almtal Getränke\n"
    "Office +43 7615 2210 40\n"
    "Mobile +43 664 918 2735\n"
    "tobias.winkler@almtal.example"
)

# ================================================================================================ places
FLAT_FORM = (
    "Homefinder\nFlats / Innsbruck / Rennweg, 2 rooms, 54 m²\nApply for this flat\n"
    "The landlord sees your application together with your profile.\n"
    "Applicant\nFull name *\nEmail *\nPhone\n"
    "Your move\nDesired move-in date *\nNumber of people moving in\nPets\n"
    "Message\nWrite a short note to the landlord.\n"
    "Attach proof of income (optional)\nSend application"
)
FLAT_SECTIONS = {"Applicant": ["Full name", "Email", "Phone"],
                 "Your move": ["Desired move-in date", "Number of people moving in", "Pets"]}

EVENT_FORM = (
    "Kärnten Kalender\nSubmit an event\nListings are checked by our editors within two days.\n"
    "Event\nEvent name *\nStart date *\nStart time\nEnd time\n"
    "Location\nVenue\nCity *\nDescription\nWhat will visitors find? Up to 600 characters.\n"
    "Organiser\nOrganiser email *\nWebsite\nSubmit for review"
)

ISSUE_THREAD = (
    "buildops / site-b\nIssues\nVendor onboarding: timber work for the site B annex #214\nOpen\n"
    "Hannah Ortner opened this issue 3 days ago\n"
    "We still need a carpentry vendor for the roof and the stair core. Please drop contact details of anyone "
    "you have worked with and a line on what they do.\n"
    "Moritz Kainz commented 2 days ago\nI asked around at the Schwaz site, will post once I hear back.\n"
    "Hannah Ortner commented yesterday\nDeadline for the shortlist is Friday.\n"
    "Add a comment\nWrite\nPreview\nMarkdown is supported\nComment\nClose issue"
)

MESSAGES_CHAT = (
    "Petra Kofler\niMessage\nToday 18:42\n"
    "Our roof guy retired, do you know a good carpentry firm near Hall?\n"
    "Yes, the ones who did our stairs were great\n"
    "Can you send me their details? Then I'll call them tomorrow\n"
    "Sure, one sec, copying it from their website\n"
    "Delivered"
)

LISTING_FORM = (
    "Handwerk Tirol\nBusiness directory\nList your business\n"
    "Customers find you by trade, town and description.\n"
    "Business\nCompany name *\nEmail *\nPhone\nStreet\nPostcode\nTown\n"
    "About the business\nCompany description *\nWhat do you do, for whom, and how? 2–4 sentences.\n"
    "Trade category\nPublish listing"
)

SLACK_CHANNEL = (
    "#platform\nNorthbeam\n"
    "Jakob Moser  10:14\nStaging deploy is stuck again after the migration, rolling back.\n"
    "Lea Brandl  10:16\nWhich step of the rollback are you on? I don't want to redo the cache flush.\n"
    "Jakob Moser  10:17\nThe one after draining the workers. Let me grab the link to that section.\n"
    "Lea Brandl  10:18\nThanks, I'll follow along."
)

TEAMS_CHAT = (
    "Chat\nPetra Kofler\n"
    "Petra Kofler 09:02\nMorning! Did you find the plate set you mentioned for the office kitchen?\n"
    "You 09:05\nYes, the green one from that ceramics shop\n"
    "Petra Kofler 09:06\nSend it over, I'll put it in the order list for facilities today.\n"
    "Type a message"
)

WEBINAR_FORM = (
    "Klimadaten Forum\nAnmeldung – Webinar Klimadaten 2027\n"
    "Das Webinar findet am 12. Mai 2027 online statt. Die Teilnahme ist kostenlos.\n"
    "Teilnehmer\nVorname *\nNachname *\nOrganisation\nE-Mail-Adresse *\n"
    "An diese Adresse senden wir den Zugangslink und die Aufzeichnung.\n"
    "Ich möchte über künftige Veranstaltungen informiert werden.\nAnmelden"
)

FOLIO_FORM = (
    "Folio\nCreate your account\nShow your work to studios and art directors.\n"
    "Account\nDisplay name *\nEmail *\nWe send the sign-in link and client enquiries here.\n"
    "Password *\nAt least 10 characters.\nDiscipline\nLocation\n"
    "By creating an account you agree to the Terms.\nCreate account"
)

CATERING_FORM = (
    "Tafelwerk Catering\nRequest a quote\nTell us about your event and we will reply within one working day.\n"
    "Contact\nName *\nOrganisation\nEmail *\nPhone\n"
    "Event\nDate\nNumber of guests\nKind of event\nAnything else?\n"
    "We confirm every quote by email and hold the date for seven days.\nSend request"
)

CHECKOUT_EN = (
    "Bergsport Direct\nCheckout\n1 Bag  2 Shipping  3 Payment\n"
    "Shipping address\nFull name *\nAddress line 1 *\nAddress line 2\nPostcode *\nCity *\nCountry *\n"
    "Phone *\nThe courier calls this number if nobody is home.\n"
    "Delivery options are shown on the next step.\nOrder summary\nTrail running vest × 1   EUR 89.00\n"
    "Continue to delivery"
)
CHECKOUT_EN_LABELS = ["Full name", "Address line 1", "Address line 2", "Postcode", "City", "Country", "Phone"]

BOOKSHOP_DE = (
    "Bücherstube Online\nKasse\nLieferadresse\n"
    "Vorname *\nNachname *\nStraße und Hausnummer *\nPLZ *\nOrt *\n"
    "Lieferung innerhalb Österreichs versandkostenfrei ab 30 Euro.\n"
    "Bitte geben Sie eine Adresse an, an der Pakete tagsüber angenommen werden.\n"
    "Zahlungsart\nRechnung\nKreditkarte\nWeiter zur Zahlung"
)

BANKING_DE = (
    "Mein Banking\nNeue Überweisung\nVon Konto: Gehaltskonto\n"
    "Empfänger *\nIBAN *\nBIC (optional)\nBetrag *\nVerwendungszweck\nZahlungsreferenz\n"
    "Echtzeitüberweisung\nDie Überweisung wird nach Freigabe mit Ihrer App ausgeführt.\n"
    "Prüfen Sie Empfänger und IBAN vor der Freigabe. Eine Echtzeitüberweisung kann nicht widerrufen werden.\n"
    "Vorlage speichern\nWeiter"
)
BANKING_LABELS = ["Empfänger", "IBAN", "BIC", "Betrag", "Verwendungszweck", "Zahlungsreferenz"]

CRM_FORM = (
    "Almkontakt CRM\nContacts / New contact\n"
    "Person\nFirst name *\nLast name *\nJob title\nCompany\nBirthday\n"
    "Reach\nEmail *\nOffice phone\nMobile\n"
    "Notes\nOnly visible to your team.\nOwner\nAssign to me\nTags\nAdd tag\n"
    "Contacts with a mobile number receive delivery updates by SMS.\nCancel\nSave contact"
)
CRM_LABELS = ["First name", "Last name", "Job title", "Company", "Birthday", "Email", "Office phone", "Mobile"]


def _siblings(labels, field):
    return [label for label in labels if label != field]


FLAT_LABELS = [label for labels in FLAT_SECTIONS.values() for label in labels]

HELDOUT = [
    # ---------------------------------------------------------------- class 1: containment
    _cell("H01_flat_full_name", "containment", RENTAL,
          _ctx("Google Chrome", "Apply for this flat – Homefinder", FLAT_FORM, "Full name", section="Applicant",
               siblings=_siblings(FLAT_LABELS, "Full name")),
          "Katrin Lechner"),
    _cell("H02_flat_move_in", "containment", RENTAL,
          _ctx("Google Chrome", "Apply for this flat – Homefinder", FLAT_FORM, "Desired move-in date",
               placeholder="DD Month YYYY", section="Your move",
               siblings=_siblings(FLAT_LABELS, "Desired move-in date")),
          "1 March 2027"),
    _cell("H03_event_city", "containment", MARKET,
          _ctx("Google Chrome", "Submit an event – Kärnten Kalender", EVENT_FORM, "City", section="Location",
               siblings=["Event name", "Start date", "Start time", "End time", "Venue", "Description",
                         "Organiser email", "Website"]),
          "Villach"),
    # ---------------------------------------------------------------- class 2: everything vs a part
    _cell("H04_issue_comment", "whole_vs_part", COMPANY,
          _ctx("Google Chrome", "Vendor onboarding: timber work for the site B annex · Issue #214 · buildops/site-b",
               ISSUE_THREAD, "Add a comment", placeholder="Leave a comment"),
          COMPANY),
    _cell("H05_messages_composer", "whole_vs_part", COMPANY,
          _ctx("Messages", "Petra Kofler", MESSAGES_CHAT, placeholder="iMessage"),
          COMPANY),
    _cell("H06_company_description", "whole_vs_part", COMPANY,
          _ctx("Google Chrome", "List your business – Handwerk Tirol", LISTING_FORM, "Company description",
               placeholder="What do you do, for whom, and how?", section="About the business",
               siblings=["Company name", "Email", "Phone", "Street", "Postcode", "Town", "Trade category"]),
          COMPANY_ABOUT),
    # ---------------------------------------------------------------- class 3: lone URL into a chat composer
    _cell("H07_url_slack", "url_chat", URL_RUNBOOK,
          _ctx("Slack", "#platform – Northbeam", SLACK_CHANNEL, placeholder="Message #platform"),
          URL_RUNBOOK),
    _cell("H08_url_teams", "url_chat", URL_SHOP,
          _ctx("Microsoft Teams", "Chat | Petra Kofler | Microsoft Teams", TEAMS_CHAT, placeholder="Type a message"),
          URL_SHOP),
    # ---------------------------------------------------------------- class 4: several emails -> ask the user
    _cell("H09_three_emails_webinar", "multi_email", THREE_EMAILS_A,
          _ctx("Google Chrome", "Anmeldung – Webinar Klimadaten 2027", WEBINAR_FORM, "E-Mail-Adresse",
               section="Teilnehmer", siblings=["Vorname", "Nachname", "Organisation"]),
          None, accept=["elif.sommer@climatelab.example", "e.sommer@uni-graz.example",
                        "elif.sommer.home@example.net"], outcome="ask"),
    _cell("H10_three_emails_folio", "multi_email", THREE_EMAILS_B,
          _ctx("Google Chrome", "Create your account – Folio", FOLIO_FORM, "Email", section="Account",
               siblings=["Display name", "Password", "Discipline", "Location"]),
          None, accept=["nikolai@vargastudio.example", "n.varga@freelance-mail.example",
                        "nikolai.varga.art@example.org"], outcome="ask"),
    _cell("H11_two_emails_catering", "multi_email", TWO_EMAILS,
          _ctx("Google Chrome", "Request a quote – Tafelwerk Catering", CATERING_FORM, "Email", section="Contact",
               siblings=["Name", "Organisation", "Phone", "Date", "Number of guests", "Kind of event",
                         "Anything else?"]),
          None, accept=["rosa.hainz@stadtsaal-wels.example", "rosa.hainz@mailbox.example"], outcome="ask"),
    # ---------------------------------------------------------------- class 5: street line, not the next line
    _cell("H12_address_line_1", "street_line", ADDRESS_EN,
          _ctx("Google Chrome", "Checkout – Bergsport Direct", CHECKOUT_EN, "Address line 1",
               placeholder="Street and house number", section="Shipping address",
               siblings=_siblings(CHECKOUT_EN_LABELS, "Address line 1")),
          "Kirchgasse 9"),
    _cell("H13_strasse_hausnummer", "street_line", ADDRESS_DE,
          _ctx("Google Chrome", "Kasse – Bücherstube Online", BOOKSHOP_DE, "Straße und Hausnummer",
               section="Lieferadresse", siblings=["Vorname", "Nachname", "PLZ", "Ort"]),
          "Leopoldstraße 41"),
    # ---------------------------------------------------------------- ordinary positives
    _cell("H14_empfaenger", "positive", INVOICE,
          _ctx("Google Chrome", "Neue Überweisung – Mein Banking", BANKING_DE, "Empfänger",
               siblings=_siblings(BANKING_LABELS, "Empfänger")),
          "Brunner Holzbau GmbH"),
    _cell("H15_mobile", "positive", SIGNATURE,
          _ctx("Google Chrome", "New contact – Almkontakt CRM", CRM_FORM, "Mobile", section="Reach",
               siblings=_siblings(CRM_LABELS, "Mobile")),
          "+43 664 918 2735"),
    _cell("H16_postcode", "positive", ADDRESS_EN,
          _ctx("Google Chrome", "Checkout – Bergsport Direct", CHECKOUT_EN, "Postcode", section="Shipping address",
               siblings=_siblings(CHECKOUT_EN_LABELS, "Postcode")),
          "6020"),
    # ---------------------------------------------------------------- traps
    _cell("H17_birthday_NEG", "trap", SIGNATURE,
          _ctx("Google Chrome", "New contact – Almkontakt CRM", CRM_FORM, "Birthday", placeholder="DD.MM.YYYY",
               section="Person", siblings=_siblings(CRM_LABELS, "Birthday")),
          None, outcome="nothing"),
    _cell("H18_phone_NEG", "trap", ADDRESS_EN,
          _ctx("Google Chrome", "Checkout – Bergsport Direct", CHECKOUT_EN, "Phone", section="Shipping address",
               siblings=_siblings(CHECKOUT_EN_LABELS, "Phone")),
          None, outcome="nothing"),
]

BY_ID = {c["id"]: c for c in HELDOUT}


def _self_check():
    from collections import Counter
    assert len(HELDOUT) >= 12 and len(BY_ID) == len(HELDOUT)
    counts = Counter(c["klass"] for c in HELDOUT)
    for klass in ("containment", "whole_vs_part", "url_chat", "multi_email", "street_line", "positive", "trap"):
        assert counts[klass] >= 2, (klass, counts[klass])
    for c in HELDOUT:
        for text in ([c["expected"]] if c["expected"] else []) + c["accept"]:
            assert text in c["item"], (c["id"], text)
        surrounding = c["context"]["surrounding_text"]
        assert 250 <= len(surrounding) <= 1200, (c["id"], len(surrounding))
        if c["expected"] is not None and c["outcome"] == "paste":
            assert c["expected"] not in surrounding, (c["id"], "leak")
        for text in c["accept"]:
            assert text not in surrounding, (c["id"], "leak")


_self_check()

if __name__ == "__main__":
    for c in HELDOUT:
        shown = c["expected"] if c["outcome"] == "paste" else c["outcome"]
        print("%-28s %-14s -> %r" % (c["id"], c["klass"], (shown or "")[:60]))
