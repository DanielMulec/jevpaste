# Spike: does Jev reliably tell free-text places from value fields?

Throwaway spike for [Spike: does Jev reliably tell free-text places from value fields?](https://github.com/DanielMulec/jevpaste/issues/40),
serving the decision in [#35](https://github.com/DanielMulec/jevpaste/issues/35#issuecomment-5821465655).
Data only; no product decision is taken here.

Evidence class per statement: **[measured]** = observed in `results/raw.jsonl`, **[inference]** = reasoning on top.

## Setup
- Endpoint `POST https://ai-gateway.vercel.sh/v1/evaluate`, `model: typesafe-ai/jev`, client
  `spikes/abstention/jev.py` reused unchanged (imported via `sys.path`, pacing 0.7 s). Run date 2026-09-24.
- One call = three questions (`paste`, `contains_value`, `free_text`) in the production request shape of
  `docs/design/jev-gateway.md` (on `main`): `state = {source_document, target_context}`, `target_context` keys
  `app_name`, `window_title`, `field_label`, `placeholder`, `section_heading`, `sibling_field_labels`,
  `surrounding_text`; absent/empty keys are omitted. Option ids `c000…` (zero-based, 3 digits) + `none_of_these`.
- `paste` and `contains_value` wording: verbatim `CHOICE_INSTRUCTIONS` / `GATE_POSITIVE` / `none_of_these` from
  `spikes/abstention/run.py` with `target_field` → `target_context`.
- Source document (same for every call, synthetic): name, email, phone, street line, postcode+city line, one
  three-sentence paragraph. `candidates.derive` yields **8** candidates (name, email, phone, street, city line,
  whole paragraph, sentences 2 and 3); the paragraph's first sentence is not extracted because the sentence
  regex runs across the joined lines (generic-extractor behaviour, left as is) **[measured]**.
- 13 situations (`situations.py`): 8 free-text (ChatGPT with and without placeholder, Ghostty, Slack, WhatsApp,
  TextEdit, VS Code, Chrome comment box) and 5 value fields (sign-up email, shipping street, search box,
  Contacts mobile, Finder rename). Surrounding text 234–990 chars, synthetic names. 3 runs each.
- Borderline to the worker: **S07 comment box** (grouped free-text) and **S10 search box** (grouped value
  field, as the brief lists it). The Finder rename carries `field_label: "Name"` (the column header).

## The `free_text` question (exact wording)
```
type: boolean
instructions: "Judge only the place described by `target_context`, not `source_document`. Is `target_context` a free-text place — a chat or message composer, a document or text editor, a code editor, a terminal — where the user would paste whatever they copied, as it is? Or is it a field that expects one specific value, such as a name, an email address, a phone number, an address line or a single short entry?"
criteria:
  true:  "A free-text place: the user would paste whatever they copied, whole."
  false: "A field for one specific value."
```
The wording names categories (chat/message composer, editor, terminal; name/email/phone/address line) that
overlap with several test situations; "search" and "comment" are **not** named **[measured]**.

## Results — 3 runs per situation (probabilities as returned, 2 decimals)
| Situation | expect | free_text runs | min | max | pass | contains_value runs | paste choice runs |
|---|---|---|---|---|---|---|---|
| S01a_chatgpt_placeholder (ChatGPT composer, placeholder) | ≥ 0.8 | 0.96 / 0.96 / 0.96 | 0.96 | 0.96 | yes | 0.39 / 0.48 / 0.51 | c005 `Product designer with nine y` / c005 `Product designer with nine y` / c005 `Product designer with nine y` |
| S01b_chatgpt_no_placeholder (ChatGPT composer, no placeholder) | ≥ 0.8 | 0.96 / 0.96 / 0.97 | 0.96 | 0.97 | yes | 0.54 / 0.47 / 0.49 | c005 `Product designer with nine y` / c005 `Product designer with nine y` / c005 `Product designer with nine y` |
| S02_terminal (Ghostty shell prompt) | ≥ 0.8 | 0.89 / 0.89 / 0.89 | 0.89 | 0.89 | yes | 0.15 / 0.15 / 0.14 | none_of_these / none_of_these / none_of_these |
| S03_slack (Slack message box) | ≥ 0.8 | 0.85 / 0.85 / 0.86 | 0.85 | 0.86 | yes | 0.50 / 0.52 / 0.43 | c001 `marlene.oberholzer@example.o` / c001 `marlene.oberholzer@example.o` / c001 `marlene.oberholzer@example.o` |
| S04_whatsapp (WhatsApp composer) | ≥ 0.8 | 0.83 / 0.86 / 0.85 | 0.83 | 0.86 | yes | 0.49 / 0.48 / 0.47 | c001 `marlene.oberholzer@example.o` / c001 `marlene.oberholzer@example.o` / c005 `Product designer with nine y` |
| S05_textedit (TextEdit document) | ≥ 0.8 | 0.97 / 0.97 / 0.97 | 0.97 | 0.97 | yes | 0.77 / 0.77 / 0.79 | c005 `Product designer with nine y` / c005 `Product designer with nine y` / c005 `Product designer with nine y` |
| S06_code_editor (VS Code markdown file) | ≥ 0.8 | 0.94 / 0.95 / 0.95 | 0.94 | 0.95 | yes | 0.52 / 0.55 / 0.53 | c005 `Product designer with nine y` / c005 `Product designer with nine y` / c005 `Product designer with nine y` |
| S07_comment_box (Web comment box (borderline)) | ≥ 0.8 | 0.88 / 0.88 / 0.89 | 0.88 | 0.89 | yes | 0.35 / 0.31 / 0.33 | none_of_these / none_of_these / none_of_these |
| S08_email_field (Sign-up email field) | ≤ 0.2 | 0.04 / 0.03 / 0.03 | 0.03 | 0.04 | yes | 0.93 / 0.94 / 0.94 | c001 `marlene.oberholzer@example.o` / c001 `marlene.oberholzer@example.o` / c001 `marlene.oberholzer@example.o` |
| S09_street_field (Shipping address street) | ≤ 0.2 | 0.05 / 0.04 / 0.04 | 0.04 | 0.05 | yes | 0.91 / 0.92 / 0.93 | c003 `Lindenweg 14` / c003 `Lindenweg 14` / c003 `Lindenweg 14` |
| S10_search_box (Search box (borderline)) | ≤ 0.2 | 0.21 / 0.22 / 0.20 | 0.20 | 0.22 | **NO** | 0.39 / 0.35 / 0.32 | none_of_these / none_of_these / none_of_these |
| S11_contacts_phone (Contacts mobile field) | ≤ 0.2 | 0.04 / 0.04 / 0.04 | 0.04 | 0.04 | yes | 0.91 / 0.91 / 0.92 | c002 `+41 79 555 01 23` / c002 `+41 79 555 01 23` / c002 `+41 79 555 01 23` |
| S12_finder_rename (Finder rename (single-line title)) | ≤ 0.2 | 0.09 / 0.09 / 0.08 | 0.08 | 0.09 | yes | 0.81 / 0.80 / 0.73 | c000 `Marlene Oberholzer` / c000 `Marlene Oberholzer` / c000 `Marlene Oberholzer` |

`paste` choice probabilities (top option / none_of_these) **[measured]**: value fields 0.97–1.00 on the right
value; ChatGPT 0.92–0.94 and TextEdit 0.87–0.90 on the whole paragraph (`c005`); VS Code 0.46–0.50 on `c005`;
Slack/WhatsApp 0.30–0.41 (mostly the email); terminal, comment box and search box choose `none_of_these`
(0.32–0.55).

## Verdict against the pass criteria (fixed by Daniel)
- Free-text situations, `free_text` ≥ 0.8 on every run: **8/8 pass** (min 0.83, WhatsApp run 0) **[measured]**.
- Value-field situations, `free_text` ≤ 0.2 on every run: **4/5 pass**. **S10 search box fails**:
  0.21 / 0.22 / 0.20 (2 of 3 runs above 0.2) **[measured]**. Email, street, phone, Finder rename: 0.03–0.09.
- **Overall: FAIL as stated** — one value-field situation (search box, one the worker marks borderline)
  misses the ≤ 0.2 bar by 0.01–0.02 **[measured]**. Without S10: all 12 pass **[measured]**.
- Separation margin **[measured]**: lowest free-text value 0.83, highest value-field value 0.22; nothing
  observed between 0.22 and 0.83. Run-to-run spread within a situation ≤ 0.03.
- **[inference]** The search box would sit far below a 0.8 free-text threshold, so at the #35 threshold it
  would not be Direct-Pasted; it only misses the symmetric ≤ 0.2 criterion. Messaging composers (Slack 0.85,
  WhatsApp 0.83–0.86) are the closest to 0.8 and far from the 0.95 aspiration; the terminal is 0.89.
  Against the 0.95 aspiration only ChatGPT (0.96–0.97) and TextEdit (0.97) clear it on every run; VS Code (0.94–0.95) is at the edge.

## ChatGPT with vs. without placeholder
`free_text` 0.96/0.96/0.96 with "Ask anything" vs. 0.96/0.96/0.97 without — **no difference** **[measured]**.
`contains_value` 0.39–0.51 vs. 0.47–0.54; `paste` = whole paragraph in all 6 runs **[measured]**.

## Effect of `app_name` + `window_title` (one extra run each, without them)
- S01a ChatGPT: `free_text` 0.95 (with: 0.96 mean); paste unchanged (`c005`), `contains_value` 0.43 **[measured]**.
- S08 email: `free_text` 0.04 (with: 0.03 mean); paste unchanged (`c001`), `contains_value` 0.95 **[measured]**.
- **[inference]** In these two situations app name and title change nothing material; the surrounding text and
  label carry the judgement. A situation with thin surrounding text was not tested without them.

## Latency and tokens vs. the two-question baseline
- 3-question calls (n=42): min 332, median 464, mean 497, max 1071 ms **[measured]**.
- Same 4 situations (ChatGPT, TextEdit, email, street): 3-question median 436 ms (n=12) vs. 2-question
  median 360 ms (n=4, `paste` + `contains_value` only) **[measured]**. The baseline sample is small; the
  difference is within the observed spread of the 3-question calls **[inference]**.
- Tokens on the same situations: input 1127 vs. 992, output 145 vs. 128 (mean) **[measured]**.
- The 2-question baseline gave the same `paste` choices as the 3-question calls in all 4 situations, i.e.
  adding `free_text` did not change the excerpt choice there **[measured]**.

## Side observation
With a rich chat transcript that asks for a CV summary, ChatGPT's `paste` picks the whole paragraph at
0.92–0.94 even without `free_text` (2-question baseline) — unlike the #35 live evidence where the ChatGPT
composer yielded `none_of_these`. **[inference]** That live case had little or no surrounding text reaching
Jev; this spike does not reproduce the production resolver's surrounding text.

## Calls and cost
- **46 billed calls** (1 smoke + 39 main + 2 ablation + 4 two-question baseline), all logged in
  `results/raw.jsonl`; 3 throttled retries (429) during the main run, none failed **[measured]**.
- `marketCost` total **$0.002186** (≈ $0.000048/call); billed `cost` 0 (free-tier credit) **[measured]**.

## Files
`situations.py` (document + Target Contexts), `run.py` (`smoke | main | ablation | baseline | report`),
`analyze.py` (table; `python3 analyze.py`), `results/raw.jsonl` (verbatim responses), `results/report.md`.

## Open questions (for the supervisor)
1. Is a search box a value field (≤ 0.2) or borderline? Jev puts it at 0.20–0.22 — between the groups but far
   from 0.8.
2. Is a web comment box a Free-text Target? Jev says yes (0.88–0.89), and `paste` abstains there.
3. Messaging composers sit at 0.83–0.86: does the 0.8 bar keep enough margin, and would wording changes
   (not tried, to stay within budget) move them toward 0.95?
4. Thin-context situations (e.g. ChatGPT with no surrounding text, as AX may deliver) were not measured.
