"""Synthetic Targets for the free-text spike. All names and data are invented.

Each situation is a Target Context dict with the production field names
(`docs/design/jev-gateway.md`) plus `app_name` and `window_title`. Keys whose
value is missing or empty are omitted by `run.build_state`, as production does.
"""

SOURCE_DOCUMENT = """Marlene Oberholzer
marlene.oberholzer@example.org
+41 79 555 01 23
Lindenweg 14
8006 Zürich
Product designer with nine years of experience in mobile banking and public-sector services. Led the redesign of a payments app used by 400,000 people and ran weekly usability sessions with older customers. Looking for a senior role in a small, research-driven team."""

CHATGPT_TRANSCRIPT = """Help me tighten my cover letter intro
You said:
I'm applying for a senior product designer role at a small fintech in Basel. Can you help me write a short intro paragraph for my cover letter? I'll paste my CV summary below so you have the facts.
ChatGPT said:
Of course! Paste your CV summary or the key points you want the intro to highlight — years of experience, the most relevant project, and what kind of team you're looking for. I'll draft two or three options in different tones (warm, direct, and understated) so you can pick one.
You said:
Great, one sec, copying it from my résumé.
ChatGPT can make mistakes. Check important info."""

TERMINAL_TAIL = """~/work/applications on main
$ ls
cover-letter.md  cv-2026.pdf  notes.txt  portfolio-links.txt
$ git status
On branch main
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
	modified:   notes.txt

no changes added to commit (use "git add" and/or "git commit -a")
$ cat notes.txt
- follow up with the Basel fintech on Friday
- ask Jonas about the portfolio review
$ echo "
~/work/applications on main
$ """

SLACK_CHATTER = """#general
Acme workspace
Tobias Renner  9:12 AM
Morning all! Reminder that the design review moved to 14:00 today.
Priya Kandasamy  9:20 AM
Thanks. Also, HR asked everyone who is referring candidates for the senior designer opening to post the contact details here so they can reach out this week.
Tobias Renner  9:21 AM
I know someone great, will share in a bit.
Lukas Fehr  9:34 AM
:tada: the new onboarding flow shipped to 10% of users.
Priya Kandasamy  9:41 AM
Nice! @channel please drop referrals in this thread before Thursday."""

WHATSAPP_LINES = """Jonas Weber
online
Hey, are you still looking for designers for your team?  10:02
Yes! Do you know someone?  10:05
My old colleague from the bank project, she's brilliant  10:05
Send me her details, I'll forward them to our recruiter  10:06
Sure, give me a sec  10:07
Also, are you coming to Lea's birthday on Saturday?  10:08
Probably! What time does it start?  10:11
Around 7, at the place by the lake  10:11
Perfect, I'll bring the cake  10:12"""

TEXTEDIT_DOC = """Referral notes — senior designer opening

Why I'm referring this person:
We worked together for three years on the payments app. She ran the usability sessions with older customers and was the person everyone went to when a flow felt confusing. She is calm under deadline pressure and writes clear specs.

Her profile, as she sent it to me:
"""

MARKDOWN_FILE = """# Candidate pipeline

## Open roles
- Senior product designer (Zürich or remote)
- Frontend engineer (Basel)

## Referrals received
### From Jonas
- Strong visual background, portfolio link pending

### From Priya
- Research-heavy, worked on public-sector services

## Next steps
- [ ] Schedule first calls
- [ ] Share shortlist with hiring manager

## Raw profiles
"""

ARTICLE_AND_COMMENTS = """How we halved onboarding drop-off in a banking app
By Nora Lindqvist · 6 min read
When we started, 41% of new customers abandoned signup before verifying their identity. We interviewed 30 of them. The most common reason was not the ID check itself but not knowing how long it would take. We added a progress indicator, an estimated time, and a way to finish later. Drop-off fell to 19% within two months.
The second change was language. We replaced "KYC verification" with "Confirm it's you" and moved the legal text behind a link. Older customers in particular told us the new wording felt less like an interrogation.
Comments (3)
Samir Haddad · 2 days ago
Great write-up. Did you test the "finish later" option with users who switch devices?
Nora Lindqvist · 2 days ago
Yes — about 12% finished on a different device. We send a magic link.
Elena Rossi · 1 day ago
We are hiring for exactly this kind of work, happy to connect with anyone who has done something similar.
Add a comment
Post"""

SIGNUP_PAGE = """Sign up – Example
Create your account
Start your free 30-day trial. No credit card required.
Full name
Email address
We'll send a confirmation link to this address.
Password
At least 8 characters, one number.
I agree to the Terms of Service and Privacy Policy.
Create account
Already have an account? Log in"""

CHECKOUT_PAGE = """Checkout – Nordic Paper Co.
1 Cart  2 Shipping  3 Payment
Contact
marlene.o@example.net
Shipping address
Country/Region
Switzerland
First name
Last name
Street
Apartment, suite, etc. (optional)
City
Postcode
Shipping method will be calculated in the next step.
Order summary
Linen notebook A5 × 2   CHF 38.00
Subtotal   CHF 38.00
Continue to shipping"""

RESULTS_PAGE = """Jobs board – Results
Search
Filters: Location · Remote · Seniority · Salary
142 results for "product designer"
Senior Product Designer — Helvetia Pay, Basel · Hybrid · Posted 2 days ago
Lead UX Designer — Stadtwerke Digital, Zürich · On-site · Posted 5 days ago
Product Designer, Mobile — Alpenbank, Remote (CH) · Posted 1 week ago
Service Designer — Canton of Aargau, Aarau · Posted 1 week ago
Save this search to get email alerts.
Page 1 of 15  Next"""

CONTACTS_CARD = """New Contact
First name  Last name
Company
mobile
home
work
add phone
home  email
add email
add address
note
Cancel  Done
All Contacts
Andrea Keller
Beat Zimmermann
Carla Meier
Daniel Brunner
Eva Schmid
Fabian Graf
Gabriela Huber
Hannes Vogel
Iris Baumann
Jana Frei
Karin Steiner"""

FINDER_RENAME = """applications
Name  Date Modified  Size  Kind
cover-letter.md  Today at 09:14  4 KB  Markdown
cv-2026.pdf  Yesterday at 18:02  212 KB  PDF document
untitled folder  Today at 10:21  --  Folder
notes.txt  Today at 09:50  1 KB  Plain Text"""


# (id, group, label, target_context). group: "free" (expect free_text >= 0.8)
# or "value" (expect free_text <= 0.2). "borderline" in the note column only.
SITUATIONS = [
    ("S01a_chatgpt_placeholder", "free", "ChatGPT composer, placeholder", {
        "app_name": "ChatGPT",
        "window_title": "Help me tighten my cover letter intro",
        "placeholder": "Ask anything",
        "surrounding_text": CHATGPT_TRANSCRIPT,
    }),
    ("S01b_chatgpt_no_placeholder", "free", "ChatGPT composer, no placeholder", {
        "app_name": "ChatGPT",
        "window_title": "Help me tighten my cover letter intro",
        "surrounding_text": CHATGPT_TRANSCRIPT,
    }),
    ("S02_terminal", "free", "Ghostty shell prompt", {
        "app_name": "Ghostty",
        "window_title": "~/work/applications",
        "surrounding_text": TERMINAL_TAIL,
    }),
    ("S03_slack", "free", "Slack message box", {
        "app_name": "Slack",
        "window_title": "#general – Acme",
        "placeholder": "Message #general",
        "surrounding_text": SLACK_CHATTER,
    }),
    ("S04_whatsapp", "free", "WhatsApp composer", {
        "app_name": "WhatsApp",
        "window_title": "Jonas Weber",
        "placeholder": "Type a message",
        "surrounding_text": WHATSAPP_LINES,
    }),
    ("S05_textedit", "free", "TextEdit document", {
        "app_name": "TextEdit",
        "window_title": "Untitled 3",
        "surrounding_text": TEXTEDIT_DOC,
    }),
    ("S06_code_editor", "free", "VS Code markdown file", {
        "app_name": "Code",
        "window_title": "notes.md — project",
        "surrounding_text": MARKDOWN_FILE,
    }),
    ("S07_comment_box", "free", "Web comment box (borderline)", {
        "app_name": "Google Chrome",
        "window_title": "How we halved onboarding drop-off in a banking app",
        "field_label": "Add a comment",
        "surrounding_text": ARTICLE_AND_COMMENTS,
    }),
    ("S08_email_field", "value", "Sign-up email field", {
        "app_name": "Google Chrome",
        "window_title": "Sign up – Example",
        "field_label": "Email address",
        "sibling_field_labels": ["Full name", "Password"],
        "surrounding_text": SIGNUP_PAGE,
    }),
    ("S09_street_field", "value", "Shipping address street", {
        "app_name": "Google Chrome",
        "window_title": "Checkout – Nordic Paper Co.",
        "field_label": "Street",
        "section_heading": "Shipping address",
        "sibling_field_labels": ["City", "Postcode"],
        "surrounding_text": CHECKOUT_PAGE,
    }),
    ("S10_search_box", "value", "Search box (borderline)", {
        "app_name": "Google Chrome",
        "window_title": "Jobs board – Results",
        "placeholder": "Search",
        "surrounding_text": RESULTS_PAGE,
    }),
    ("S11_contacts_phone", "value", "Contacts mobile field", {
        "app_name": "Contacts",
        "window_title": "New Contact",
        "field_label": "mobile",
        "sibling_field_labels": ["home", "work"],
        "surrounding_text": CONTACTS_CARD,
    }),
    ("S12_finder_rename", "value", "Finder rename (single-line title)", {
        "app_name": "Finder",
        "window_title": "applications",
        "field_label": "Name",
        "surrounding_text": FINDER_RENAME,
    }),
]

BY_ID = {s[0]: s for s in SITUATIONS}
