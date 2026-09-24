calls logged: 46 (smoke=1, main=39, no_app_title=2, baseline2q=4)
marketCost total $0.002186, billed cost $0.000000

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

situations passing: 12/13

ablation (no app_name/window_title) vs main-run mean:
  S01a_chatgpt_placeholder: free_text 0.95 (with: mean 0.960), contains_value 0.43, paste c005 `Product designer with nine y`, keys ['placeholder', 'surrounding_text']
  S08_email_field: free_text 0.04 (with: mean 0.033), contains_value 0.95, paste c001 `marlene.oberholzer@example.o`, keys ['field_label', 'sibling_field_labels', 'surrounding_text']

latency ms, 3 questions (all):          n=42 min=332 median=464 mean=497 max=1071
latency ms, 3 questions (same 4 sits.): n=12 min=332 median=436 mean=508 max=1071
latency ms, 2 questions baseline:       n=4 min=349 median=360 mean=388 max=483
tokens main       (same sits.): input mean 1127, output mean 145
tokens baseline2q (same sits.): input mean 992, output mean 128
