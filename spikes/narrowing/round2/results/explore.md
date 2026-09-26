# Exploration (round-1 cells only)

Billed exploration calls: 140 (budget 150). Cells tuned on (28): A03_strasse, A12_strasse_hnr, A13_passwort_NEG, B01_handle, B02_city, B03_bio, B05_phone_NEG, C01_cover_letter, C02_motivation, C03_availability, C04_name, C05_notes_freetext, K01_three_emails, N02_url_chat, O07_amount, O09_coupon_NEG, R03_birthplace, R05_about, R06_country, R07_linkedin_NEG, R08_summary, S04_phone, S05_mobile, T01_email_two_lines, W01_chrome_textarea, W02_terminal_prompt, W03_chatgpt_composer, W04_whatsapp_composer.

## D3 wordings: the step-1 decision per variant (screen)

`exact` = the decision is the final answer; `path` = a smaller piece that still contains it; ✗ = miss. Design column: `base` = K=8 fine runs, document-order choices, full-text options.

### design `base`

| cell | expected | V0 | V1 | V2 | V3 | V5 | V6 | V7 |
|---|---|---|---|---|---|---|---|---|
| A03_strasse | `Prankergasse` |  |  | ↘ `Prankergasse 77` 0.60 |  | ↘ `Prankergasse 77` 0.46 | ↘ `Prankergasse 77` 0.58 |  |
| A12_strasse_hnr | `Prankergasse 77` | ↘ `Prankergasse 77⏎Top 11` 0.86 | ↘ `Prankergasse 77⏎Top 11` 0.84 | ↘ `Prankergasse 77⏎Top 11` 0.77<br>↘ `Prankergasse 77⏎Top 11` 0.80 | ↘ `Prankergasse 77⏎Top 11` 0.73 | ↘ `Prankergasse 77⏎Top 11` 0.75 | ↘ `Prankergasse 77⏎Top 11` 0.64 |  |
| A13_passwort_NEG | nothing |  |  | ✅ nothing_fits 0.96 |  | ✅ nothing_fits 0.89 | ✅ nothing_fits 0.93 |  |
| S04_phone | `+43 1 2345678` |  |  | ✅ `+43 1 2345678` 0.64 |  | ✅ `+43 1 2345678` 0.82 | ✅ `+43 1 2345678` 0.63 |  |
| S05_mobile | `+43 660 1112233` |  |  | ✅ `+43 660 1112233` 0.95 |  | ✅ `+43 660 1112233` 0.97 | ✅ `+43 660 1112233` 0.94 |  |
| R03_birthplace | `Linz` |  |  | ✅ `Linz` 0.76 |  | ✅ `Linz` 0.81 | ✅ `Linz` 0.85 |  |
| R05_about | `Data engineer with eight y…` |  |  | ✅ `Data engineer with eight y…` 0.94 |  | ✅ `Data engineer with eight y…` 0.94 | ✅ `Data engineer with eight y…` 0.92 |  |
| R06_country | `Austria` |  |  | ✅ `Austria` 0.89 |  | ✅ `Austria` 0.80 | ✅ `Austria` 0.81 |  |
| R07_linkedin_NEG | nothing |  |  | ✅ nothing_fits 0.95 |  | ✅ nothing_fits 0.98 | ✅ nothing_fits 0.96 |  |
| R08_summary | `Data engineer with eight y…` |  |  | ✅ `Data engineer with eight y…` 0.97 |  | ✅ `Data engineer with eight y…` 0.93 | ✅ `Data engineer with eight y…` 0.97 |  |
| O07_amount | `129,90` |  |  | ✅ `129,90` 0.58 |  | ✅ `129,90` 0.67 | ✅ `129,90` 0.61 |  |
| O09_coupon_NEG | nothing |  |  | ✅ nothing_fits 0.94 |  | ✅ nothing_fits 0.69 | ✅ nothing_fits 0.91 |  |
| B01_handle | `@mira_h` |  |  | ✅ `@mira_h` 0.82 |  | ✅ `@mira_h` 0.95 | ✅ `@mira_h` 0.93 |  |
| B02_city | `Innsbruck` | ✅ `Innsbruck` 0.97 | ✅ `Innsbruck` 0.89 | ✅ `Innsbruck` 0.95<br>✅ `Innsbruck` 0.96 | ✅ `Innsbruck` 0.96 | ✅ `Innsbruck` 0.97 | ✅ `Innsbruck` 0.98 |  |
| B03_bio | `Hi, I'm Lena Vogt, a ceram…` |  |  | ✅ everything 0.65 |  | ✅ everything 0.69 | ✅ everything 0.58 |  |
| B05_phone_NEG | nothing |  |  | ✅ nothing_fits 0.92 |  | ✅ nothing_fits 0.97 | ✅ nothing_fits 0.96 |  |
| T01_email_two_lines | ask | ✗ `wren.castellan@example.net` 0.34 | ✗ `wren.castellan@example.net` 0.45 | ✅ ask_user 0.55<br>✅ ask_user 0.49 | ✅ ask_user 0.50 | ✅ ask_user 0.75 | ✅ ask_user 0.36 |  |
| C01_cover_letter | `I am writing to apply for …` |  |  | ✅ everything 0.80 |  | ✅ everything 0.74 | ✅ everything 0.83 |  |
| C02_motivation | `What draws me to Grünraum …` | ✅ `What draws me to Grünraum …` 0.83 | ✅ `What draws me to Grünraum …` 0.71 | ✅ `What draws me to Grünraum …` 0.84<br>✅ `What draws me to Grünraum …` 0.79 | ✅ `What draws me to Grünraum …` 0.68 | ✅ `What draws me to Grünraum …` 0.94 | ✅ `What draws me to Grünraum …` 0.77 |  |
| C03_availability | `I can start on 1 December …` |  |  |  |  | ✗ everything 0.32 |  | ✗ `I can start on 1 December …` 0.40 |
| C04_name | `Theo Brandner` | ✗ everything 0.62 | ✗ everything 0.50 | ✗ everything 0.55<br>✗ everything 0.43 | ✗ everything 0.66 | ✅ `Theo Brandner` 0.34<br>✗ everything 0.43 | ✗ everything 0.54 | ✗ everything 0.37 |
| C05_notes_freetext | `Dear Ms Hofer,⏎⏎I am writi…` |  |  | ✅ everything 0.63 |  | ✅ everything 0.69 | ✅ everything 0.46 |  |
| W01_chrome_textarea | `Marlene Oberholzer⏎marlene…` | ✗ `Product designer with nine…` 0.56 | ✗ `Product designer with nine…` 0.48 | ✗ `Product designer with nine…` 0.45<br>✗ `Product designer with nine…` 0.39 | ✗ nothing_fits 0.35 | ✅ everything 0.61<br>✅ everything 0.56 | ✗ `Product designer with nine…` 0.24 | ✅ everything 0.58 |
| W02_terminal_prompt | `Marlene Oberholzer⏎marlene…` |  |  | ✗ nothing_fits 0.25 |  | ✅ everything 0.87 | ✅ everything 0.47 |  |
| W03_chatgpt_composer | `Marlene Oberholzer⏎marlene…` | ✅ everything 0.41 | ✅ everything 0.37 | ✗ `Product designer with nine…` 0.80<br>✗ `Product designer with nine…` 0.88 | ✗ `Product designer with nine…` 0.80 | ✅ everything 0.44<br>✅ everything 0.47 | ✅ everything 0.47 | ✅ everything 0.35 |
| W04_whatsapp_composer | `Marlene Oberholzer⏎marlene…` |  |  | ✅ everything 0.40 |  | ✅ everything 0.41 | ✅ everything 0.47 |  |
| K01_three_emails | ask | ✗ `marcus@anything.com` 0.93 | ✗ `marcus@anything.com` 0.78 | ✅ ask_user 0.74 | ✅ ask_user 0.71 | ✅ ask_user 0.89 | ✅ ask_user 0.76 |  |
| N02_url_chat | `https://www.miraholzner.ex…` | ✗ nothing_fits 0.54 | ✗ nothing_fits 0.49 | ✗ nothing_fits 0.38<br>✗ nothing_fits 0.41 | ✅ everything 0.44 | ✅ everything 0.58<br>✅ everything 0.57 | ✗ nothing_fits 0.40 | ✅ everything 0.45 |
| **total** exact / path / miss | | 3 / 1 / 5 | 3 / 1 / 5 | 23 / 3 / 9 | 5 / 1 / 3 | 28 / 2 / 2 | 22 / 2 / 3 | 3 / 0 / 2 |

### design `base+form=ids`

| cell | expected | V5 |
|---|---|---|
| A03_strasse | `Prankergasse` | ↘ `Prankergasse 77` 0.53 |
| S04_phone | `+43 1 2345678` | ↘ `Phone +43 1 2345678` 0.82 |
| T01_email_two_lines | ask | ✅ ask_user 0.60 |
| C04_name | `Theo Brandner` | ✅ `Theo Brandner` 0.42 |
| W01_chrome_textarea | `Marlene Oberholzer⏎marlene…` | ✅ everything 0.51 |
| W03_chatgpt_composer | `Marlene Oberholzer⏎marlene…` | ✅ everything 0.41 |
| K01_three_emails | ask | ✅ ask_user 0.83 |
| N02_url_chat | `https://www.miraholzner.ex…` | ✅ everything 0.46 |
| **total** exact / path / miss | | 6 / 2 / 0 |

### design `base+layout=cont`

| cell | expected | V5 | V7 |
|---|---|---|---|
| C03_availability | `I can start on 1 December …` | ✗ everything 0.42 | ✗ everything 0.38 |
| C04_name | `Theo Brandner` | ✗ everything 0.33 | ✅ `Theo Brandner` 0.64 |
| **total** exact / path / miss | | 0 / 0 / 2 | 1 / 0 / 1 |

### design `base+layout=cont+form=ids`

| cell | expected | V5 | V7 |
|---|---|---|---|
| C03_availability | `I can start on 1 December …` | ✗ `I can start on 1 December …` 0.41 | ✗ `I can start on 1 December …` 0.49 |
| C04_name | `Theo Brandner` | ✅ `Theo Brandner` 0.50 | ✅ `Theo Brandner` 0.58 |
| W01_chrome_textarea | `Marlene Oberholzer⏎marlene…` | ✅ everything 0.48 | ✅ everything 0.45 |
| W03_chatgpt_composer | `Marlene Oberholzer⏎marlene…` | ✅ everything 0.45 | ✅ everything 0.33 |
| **total** exact / path / miss | | 3 / 0 / 1 | 3 / 0 / 1 |

## D4 place choice: argmax per wording (screen + runs)

Expected class: whole-copy cells → everything, traps → nothing, all others (incl. ask cells) → one_part.

| cell | expected | P1 | P2 | P3 | P4 |
|---|---|---|---|---|---|
| A03_strasse | one_part | ✅ one_part 0.79<br>✅ one_part 0.77 | ✅ one_part 0.98<br>✅ one_part 0.99 | ✅ one_part 0.83<br>✅ one_part 0.81 | ✗ everything 0.55<br>✗ everything 0.71 |
| A12_strasse_hnr | one_part | ✅ one_part 0.80<br>✅ one_part 0.75 | ✅ one_part 1.00<br>✅ one_part 1.00 | ✅ one_part 0.80 | ✗ everything 0.59 |
| A13_passwort_NEG | nothing | ✅ nothing 0.65 | ✅ nothing 0.89 | ✅ nothing 0.86 | ✗ everything 0.79 |
| S04_phone | one_part | ✅ one_part 0.61<br>✅ one_part 0.54 | ✅ one_part 0.98<br>✅ one_part 0.98 | ✅ one_part 0.77<br>✅ one_part 0.86 | ✅ one_part 0.50<br>✗ everything 0.80 |
| S05_mobile | one_part | ✅ one_part 0.57 | ✅ one_part 0.98 | ✅ one_part 0.85 | ✗ everything 0.54 |
| R03_birthplace | one_part | ✅ one_part 0.87 | ✅ one_part 1.00 | ✅ one_part 0.92 | ✅ one_part 0.53 |
| R05_about | one_part | ✅ one_part 0.77 | ✅ one_part 0.99 | ✅ one_part 0.62 | ✗ everything 0.77 |
| R06_country | one_part | ✅ one_part 0.53 | ✅ one_part 0.86 | ✅ one_part 0.70 | ✗ everything 0.65 |
| R07_linkedin_NEG | nothing | ✅ nothing 0.47 | ✅ nothing 0.88 | ✅ nothing 0.96 | ✗ everything 0.61 |
| R08_summary | one_part | ✅ one_part 0.81 | ✅ one_part 0.98 | ✅ one_part 0.69 | ✗ everything 0.77 |
| O07_amount | one_part | ✅ one_part 0.79 | ✅ one_part 0.98 | ✅ one_part 0.85 | ✗ everything 0.69 |
| O09_coupon_NEG | nothing | ✅ nothing 0.54 | ✅ nothing 0.86 | ✅ nothing 0.84 | ✗ everything 0.54 |
| B01_handle | one_part | ✅ one_part 0.66 | ✅ one_part 0.92 | ✅ one_part 0.80 | ✗ everything 0.53 |
| B02_city | one_part | ✅ one_part 0.51<br>✅ one_part 0.51 | ✅ one_part 0.95<br>✅ one_part 0.91 | ✅ one_part 0.85 | ✗ everything 0.54 |
| B03_bio | everything | ✅ everything 0.82 | ✅ everything 0.62 | ✅ everything 0.87 | ✅ everything 0.91 |
| B05_phone_NEG | nothing | ✅ nothing 0.44 | ✅ nothing 0.85 | ✅ nothing 0.92 | ✗ everything 0.67 |
| T01_email_two_lines | ask | ✗ everything 0.66<br>✗ everything 0.68<br>✗ everything 0.63 | ✗ one_part 0.90<br>✗ one_part 0.86<br>✗ one_part 0.84 | ✗ one_part 0.65<br>✗ one_part 0.53 | ✗ everything 0.84<br>✗ everything 0.86 |
| C01_cover_letter | everything | ✅ everything 0.92 | ✅ everything 0.81 | ✅ everything 0.86 | ✅ everything 0.98 |
| C02_motivation | one_part | ✅ one_part 0.64<br>✅ one_part 0.64 | ✅ one_part 0.95<br>✅ one_part 0.93 | ✅ one_part 0.82 | ✗ everything 0.49 |
| C03_availability | one_part | ✗ everything 0.70<br>✗ everything 0.74<br>✗ everything 0.79 | ✅ one_part 0.73<br>✅ one_part 0.66<br>✅ one_part 0.78 | ✅ one_part 0.68<br>✅ one_part 0.71<br>✅ one_part 0.73 | ✗ everything 0.68<br>✗ everything 0.82<br>✗ everything 0.73 |
| C04_name | one_part | ✗ everything 0.82<br>✗ everything 0.76<br>✗ everything 0.91<br>✗ everything 0.76<br>✗ everything 0.77<br>✗ everything 0.90 | ✅ one_part 0.54<br>✅ one_part 0.57<br>✅ one_part 0.57<br>✗ everything 0.56<br>✅ one_part 0.52<br>✗ everything 0.46 | ✅ one_part 0.74<br>✅ one_part 0.81<br>✅ one_part 0.59<br>✅ one_part 0.72<br>✅ one_part 0.79 | ✗ everything 0.71<br>✗ everything 0.77<br>✗ everything 0.75<br>✗ everything 0.68<br>✗ everything 0.73 |
| C05_notes_freetext | everything | ✅ everything 0.62 | ✗ one_part 0.53 | ✅ everything 0.69 | ✅ everything 0.69 |
| W01_chrome_textarea | everything | ✅ everything 0.64<br>✅ everything 0.62<br>✅ everything 0.62<br>✅ everything 0.63<br>✅ everything 0.68 | ✗ one_part 0.70<br>✗ one_part 0.70<br>✗ one_part 0.61<br>✗ one_part 0.70<br>✗ one_part 0.70 | ✅ everything 0.77<br>✅ everything 0.71<br>✅ everything 0.76<br>✅ everything 0.72 | ✅ everything 0.89<br>✅ everything 0.81<br>✅ everything 0.92<br>✅ everything 0.86 |
| W02_terminal_prompt | everything | ✅ everything 0.76 | ✗ nothing 0.40 | ✅ everything 0.93 | ✅ everything 0.94 |
| W03_chatgpt_composer | everything | ✗ one_part 0.63<br>✗ one_part 0.61<br>✅ everything 0.58<br>✗ one_part 0.61<br>✅ everything 0.56 | ✗ one_part 0.60<br>✗ one_part 0.55<br>✗ one_part 0.79<br>✗ one_part 0.59<br>✗ one_part 0.77 | ✗ one_part 0.53<br>✅ everything 0.60<br>✗ one_part 0.56<br>✅ everything 0.61 | ✅ everything 0.67<br>✅ everything 0.92<br>✅ everything 0.67<br>✅ everything 0.96 |
| W04_whatsapp_composer | everything | ✅ everything 0.83 | ✅ everything 0.54 | ✅ everything 0.68 | ✅ everything 0.94 |
| K01_three_emails | ask | ✗ one_part 0.84<br>✗ one_part 0.83<br>✗ one_part 0.64 | ✗ one_part 0.99<br>✗ one_part 0.98<br>✗ one_part 0.99 | ✗ one_part 0.89<br>✗ one_part 0.86 | ✗ one_part 0.51<br>✗ everything 0.82 |
| N02_url_chat | everything | ✗ nothing 0.49<br>✗ nothing 0.49<br>✗ nothing 0.60<br>✗ one_part 0.48 | ✗ nothing 0.55<br>✗ nothing 0.55<br>✗ nothing 0.76<br>✗ nothing 0.56 | ✗ nothing 0.66<br>✗ nothing 0.70<br>✗ nothing 0.62 | ✗ nothing 0.47<br>✅ everything 0.79<br>✗ nothing 0.47 |
| **correct** | | 33/55 | 31/55 | 37/46 | 16/46 |

## D2 option form: input tokens and latency per request

Same wording (V5); `ids` = pieces held once in `state.excerpts`, options id-only (`null` descriptions); `full` = every option carries its text.

| cell | request | full: questions / tokens / ms | ids: questions / tokens / ms |
|---|---|---|---|
| A03_strasse | run r2 step step 0 | – | 2 / 4690 / 489 |
| A03_strasse | run r2 step step 1 | – | 1 / 1353 / 799 |
| A03_strasse | run r2 step step 2 | – | 1 / 2660 / 632 |
| A03_strasse | screen step 1 (+4 place questions) | – | 5 / 5088 / 829 |
| A12_strasse_hnr | run r2 step step 0 | – | 2 / 4616 / 524 |
| A12_strasse_hnr | run r2 step step 1 | – | 1 / 1279 / 477 |
| B02_city | run r2 follow_up step 0 | – | 4 / 9932 / 8206 |
| B02_city | run r2 step step 0 | – | 3 / 13920 / 954 |
| B02_city | run r2+form=full+layout=doc follow_up step 0 | 4 / 3207 / 506 | – |
| B02_city | run r2+form=full+layout=doc step step 0 | 3 / 10575 / 804 | – |
| B05_phone_NEG | run r2 step step 0 | – | 3 / 13920 / 604 |
| C02_motivation | run r2 follow_up step 0 | – | 2 / 8354 / 883 |
| C02_motivation | run r2 step step 0 | – | 4 / 21711 / 972 |
| C02_motivation | run r2 step step 1 | – | 2 / 8186 / 542 |
| C03_availability | run r2 follow_up step 0 | – | 3 / 11191 / 623 |
| C03_availability | run r2 step step 0 | – | 4 / 21711 / 1112 |
| C04_name | run r2 follow_up step 0 | – | 4 / 5326 / 532 |
| C04_name | run r2 step step 0 | – | 4 / 21713 / 741 |
| C04_name | run r2+form=full+layout=doc step step 0 | 4 / 16336 / 700 | – |
| C04_name | screen step 1 (+4 place questions) | – | 7 / 21151 / 791 |
| C05_notes_freetext | run r2 step step 0 | – | 4 / 21711 / 734 |
| K01_three_emails | run r2 step step 0 | 4 / 21838 / 686 | – |
| K01_three_emails | screen step 1 (+4 place questions) | – | 7 / 26121 / 1284 |
| N02_url_chat | run r2 step step 0 | – | 2 / 8398 / 796 |
| N02_url_chat | screen step 1 (+4 place questions) | – | 5 / 8796 / 601 |
| O07_amount | run r2 step step 0 | – | 2 / 5476 / 498 |
| O07_amount | run r2 step step 1 | – | 1 / 1091 / 568 |
| O09_coupon_NEG | run r2 step step 0 | – | 2 / 5479 / 508 |
| R05_about | run r2 follow_up step 0 | – | 2 / 10034 / 589 |
| R05_about | run r2 step step 0 | – | 4 / 16953 / 601 |
| R05_about | run r2+form=full+layout=doc follow_up step 0 | 4 / 9065 / 540 | – |
| R05_about | run r2+form=full+layout=doc step step 0 | 3 / 12426 / 1214 | – |
| R06_country | run r2 follow_up step 0 | – | 4 / 5843 / 704 |
| R06_country | run r2 step step 0 | – | 4 / 16936 / 839 |
| S04_phone | run r2 step step 0 | – | 2 / 6758 / 627 |
| S04_phone | run r2 step step 1 | – | 1 / 1589 / 469 |
| S04_phone | run r2 step step 2 | – | 1 / 1311 / 558 |
| S04_phone | run r2+form=full+layout=doc step step 0 | 2 / 5460 / 498 | – |
| S04_phone | run r2+form=full+layout=doc step step 1 | 1 / 1189 / 478 | – |
| S04_phone | screen step 1 (+4 place questions) | – | 5 / 7156 / 800 |
| T01_email_two_lines | run r2 step step 0 | – | 2 / 3164 / 722 |
| T01_email_two_lines | run r2+form=full+layout=doc step step 0 | 2 / 2580 / 509 | – |
| T01_email_two_lines | screen step 1 (+4 place questions) | – | 5 / 3562 / 621 |
| W01_chrome_textarea | run r2 step step 0 | – | 3 / 14327 / 1315 |
| W01_chrome_textarea | screen step 1 (+4 place questions) | – | 6 / 14495 / 615 |
| W02_terminal_prompt | run r2 step step 0 | – | 3 / 14191 / 575 |
| W03_chatgpt_composer | run r2 step step 0 | – | 3 / 14222 / 546 |
| W03_chatgpt_composer | run r2+form=full+layout=doc step step 0 | 3 / 10802 / 559 | – |
| W03_chatgpt_composer | screen step 1 (+4 place questions) | – | 6 / 14390 / 586 |
| W04_whatsapp_composer | run r2 step step 0 | – | 3 / 14236 / 1038 |

## Full Narrowing runs (explore)

| design | cell | A | B | outcome | calls | ms | place (every / part / nothing) | steps |
|---|---|---|---|---|---|---|---|---|
| base+variant=V5+place=P3 | T01_email_two_lines | ✅ | ✅ | ask | 1 | 754 | 0.38 / 0.61 / 0.01 | ask_user (84, 0.73) |
| base+variant=V5+place=P3 | A12_strasse_hnr | ✅ | ✅ | `Prankergasse 77` | 3 | 1632 | 0.22 / 0.78 / 0.00 | `Prankergasse 77⏎To…` (115, 0.74) › `Prankergasse 77` (13, 0.60) › keep (17, 0.98) |
| base+variant=V5+place=P3 | S04_phone | ✅ | ✅ | `+43 1 2345678` | 2 | 1696 | 0.15 / 0.85 / 0.00 | `+43 1 2345678` (186, 0.68) › keep (18, 0.95) |
| base+variant=V5+place=P3 | W03_chatgpt_composer | ✅ | ✅ | `Marlene Oberholzer⏎marlene…` | 1 | 574 | 0.40 / 0.60 / 0.00 | keep (255/2, 0.46) |
| base+variant=V5+place=P3 | C04_name | ❌ | ❌ | `Dear Ms Hofer,⏎⏎I am writi…` | 2 | 1441 | 0.25 / 0.71 / 0.04 | keep (78/3, 0.53) |
| r2 | T01_email_two_lines | ✅ | ✅ | ask | 1 | 722 | 0.37 / 0.63 / 0.00 | ask_user (84, 0.58) |
| r2 | K01_three_emails | ✅ | ✅ | ask | 1 | 686 | 0.12 / 0.88 / 0.00 | ask_user (255/3, 0.92) |
| r2 | A12_strasse_hnr | ✅ | ✅ | `Prankergasse 77` | 2 | 1001 | 0.29 / 0.71 / 0.00 | `Prankergasse 77` (115, 0.54) › keep (17, 0.92) |
| r2 | A03_strasse | ✅ | ✅ | `Prankergasse` | 3 | 1920 | 0.20 / 0.80 / 0.00 | `Prankergasse 77` (115, 0.64) › `Prankergasse` (17, 0.92) › keep (76, 0.81) |
| r2 | S04_phone | ✅ | ✅ | `+43 1 2345678` | 3 | 1654 | 0.16 / 0.84 / 0.00 | `Phone +43 1 234567…` (186, 0.85) › `+43 1 2345678` (27, 0.96) › keep (18, 0.81) |
| r2 | O07_amount | ✅ | ✅ | `129,90` | 2 | 1066 | 0.11 / 0.89 / 0.00 | `129,90` (151, 0.83) › keep (11, 0.93) |
| r2 | O09_coupon_NEG | ✅ | ✅ | nothing | 1 | 508 | 0.10 / 0.09 / 0.81 | nothing_fits (151, 0.63) |
| r2 | N02_url_chat | ✅ | ✅ | `https://www.miraholzner.ex…` | 1 | 796 | 0.49 / 0.02 / 0.49 | keep (235, 0.63) |
| r2 | B02_city | ✅ | ✅ | `Innsbruck` | 2 | 9160 | 0.14 / 0.86 / 0.00 | `Innsbruck` (44/2, 0.89) › keep (46, 0.98) |
| r2 | B05_phone_NEG | ✅ | ✅ | nothing | 1 | 604 | 0.06 / 0.05 / 0.89 | nothing_fits (255/2, 0.59) |
| r2 | R05_about | ✅ | ✅ | `Data engineer with eight y…` | 2 | 1190 | 0.21 / 0.79 / 0.00 | `Data engineer with…` (63/3, 0.42) › keep (255, 0.81) |
| r2 | R06_country | ✅ | ❌ | `Austria` | 2 | 1543 | 0.25 / 0.25 / 0.50 | `Austria` (59/3, 0.71) › keep (30, 0.81) |
| r2 | C02_motivation | ✅ | ✅ | `What draws me to Grünraum …` | 3 | 2397 | 0.16 / 0.84 / 0.00 | `What draws me to G…` (66/3, 0.20) › keep (255/2, 0.39) |
| r2 | C03_availability | ❌ | ❌ | `I can start on 1 December …` | 2 | 1734 | 0.22 / 0.78 / 0.00 | `I can start on 1 D…` (70/3, 0.22) › keep (154, 0.76) |
| r2 | C04_name | ✅ | ✅ | `Theo Brandner` | 2 | 1273 | 0.15 / 0.84 / 0.01 | `Theo Brandner` (65/3, 0.57) › keep (15, 0.96) |
| r2 | C05_notes_freetext | ✅ | ✅ | `Dear Ms Hofer,⏎⏎I am writi…` | 1 | 734 | 0.74 / 0.21 / 0.05 | keep (255/3, 0.51) |
| r2 | W01_chrome_textarea | ✅ | ✅ | `Marlene Oberholzer⏎marlene…` | 1 | 1315 | 0.86 / 0.08 / 0.06 | keep (255/2, 0.63) |
| r2 | W03_chatgpt_composer | ✅ | ✅ | `Marlene Oberholzer⏎marlene…` | 1 | 546 | 0.64 / 0.36 / 0.00 | keep (255/2, 0.45) |
| r2 | W04_whatsapp_composer | ✅ | ✅ | `Marlene Oberholzer⏎marlene…` | 1 | 1038 | 0.71 / 0.28 / 0.01 | keep (255/2, 0.32) |
| r2 | W02_terminal_prompt | ✅ | ✅ | `Marlene Oberholzer⏎marlene…` | 1 | 575 | 0.92 / 0.02 / 0.06 | keep (255/2, 0.75) |
| r2+form=full+layout=doc | C04_name | ❌ | ❌ | `Dear Ms Hofer,⏎⏎I am writi…` | 1 | 700 | 0.31 / 0.62 / 0.07 | keep (255/3, 0.44) |
| r2+form=full+layout=doc | W03_chatgpt_composer | ✅ | ✅ | `Marlene Oberholzer⏎marlene…` | 1 | 559 | 0.40 / 0.60 / 0.00 | keep (255/2, 0.42) |
| r2+form=full+layout=doc | B02_city | ✅ | ✅ | `Innsbruck` | 2 | 1310 | 0.13 / 0.84 / 0.03 | `Innsbruck` (23/2, 0.94) › keep (46, 0.98) |
| r2+form=full+layout=doc | R05_about | ✅ | ✅ | `Data engineer with eight y…` | 2 | 1754 | 0.39 / 0.60 / 0.01 | `Data engineer with…` (39/2, 0.92) › keep (255, 0.90) |
| r2+form=full+layout=doc | S04_phone | ✅ | ✅ | `+43 1 2345678` | 2 | 977 | 0.14 / 0.86 / 0.00 | `+43 1 2345678` (186, 0.64) › keep (18, 0.96) |
| r2+form=full+layout=doc | T01_email_two_lines | ✅ | ✅ | ask | 1 | 509 | 0.34 / 0.66 / 0.00 | ask_user (84, 0.76) |

- `base+variant=V5+place=P3`: A 4/5, B 4/5; calls mean 1.80; latency median 1441 ms, max 1696 ms.

- `r2`: A 19/20, B 18/20; calls mean 1.65; latency median 1052 ms, max 9160 ms.

- `r2+form=full+layout=doc`: A 5/6, B 5/6; calls mean 1.50; latency median 839 ms, max 1754 ms.

