# Round-2 matrix report (design `r2b`, frozen at GATE A2; N03 after the approved fallback fix)

Pastes: 166 (round-1 cells 130, held-out 36). Both runs of every cell.

### Round-1 cells — policy A

| # | criterion | result |
|---|---|---|
| 1 | every positive cell hits (borderline reported, not gating) | **FAIL** — 71/74 pastes; misses: C03_availability r0 → `I can start on 1 December 2026 and…`, C03_availability r1 → `I can start on 1 December 2026 and…`, C04_name r0 → `Dear Ms Hofer,⏎⏎I am writing to ap…`. Borderline: 20/24 (misses: R10_description r0 → `Anna Reisinger⏎Born 14 March 1991 …`, R10_description r1 → `Anna Reisinger⏎Born 14 March 1991 …`, B06_biography r0 → nothing, B06_biography r1 → nothing) |
| 2 | every trap cell ends in No Suitable Match | PASS — 12/12 |
| 3 | whole copy in W01_chrome_textarea, W02_terminal_prompt, W03_chatgpt_composer, W04_whatsapp_composer, C05_notes_freetext; paragraph in R05_about, R08_summary, R10_description | **FAIL** — 14/16; misses: R10_description r0 → `Anna Reisinger⏎Born 14 March 1991 …`, R10_description r1 → `Anna Reisinger⏎Born 14 March 1991 …` |
| 4 | chooser opens on T01_email_two_lines, K01_three_emails, nowhere else | PASS — opened 4/4; asks elsewhere: none |
| 5 | every paste byte-exact | PASS — 130/130 |
| 6 | median < 2 s, nothing > 5 s | PASS — median 1059 ms, p90 1586 ms, max 3421 ms (n=128) |
| 7 | new cells | N01_address_line_ort 2/2 (`Graz` / `Graz`); N02_url_chat 2/2 (`https://www.miraholzner.example/po…` / `https://www.miraholzner.example/po…`); N03_list_300_lines 2/2 (`WINTER-4471-KQ` / `WINTER-4471-KQ`); N04_too_big 2/2 (error 400 / error 400) |

### Held-out cells — policy A

| # | criterion | result |
|---|---|---|
| 1 | every positive cell hits (borderline reported, not gating) | PASS — 18/18 pastes. Borderline: 0/0 |
| 2 | every trap cell ends in No Suitable Match | PASS — 4/4 |
| 3 | whole copy in H04_issue_comment, H05_messages_composer; paragraph in H06_company_description | PASS — 6/6 |
| 4 | chooser opens on H09_three_emails_webinar, H10_three_emails_folio, H11_two_emails_catering, nowhere else | PASS — opened 6/6; asks elsewhere: none |
| 5 | every paste byte-exact | PASS — 36/36 |
| 6 | median < 2 s, nothing > 5 s | PASS — median 956 ms, p90 1425 ms, max 2237 ms (n=36) |
| 7 | new cells | H07_url_slack 2/2 (`https://docs.northbeam.example/run…` / `https://docs.northbeam.example/run…`); H08_url_teams 2/2 (`https://www.kofler-keramik.example…` / `https://www.kofler-keramik.example…`) |

### Round-1 cells — policy B

| # | criterion | result |
|---|---|---|
| 1 | every positive cell hits (borderline reported, not gating) | **FAIL** — 71/74 pastes; misses: C03_availability r0 → `I can start on 1 December 2026 and…`, C03_availability r1 → `I can start on 1 December 2026 and…`, C04_name r0 → `Dear Ms Hofer,⏎⏎I am writing to ap…`. Borderline: 21/24 (misses: R10_description r0 → `Anna Reisinger⏎Born 14 March 1991 …`, R10_description r1 → `Anna Reisinger⏎Born 14 March 1991 …`, B06_biography r1 → nothing) |
| 2 | every trap cell ends in No Suitable Match | PASS — 12/12 |
| 3 | whole copy in W01_chrome_textarea, W02_terminal_prompt, W03_chatgpt_composer, W04_whatsapp_composer, C05_notes_freetext; paragraph in R05_about, R08_summary, R10_description | **FAIL** — 14/16; misses: R10_description r0 → `Anna Reisinger⏎Born 14 March 1991 …`, R10_description r1 → `Anna Reisinger⏎Born 14 March 1991 …` |
| 4 | chooser opens on T01_email_two_lines, K01_three_emails, nowhere else | PASS — opened 4/4; asks elsewhere: none |
| 5 | every paste byte-exact | PASS — 130/130 |
| 6 | median < 2 s, nothing > 5 s | PASS — median 1052 ms, p90 1586 ms, max 3421 ms (n=128) |
| 7 | new cells | N01_address_line_ort 2/2 (`Graz` / `Graz`); N02_url_chat 0/2 (nothing / nothing); N03_list_300_lines 2/2 (`WINTER-4471-KQ` / `WINTER-4471-KQ`); N04_too_big 2/2 (error 400 / error 400) |

### Held-out cells — policy B

| # | criterion | result |
|---|---|---|
| 1 | every positive cell hits (borderline reported, not gating) | PASS — 18/18 pastes. Borderline: 0/0 |
| 2 | every trap cell ends in No Suitable Match | PASS — 4/4 |
| 3 | whole copy in H04_issue_comment, H05_messages_composer; paragraph in H06_company_description | PASS — 6/6 |
| 4 | chooser opens on H09_three_emails_webinar, H10_three_emails_folio, H11_two_emails_catering, nowhere else | PASS — opened 6/6; asks elsewhere: none |
| 5 | every paste byte-exact | PASS — 36/36 |
| 6 | median < 2 s, nothing > 5 s | PASS — median 956 ms, p90 1425 ms, max 2237 ms (n=36) |
| 7 | new cells | H07_url_slack 2/2 (`https://docs.northbeam.example/run…` / `https://docs.northbeam.example/run…`); H08_url_teams 2/2 (`https://www.kofler-keramik.example…` / `https://www.kofler-keramik.example…`) |

### Summary: failing criteria

- round-1, policy A: 1, 3
- held-out, policy A: none
- round-1, policy B: 1, 3, 7
- held-out, policy B: none

## Every miss, with what Jev chose instead

| cell | run | policy | expected | pasted | steps (pick (options/choices, p)) | place (every/part/nothing) |
|---|---|---|---|---|---|---|
| R10_description ⚠ | 0 | A | `Data engineer with eight years of …` | `Anna Reisinger⏎Born 14 March 1991 …` | keep (255/3, 0.37) | 0.50 / 0.50 / 0.00 |
| R10_description ⚠ | 0 | B | `Data engineer with eight years of …` | `Anna Reisinger⏎Born 14 March 1991 …` | keep (255/3, 0.37) | 0.50 / 0.50 / 0.00 |
| R10_description ⚠ | 1 | A | `Data engineer with eight years of …` | `Anna Reisinger⏎Born 14 March 1991 …` | keep (255/3, 0.30) | 0.50 / 0.50 / 0.00 |
| R10_description ⚠ | 1 | B | `Data engineer with eight years of …` | `Anna Reisinger⏎Born 14 March 1991 …` | keep (255/3, 0.30) | 0.50 / 0.50 / 0.00 |
| B06_biography ⚠ | 0 | A | `Hi, I'm Lena Vogt, a ceramicist wo…` | nothing | nothing_fits (61/2, 0.38) | 0.57 / 0.42 / 0.01 |
| B06_biography ⚠ | 1 | A | `Hi, I'm Lena Vogt, a ceramicist wo…` | nothing | nothing_fits (255/2, 0.22) | 0.47 / 0.52 / 0.01 |
| B06_biography ⚠ | 1 | B | `Hi, I'm Lena Vogt, a ceramicist wo…` | nothing | nothing_fits (255/2, 0.22) | 0.47 / 0.52 / 0.01 |
| C03_availability | 0 | A | `I can start on 1 December 2026 and…` | `I can start on 1 December 2026 and…` | `I can start on 1 Decem…` (62/3, 0.39) › keep (154, 0.70, spec) | 0.27 / 0.72 / 0.01 |
| C03_availability | 0 | B | `I can start on 1 December 2026 and…` | `I can start on 1 December 2026 and…` | `I can start on 1 Decem…` (62/3, 0.39) › keep (154, 0.70, spec) | 0.27 / 0.72 / 0.01 |
| C03_availability | 1 | A | `I can start on 1 December 2026 and…` | `I can start on 1 December 2026 and…` | `I can start on 1 Decem…` (63/3, 0.38) › keep (154, 0.69, spec) | 0.20 / 0.79 / 0.01 |
| C03_availability | 1 | B | `I can start on 1 December 2026 and…` | `I can start on 1 December 2026 and…` | `I can start on 1 Decem…` (63/3, 0.38) › keep (154, 0.69, spec) | 0.20 / 0.79 / 0.01 |
| C04_name | 0 | A | `Theo Brandner` | `Dear Ms Hofer,⏎⏎I am writing to ap…` | keep (69/3, 0.44) | 0.18 / 0.81 / 0.01 |
| C04_name | 0 | B | `Theo Brandner` | `Dear Ms Hofer,⏎⏎I am writing to ap…` | keep (69/3, 0.44) | 0.18 / 0.81 / 0.01 |
| N02_url_chat | 0 | B | `https://www.miraholzner.example/po…` | nothing | keep (235, 0.45) | 0.24 / 0.06 / 0.70 |
| N02_url_chat | 1 | B | `https://www.miraholzner.example/po…` | nothing | keep (235, 0.47) | 0.33 / 0.05 / 0.62 |

## Expectation questions for Daniel

- **C03_availability** r0: pasted `I can start on 1 December 2026 and…`; step 1 pick `I can start on 1 December 2026 and…` (p 0.39), then keep (154, 0.70, spec). Scored as a miss — the fixture expects the 2-line paragraph 3; the second line (`I am happy to relocate for the role.`) is not about availability.
- **C03_availability** r1: pasted `I can start on 1 December 2026 and…`; step 1 pick `I can start on 1 December 2026 and…` (p 0.38), then keep (154, 0.69, spec). Scored as a miss — the fixture expects the 2-line paragraph 3; the second line (`I am happy to relocate for the role.`) is not about availability.

## Per-paste table

Steps: `pick (options[/choices], p)`; `spec` = answered by a speculative question (no extra call). p(all) = p(everything / keep) of the deciding choice at step 1; max p(nothing) and p(ask) over steps.

| cell | run | A | B | pasted (A) | calls | ms | forms | steps | p(all) s1 | p(nothing) | p(ask) | place every/part/nothing |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A01_vorname | 0 | ✅ | ✅ | `Mira` | 2 | 1337 | ids | `Mira` (115, 0.92) › keep (12, 1.00) | 0.02 | 0.00 | 0.00 | 0.19 / 0.81 / 0.00 |
| A01_vorname | 1 | ✅ | ✅ | `Mira` | 2 | 905 | ids | `Mira` (115, 0.90) › keep (12, 1.00) | 0.03 | 0.00 | 0.00 | 0.20 / 0.80 / 0.00 |
| A02_nachname | 0 | ✅ | ✅ | `Holzner` | 2 | 930 | ids | `Holzner` (115, 0.90) › keep (30, 1.00) | 0.03 | 0.00 | 0.02 | 0.21 / 0.79 / 0.00 |
| A02_nachname | 1 | ✅ | ✅ | `Holzner` | 2 | 1008 | ids | `Holzner` (115, 0.92) › keep (30, 0.99) | 0.02 | 0.00 | 0.01 | 0.15 / 0.85 / 0.00 |
| A03_strasse | 0 | ✅ | ✅ | `Prankergasse` | 2 | 1045 | ids | `Prankergasse` (115, 0.39) › keep (76, 0.91) | 0.04 | 0.03 | 0.07 | 0.43 / 0.56 / 0.01 |
| A03_strasse | 1 | ✅ | ✅ | `Prankergasse` | 3 | 1691 | ids | `Prankergasse 77` (115, 0.54) › `Prankergasse` (17, 0.72) › keep (76, 0.91) | 0.03 | 0.02 | 0.05 | 0.21 / 0.79 / 0.00 |
| A04_hausnummer | 0 | ✅ | ✅ | `77` | 2 | 1109 | ids | `77` (115, 0.92) › keep (4, 0.98) | 0.02 | 0.00 | 0.02 | 0.33 / 0.65 / 0.02 |
| A04_hausnummer | 1 | ✅ | ✅ | `77` | 2 | 921 | ids | `77` (115, 0.94) › keep (4, 0.97) | 0.02 | 0.00 | 0.02 | 0.16 / 0.84 / 0.00 |
| A05_adresszusatz | 0 | ✅ | ✅ | `Top 11` | 2 | 1798 | ids | `Top 11` (115, 0.83) › keep (8, 0.86) | 0.05 | 0.02 | 0.04 | 0.13 / 0.86 / 0.01 |
| A05_adresszusatz | 1 | ✅ | ✅ | `Top 11` | 2 | 1026 | ids | `Top 11` (115, 0.83) › keep (8, 0.89) | 0.05 | 0.02 | 0.04 | 0.12 / 0.87 / 0.01 |
| A06_plz | 0 | ✅ | ✅ | `8020` | 2 | 975 | ids | `8020` (115, 0.98) › keep (11, 1.00) | 0.01 | 0.00 | 0.01 | 0.19 / 0.81 / 0.00 |
| A06_plz | 1 | ✅ | ✅ | `8020` | 2 | 965 | ids | `8020` (115, 0.98) › keep (11, 1.00) | 0.02 | 0.00 | 0.00 | 0.19 / 0.81 / 0.00 |
| A07_ort | 0 | ✅ | ✅ | `Graz` | 2 | 1508 | ids | `Graz` (115, 0.97) › keep (12, 1.00) | 0.02 | 0.00 | 0.01 | 0.13 / 0.87 / 0.00 |
| A07_ort | 1 | ✅ | ✅ | `Graz` | 2 | 1216 | ids | `Graz` (115, 0.97) › keep (12, 1.00) | 0.03 | 0.00 | 0.00 | 0.14 / 0.86 / 0.00 |
| A08_land | 0 | ✅ | ✅ | `Österreich` | 2 | 1658 | ids | `Österreich` (115, 0.97) › keep (55, 0.96) | 0.02 | 0.03 | 0.00 | 0.11 / 0.89 / 0.00 |
| A08_land | 1 | ✅ | ✅ | `Österreich` | 2 | 884 | ids | `Österreich` (115, 0.98) › keep (55, 0.97) | 0.02 | 0.03 | 0.00 | 0.13 / 0.87 / 0.00 |
| A09_email | 0 | ✅ | ✅ | `mira.holzner@example.org` | 2 | 1150 | ids | `mira.holzner@example.o…` (115, 0.92) › keep (34, 1.00) | 0.04 | 0.00 | 0.00 | 0.20 / 0.80 / 0.00 |
| A09_email | 1 | ✅ | ✅ | `mira.holzner@example.org` | 2 | 1702 | ids | `mira.holzner@example.o…` (115, 0.90) › keep (34, 1.00) | 0.03 | 0.00 | 0.01 | 0.18 / 0.82 / 0.00 |
| A10_website | 0 | ✅ | ✅ | `https://www.miraholzner.example` | 2 | 1255 | ids | `https://www.miraholzne…` (115, 0.91) › keep (55, 0.94) | 0.03 | 0.00 | 0.02 | 0.15 / 0.85 / 0.00 |
| A10_website | 1 | ✅ | ✅ | `https://www.miraholzner.example` | 2 | 967 | ids | `https://www.miraholzne…` (115, 0.92) › keep (55, 0.95) | 0.02 | 0.00 | 0.02 | 0.16 / 0.84 / 0.00 |
| A11_telefon | 0 | ✅ | ✅ | `06608405534` | 2 | 904 | ids | `06608405534` (115, 0.97) › keep (63, 0.94) | 0.03 | 0.00 | 0.02 | 0.18 / 0.82 / 0.00 |
| A11_telefon | 1 | ✅ | ✅ | `06608405534` | 2 | 1576 | ids | `06608405534` (115, 0.97) › keep (63, 0.91) | 0.03 | 0.00 | 0.03 | 0.14 / 0.86 / 0.00 |
| A12_strasse_hnr | 0 | ✅ | ✅ | `Prankergasse 77` | 2 | 1162 | ids | `Prankergasse 77` (115, 0.55) › keep (17, 0.97) | 0.03 | 0.03 | 0.12 | 0.25 / 0.75 / 0.00 |
| A12_strasse_hnr | 1 | ✅ | ✅ | `Prankergasse 77` | 2 | 1182 | ids | `Prankergasse 77` (115, 0.60) › keep (17, 0.97) | 0.03 | 0.02 | 0.15 | 0.30 / 0.70 / 0.00 |
| A13_passwort_NEG | 0 | ✅ | ✅ | nothing | 1 | 760 | ids | nothing_fits (115, 0.71) | 0.15 | 0.71 | 0.04 | 0.38 / 0.04 / 0.58 |
| A13_passwort_NEG | 1 | ✅ | ✅ | nothing | 1 | 553 | ids | nothing_fits (115, 0.94) | 0.04 | 0.94 | 0.01 | 0.06 / 0.01 / 0.93 |
| A14_fax_NEG | 0 | ✅ | ✅ | nothing | 1 | 631 | ids | nothing_fits (115, 0.93) | 0.05 | 0.93 | 0.00 | 0.10 / 0.05 / 0.85 |
| A14_fax_NEG | 1 | ✅ | ✅ | nothing | 1 | 477 | ids | nothing_fits (115, 0.89) | 0.07 | 0.89 | 0.02 | 0.11 / 0.04 / 0.85 |
| S01_first_name | 0 | ✅ | ✅ | `Jonas` | 2 | 1054 | ids | `Jonas` (186, 0.95) › keep (17, 0.99) | 0.02 | 0.00 | 0.01 | 0.20 / 0.80 / 0.00 |
| S01_first_name | 1 | ✅ | ✅ | `Jonas` | 2 | 1298 | ids | `Jonas` (186, 0.94) › keep (17, 1.00) | 0.01 | 0.00 | 0.01 | 0.25 / 0.75 / 0.00 |
| S02_last_name | 0 | ✅ | ✅ | `Prell` | 2 | 1145 | ids | `Prell` (186, 0.90) › keep (16, 1.00) | 0.04 | 0.02 | 0.03 | 0.17 / 0.83 / 0.00 |
| S02_last_name | 1 | ✅ | ✅ | `Prell` | 2 | 996 | ids | `Prell` (186, 0.87) › keep (16, 1.00) | 0.04 | 0.02 | 0.04 | 0.16 / 0.84 / 0.00 |
| S03_job_title | 0 | ✅ | ✅ | `Product Lead` | 2 | 1492 | ids | `Product Lead` (186, 0.87) › keep (14, 0.98) | 0.05 | 0.00 | 0.03 | 0.26 / 0.73 / 0.01 |
| S03_job_title | 1 | ✅ | ✅ | `Product Lead` | 2 | 986 | ids | `Product Lead` (186, 0.89) › keep (14, 1.00) | 0.03 | 0.02 | 0.03 | 0.12 / 0.88 / 0.00 |
| S04_phone | 0 | ✅ | ✅ | `+43 1 2345678` | 3 | 2731 | ids | `Phone +43 1 2345678` (186, 0.81) › `+43 1 2345678` (27, 0.90) › keep (18, 0.99) | 0.03 | 0.02 | 0.07 | 0.16 / 0.84 / 0.00 |
| S04_phone | 1 | ✅ | ✅ | `+43 1 2345678` | 3 | 1486 | ids | `Phone +43 1 2345678` (186, 0.79) › `+43 1 2345678` (27, 0.93) › keep (18, 0.99) | 0.03 | 0.02 | 0.08 | 0.15 / 0.85 / 0.00 |
| S05_mobile | 0 | ✅ | ✅ | `+43 660 1112233` | 2 | 1193 | ids | `+43 660 1112233` (186, 0.93) › keep (18, 0.98) | 0.01 | 0.00 | 0.01 | 0.14 / 0.86 / 0.00 |
| S05_mobile | 1 | ✅ | ✅ | `+43 660 1112233` | 2 | 1008 | ids | `+43 660 1112233` (186, 0.94) › keep (18, 0.99) | 0.01 | 0.00 | 0.01 | 0.17 / 0.83 / 0.00 |
| S06_email | 0 | ✅ | ✅ | `jonas.prell@example.com` | 2 | 1536 | ids | `jonas.prell@example.co…` (186, 0.84) › keep (35, 1.00) | 0.06 | 0.02 | 0.03 | 0.35 / 0.64 / 0.01 |
| S06_email | 1 | ✅ | ✅ | `jonas.prell@example.com` | 2 | 1089 | ids | `jonas.prell@example.co…` (186, 0.97) › keep (35, 1.00) | 0.02 | 0.00 | 0.01 | 0.16 / 0.84 / 0.00 |
| S07_website | 0 | ✅ | ✅ | `www.prell.example` | 2 | 1220 | ids | `www.prell.example` (186, 0.89) › keep (24, 0.97) | 0.04 | 0.00 | 0.03 | 0.39 / 0.60 / 0.01 |
| S07_website | 1 | ✅ | ✅ | `www.prell.example` | 2 | 1432 | ids | `www.prell.example` (186, 0.97) › keep (24, 0.99) | 0.02 | 0.00 | 0.00 | 0.13 / 0.87 / 0.00 |
| S08_iban | 0 | ✅ | ✅ | `AT61 1904 3002 3457 3201` | 2 | 1410 | ids | `AT61 1904 3002 3457 32…` (186, 0.64) › keep (23, 0.99) | 0.01 | 0.00 | 0.03 | 0.16 / 0.84 / 0.00 |
| S08_iban | 1 | ✅ | ✅ | `AT61 1904 3002 3457 3201` | 2 | 1233 | ids | `AT61 1904 3002 3457 32…` (186, 0.75) › keep (23, 1.00) | 0.02 | 0.00 | 0.04 | 0.15 / 0.85 / 0.00 |
| S09_fax_NEG | 0 | ✅ | ✅ | nothing | 1 | 886 | ids | nothing_fits (186, 0.91) | 0.05 | 0.91 | 0.00 | 0.05 / 0.02 / 0.93 |
| S09_fax_NEG | 1 | ✅ | ✅ | nothing | 1 | 532 | ids | nothing_fits (186, 0.92) | 0.05 | 0.92 | 0.00 | 0.06 / 0.02 / 0.92 |
| R01_full_name | 0 | ✅ | ✅ | `Anna Reisinger` | 2 | 1299 | ids | `Anna Reisinger` (6/3, 0.95) › keep (16, 0.99, spec) | 0.02 | 0.00 | 0.02 | 0.11 / 0.89 / 0.00 |
| R01_full_name | 1 | ✅ | ✅ | `Anna Reisinger` | 2 | 1029 | ids | `Anna Reisinger` (6/3, 0.94) › keep (16, 0.98, spec) | 0.02 | 0.00 | 0.02 | 0.08 / 0.92 / 0.00 |
| R02_birthdate | 0 | ✅ | ✅ | `14 March 1991` | 2 | 1446 | ids | `14 March 1991` (53/3, 0.89) › keep (12, 0.97, spec) | 0.01 | 0.03 | 0.06 | 0.09 / 0.91 / 0.00 |
| R02_birthdate | 1 | ✅ | ✅ | `14 March 1991` | 2 | 1357 | ids | `14 March 1991` (50/3, 0.88) › keep (12, 0.97, spec) | 0.02 | 0.01 | 0.09 | 0.08 / 0.91 / 0.01 |
| R03_birthplace | 0 | ✅ | ✅ | `Linz` | 2 | 1311 | ids | `Linz` (31/3, 0.95) › keep (12, 0.99, spec) | 0.02 | 0.01 | 0.03 | 0.09 / 0.91 / 0.00 |
| R03_birthplace | 1 | ✅ | ✅ | `Linz` | 2 | 1147 | ids | `Linz` (31/3, 0.94) › keep (12, 0.98, spec) | 0.02 | 0.01 | 0.03 | 0.07 / 0.93 / 0.00 |
| R04_nationality | 0 | ✅ | ✅ | `Austrian` | 2 | 1016 | ids | `Austrian` (17/3, 0.89) › keep (38, 0.96, spec) | 0.01 | 0.01 | 0.07 | 0.06 / 0.94 / 0.00 |
| R04_nationality | 1 | ✅ | ✅ | `Austrian` | 2 | 1217 | ids | `Austrian` (12/3, 0.81) › keep (38, 0.94, spec) | 0.00 | 0.01 | 0.14 | 0.06 / 0.94 / 0.00 |
| R05_about | 0 | ✅ | ✅ | `Data engineer with eight years of …` | 2 | 1133 | ids | `Data engineer with eig…` (65/3, 0.55) › keep (255, 0.85, spec) | 0.16 | 0.05 | 0.08 | 0.25 / 0.75 / 0.00 |
| R05_about | 1 | ✅ | ✅ | `Data engineer with eight years of …` | 2 | 1608 | ids | `Data engineer with eig…` (71/3, 0.49) › keep (255, 0.79, spec) | 0.15 | 0.07 | 0.08 | 0.24 / 0.76 / 0.00 |
| R06_country | 0 | ✅ | ✅ | `Austria` | 2 | 1042 | ids | `Austria` (39/3, 0.86) › keep (30, 0.95, spec) | 0.05 | 0.03 | 0.05 | 0.11 / 0.80 / 0.09 |
| R06_country | 1 | ✅ | ✅ | `Austria` | 2 | 1095 | ids | `Austria` (45/3, 0.77) › keep (30, 0.95, spec) | 0.07 | 0.03 | 0.10 | 0.16 / 0.75 / 0.09 |
| R07_linkedin_NEG | 0 | ✅ | ✅ | nothing | 1 | 745 | ids | nothing_fits (255/3, 0.82) | 0.09 | 0.82 | 0.02 | 0.11 / 0.00 / 0.89 |
| R07_linkedin_NEG | 1 | ✅ | ✅ | nothing | 1 | 676 | ids | nothing_fits (255/3, 0.86) | 0.04 | 0.86 | 0.02 | 0.02 / 0.01 / 0.97 |
| R08_summary | 0 | ✅ | ✅ | `Data engineer with eight years of …` | 2 | 1398 | ids | `Data engineer with eig…` (52/3, 0.49) › keep (255, 0.81, spec) | 0.15 | 0.13 | 0.09 | 0.24 / 0.76 / 0.00 |
| R08_summary | 1 | ✅ | ✅ | `Data engineer with eight years of …` | 2 | 1705 | ids | `Data engineer with eig…` (55/3, 0.65) › keep (255, 0.87, spec) | 0.09 | 0.02 | 0.06 | 0.24 / 0.76 / 0.00 |
| R09_biography | 0 | ✅ | ✅ | `Data engineer with eight years of …` | 2 | 1853 | ids | `Data engineer with eig…` (71/3, 0.37) › keep (255, 0.66, spec) | 0.14 | 0.15 | 0.06 | 0.22 / 0.78 / 0.00 |
| R09_biography | 1 | ✅ | ✅ | `Data engineer with eight years of …` | 2 | 1483 | ids | `Data engineer with eig…` (69/3, 0.29) › keep (255, 0.63, spec) | 0.19 | 0.09 | 0.07 | 0.24 / 0.76 / 0.00 |
| R10_description | 0 | ❌ | ❌ | `Anna Reisinger⏎Born 14 March 1991 …` | 1 | 668 | ids | keep (255/3, 0.37) | 0.37 | 0.04 | 0.02 | 0.50 / 0.50 / 0.00 |
| R10_description | 1 | ❌ | ❌ | `Anna Reisinger⏎Born 14 March 1991 …` | 1 | 695 | ids | keep (255/3, 0.30) | 0.30 | 0.05 | 0.02 | 0.50 / 0.50 / 0.00 |
| O01_email | 0 | ✅ | ✅ | `wren.castellan@example.net` | 2 | 1081 | ids | `wren.castellan@example…` (151, 0.95) › keep (34, 1.00) | 0.03 | 0.00 | 0.00 | 0.12 / 0.88 / 0.00 |
| O01_email | 1 | ✅ | ✅ | `wren.castellan@example.net` | 2 | 1213 | ids | `wren.castellan@example…` (151, 0.96) › keep (34, 1.00) | 0.02 | 0.00 | 0.00 | 0.32 / 0.67 / 0.01 |
| O02_order_number | 0 | ✅ | ✅ | `4711` | 2 | 923 | ids | `4711` (151, 0.46) › keep (11, 1.00) | 0.05 | 0.03 | 0.10 | 0.14 / 0.86 / 0.00 |
| O02_order_number | 1 | ✅ | ✅ | `4711` | 2 | 1068 | ids | `4711` (151, 0.42) › keep (11, 1.00) | 0.05 | 0.03 | 0.10 | 0.13 / 0.87 / 0.00 |
| O03_recipient | 0 | ✅ | ✅ | `Lise Adler` | 2 | 1310 | ids | `Lise Adler` (151, 0.90) › keep (12, 1.00) | 0.03 | 0.00 | 0.02 | 0.15 / 0.85 / 0.00 |
| O03_recipient | 1 | ✅ | ✅ | `Lise Adler` | 2 | 980 | ids | `Lise Adler` (151, 0.87) › keep (12, 1.00) | 0.04 | 0.00 | 0.03 | 0.13 / 0.87 / 0.00 |
| O04_street | 0 | ✅ | ✅ | `Hauptstr. 5` | 2 | 979 | ids | `Hauptstr. 5` (151, 0.47) › keep (15, 0.92) | 0.04 | 0.02 | 0.02 | 0.13 / 0.87 / 0.00 |
| O04_street | 1 | ✅ | ✅ | `Hauptstr. 5` | 2 | 915 | ids | `Hauptstr. 5` (151, 0.57) › keep (15, 0.95) | 0.04 | 0.01 | 0.03 | 0.13 / 0.87 / 0.00 |
| O05_postal_code | 0 | ✅ | ✅ | `4020` | 2 | 1063 | ids | `4020` (151, 0.90) › keep (11, 1.00) | 0.04 | 0.00 | 0.03 | 0.11 / 0.88 / 0.01 |
| O05_postal_code | 1 | ✅ | ✅ | `4020` | 2 | 976 | ids | `4020` (151, 0.90) › keep (11, 1.00) | 0.05 | 0.00 | 0.02 | 0.11 / 0.89 / 0.00 |
| O06_city | 0 | ✅ | ✅ | `Linz` | 2 | 1222 | ids | `Linz` (151, 0.95) › keep (12, 1.00) | 0.03 | 0.00 | 0.02 | 0.12 / 0.88 / 0.00 |
| O06_city | 1 | ✅ | ✅ | `Linz` | 2 | 993 | ids | `Linz` (151, 0.94) › keep (12, 1.00) | 0.03 | 0.00 | 0.02 | 0.10 / 0.90 / 0.00 |
| O07_amount | 0 | ✅ | ✅ | `129,90` | 2 | 1430 | ids | `129,90` (151, 0.50) › keep (11, 0.95) | 0.06 | 0.02 | 0.03 | 0.42 / 0.55 / 0.03 |
| O07_amount | 1 | ✅ | ✅ | `129,90` | 2 | 935 | ids | `129,90` (151, 0.79) › keep (11, 0.97) | 0.05 | 0.02 | 0.02 | 0.11 / 0.89 / 0.00 |
| O08_tracking | 0 | ✅ | ✅ | `00340434161234567890` | 2 | 970 | ids | `00340434161234567890` (151, 0.92) › keep (200, 0.88) | 0.02 | 0.02 | 0.02 | 0.10 / 0.90 / 0.00 |
| O08_tracking | 1 | ✅ | ✅ | `00340434161234567890` | 2 | 917 | ids | `00340434161234567890` (151, 0.93) › keep (200, 0.91) | 0.01 | 0.02 | 0.02 | 0.11 / 0.89 / 0.00 |
| O09_coupon_NEG | 0 | ✅ | ✅ | nothing | 1 | 538 | ids | nothing_fits (151, 0.67) | 0.14 | 0.67 | 0.02 | 0.08 / 0.06 / 0.86 |
| O09_coupon_NEG | 1 | ✅ | ✅ | nothing | 1 | 483 | ids | nothing_fits (151, 0.69) | 0.14 | 0.69 | 0.02 | 0.09 / 0.06 / 0.85 |
| B01_handle | 0 | ✅ | ✅ | `@mira_h` | 2 | 1198 | ids | `@mira_h` (34/2, 0.89) › keep (12, 0.73, spec) | 0.01 | 0.01 | 0.09 | 0.10 / 0.90 / 0.00 |
| B01_handle | 1 | ✅ | ✅ | `@mira_h` | 2 | 1170 | ids | `@mira_h` (30/2, 0.87) › keep (12, 0.82, spec) | 0.01 | 0.01 | 0.10 | 0.08 / 0.92 / 0.00 |
| B02_city | 0 | ✅ | ✅ | `Innsbruck` | 2 | 1439 | ids | `Innsbruck` (42/2, 0.93) › keep (46, 0.99, spec) | 0.02 | 0.00 | 0.04 | 0.12 / 0.88 / 0.00 |
| B02_city | 1 | ✅ | ✅ | `Innsbruck` | 2 | 1251 | ids | `Innsbruck` (42/2, 0.90) › keep (46, 0.99, spec) | 0.01 | 0.02 | 0.05 | 0.10 / 0.89 / 0.01 |
| B03_bio | 0 | ✅ | ✅ | `Hi, I'm Lena Vogt, a ceramicist wo…` | 1 | 591 | ids | keep (255/2, 0.52) | 0.52 | 0.02 | 0.02 | 0.75 / 0.25 / 0.00 |
| B03_bio | 1 | ✅ | ✅ | `Hi, I'm Lena Vogt, a ceramicist wo…` | 1 | 605 | ids | keep (255/2, 0.53) | 0.53 | 0.02 | 0.02 | 0.68 / 0.32 / 0.00 |
| B04_birth_year | 0 | ✅ | ✅ | `1994` | 2 | 1142 | ids | `1994` (53/2, 0.90) › keep (11, 1.00, spec) | 0.03 | 0.00 | 0.03 | 0.22 / 0.74 / 0.04 |
| B04_birth_year | 1 | ✅ | ✅ | `1994` | 2 | 1076 | ids | `1994` (45/2, 0.91) › keep (11, 1.00, spec) | 0.00 | 0.00 | 0.06 | 0.09 / 0.91 / 0.00 |
| B05_phone_NEG | 0 | ✅ | ✅ | nothing | 1 | 637 | ids | nothing_fits (255/2, 0.63) | 0.13 | 0.63 | 0.02 | 0.06 / 0.05 / 0.89 |
| B05_phone_NEG | 1 | ✅ | ✅ | nothing | 1 | 640 | ids | nothing_fits (255/2, 0.62) | 0.14 | 0.62 | 0.02 | 0.06 / 0.04 / 0.90 |
| B06_biography | 0 | ❌ | ✅ | nothing | 2 | 1153 | ids | nothing_fits (61/2, 0.38) | 0.30 | 0.38 | 0.03 | 0.57 / 0.42 / 0.01 |
| B06_biography | 1 | ❌ | ❌ | nothing | 1 | 565 | ids | nothing_fits (255/2, 0.22) | 0.21 | 0.22 | 0.03 | 0.47 / 0.52 / 0.01 |
| B07_about_me | 0 | ✅ | ✅ | `Hi, I'm Lena Vogt, a ceramicist wo…` | 1 | 831 | ids | keep (255/2, 0.58) | 0.58 | 0.02 | 0.02 | 0.83 / 0.17 / 0.00 |
| B07_about_me | 1 | ✅ | ✅ | `Hi, I'm Lena Vogt, a ceramicist wo…` | 1 | 560 | ids | keep (255/2, 0.60) | 0.60 | 0.00 | 0.02 | 0.87 / 0.13 / 0.00 |
| B08_short_bio | 0 | ✅ | ✅ | `Hi, I'm Lena Vogt, a ceramicist wo…` | 2 | 1288 | ids | keep (67/2, 0.29) | 0.29 | 0.06 | 0.15 | 0.28 / 0.72 / 0.00 |
| B08_short_bio | 1 | ✅ | ✅ | `Hi, I'm Lena Vogt, a ceramicist wo…` | 2 | 1291 | ids | keep (73/2, 0.18) | 0.18 | 0.12 | 0.15 | 0.35 / 0.65 / 0.00 |
| T01_email_two_lines | 0 | ✅ | ✅ | ask → [`Ticket 4711 wren.castell…`, `wren.castellan@example.n…`, `Ticket 4711 wren.castell…`, `lise.adler@example.net`] | 1 | 509 | ids | ask_user (84, 0.60) | 0.12 | 0.04 | 0.60 | 0.41 / 0.59 / 0.00 |
| T01_email_two_lines | 1 | ✅ | ✅ | ask → [`wren.castellan@example.n…`, `Ticket 4711 wren.castell…`, `Ticket 4711 wren.castell…`, `lise.adler@example.net`] | 1 | 498 | ids | ask_user (84, 0.66) | 0.09 | 0.03 | 0.66 | 0.36 / 0.64 / 0.00 |
| C01_cover_letter | 0 | ✅ | ✅ | `Dear Ms Hofer,⏎⏎I am writing to ap…` | 1 | 1404 | ids | keep (255/3, 0.65) | 0.65 | 0.02 | 0.02 | 0.85 / 0.15 / 0.00 |
| C01_cover_letter | 1 | ✅ | ✅ | `Dear Ms Hofer,⏎⏎I am writing to ap…` | 1 | 591 | ids | keep (255/3, 0.64) | 0.64 | 0.03 | 0.03 | 0.85 / 0.15 / 0.00 |
| C02_motivation | 0 | ✅ | ✅ | `What draws me to Grünraum is your …` | 3 | 2241 | ids | `What draws me to Grünr…` (73/3, 0.67) › keep (255/2, 0.69) | 0.08 | 0.04 | 0.03 | 0.25 / 0.75 / 0.00 |
| C02_motivation | 1 | ✅ | ✅ | `What draws me to Grünraum is your …` | 3 | 1664 | ids | `What draws me to Grünr…` (72/3, 0.54) › keep (255/2, 0.65) | 0.09 | 0.03 | 0.09 | 0.21 / 0.79 / 0.00 |
| C03_availability | 0 | ❌ | ❌ | `I can start on 1 December 2026 and…` | 2 | 1344 | ids | `I can start on 1 Decem…` (62/3, 0.39) › keep (154, 0.70, spec) | 0.13 | 0.03 | 0.15 | 0.27 / 0.72 / 0.01 |
| C03_availability | 1 | ❌ | ❌ | `I can start on 1 December 2026 and…` | 2 | 1240 | ids | `I can start on 1 Decem…` (63/3, 0.38) › keep (154, 0.69, spec) | 0.14 | 0.06 | 0.10 | 0.20 / 0.79 / 0.01 |
| C04_name | 0 | ❌ | ❌ | `Dear Ms Hofer,⏎⏎I am writing to ap…` | 2 | 1624 | ids | keep (69/3, 0.44) | 0.44 | 0.06 | 0.05 | 0.18 / 0.81 / 0.01 |
| C04_name | 1 | ✅ | ✅ | `Theo Brandner` | 2 | 1308 | ids | `Theo Brandner` (78/3, 0.45) › keep (15, 0.97, spec) | 0.27 | 0.04 | 0.03 | 0.20 / 0.78 / 0.02 |
| C05_notes_freetext | 0 | ✅ | ✅ | `Dear Ms Hofer,⏎⏎I am writing to ap…` | 1 | 1006 | ids | keep (255/3, 0.54) | 0.54 | 0.04 | 0.03 | 0.78 / 0.18 / 0.04 |
| C05_notes_freetext | 1 | ✅ | ✅ | `Dear Ms Hofer,⏎⏎I am writing to ap…` | 1 | 796 | ids | keep (255/3, 0.53) | 0.53 | 0.05 | 0.03 | 0.74 / 0.20 / 0.06 |
| W01_chrome_textarea | 0 | ✅ | ✅ | `Marlene Oberholzer⏎marlene.oberhol…` | 1 | 665 | ids | keep (255/2, 0.46) | 0.46 | 0.07 | 0.03 | 0.76 / 0.19 / 0.05 |
| W01_chrome_textarea | 1 | ✅ | ✅ | `Marlene Oberholzer⏎marlene.oberhol…` | 1 | 731 | ids | keep (255/2, 0.66) | 0.66 | 0.07 | 0.04 | 0.88 / 0.07 / 0.05 |
| W02_terminal_prompt | 0 | ✅ | ✅ | `Marlene Oberholzer⏎marlene.oberhol…` | 1 | 629 | ids | keep (255/2, 0.76) | 0.76 | 0.03 | 0.00 | 0.90 / 0.02 / 0.08 |
| W02_terminal_prompt | 1 | ✅ | ✅ | `Marlene Oberholzer⏎marlene.oberhol…` | 1 | 643 | ids | keep (255/2, 0.76) | 0.76 | 0.03 | 0.00 | 0.92 / 0.02 / 0.06 |
| W03_chatgpt_composer | 0 | ✅ | ✅ | `Marlene Oberholzer⏎marlene.oberhol…` | 1 | 736 | ids | keep (255/2, 0.43) | 0.43 | 0.02 | 0.03 | 0.58 / 0.42 / 0.00 |
| W03_chatgpt_composer | 1 | ✅ | ✅ | `Marlene Oberholzer⏎marlene.oberhol…` | 1 | 785 | ids | keep (255/2, 0.45) | 0.45 | 0.02 | 0.04 | 0.56 / 0.44 / 0.00 |
| W04_whatsapp_composer | 0 | ✅ | ✅ | `Marlene Oberholzer⏎marlene.oberhol…` | 1 | 1049 | ids | keep (255/2, 0.44) | 0.44 | 0.02 | 0.14 | 0.82 / 0.15 / 0.03 |
| W04_whatsapp_composer | 1 | ✅ | ✅ | `Marlene Oberholzer⏎marlene.oberhol…` | 1 | 544 | ids | keep (255/2, 0.43) | 0.43 | 0.03 | 0.07 | 0.70 / 0.29 / 0.01 |
| K01_three_emails | 0 | ✅ | ✅ | ask → [`marcus@anything.com`] | 1 | 683 | full | ask_user (255/3, 0.91) | 0.00 | 0.01 | 0.91 | 0.11 / 0.89 / 0.00 |
| K01_three_emails | 1 | ✅ | ✅ | ask → [`marcus@anything.com`] | 1 | 783 | full | ask_user (255/3, 0.90) | 0.00 | 0.01 | 0.90 | 0.20 / 0.79 / 0.01 |
| N01_address_line_ort | 0 | ✅ | ✅ | `Graz` | 2 | 1214 | ids | `Graz` (43, 0.98) › keep (12, 1.00) | 0.02 | 0.00 | 0.00 | 0.10 / 0.90 / 0.00 |
| N01_address_line_ort | 1 | ✅ | ✅ | `Graz` | 2 | 944 | ids | `Graz` (43, 0.98) › keep (12, 1.00) | 0.00 | 0.00 | 0.02 | 0.09 / 0.91 / 0.00 |
| N02_url_chat | 0 | ✅ | ❌ | `https://www.miraholzner.example/po…` | 1 | 578 | ids | keep (235, 0.45) | 0.45 | 0.20 | 0.02 | 0.24 / 0.06 / 0.70 |
| N02_url_chat | 1 | ✅ | ❌ | `https://www.miraholzner.example/po…` | 1 | 592 | ids | keep (235, 0.47) | 0.47 | 0.21 | 0.02 | 0.33 / 0.05 / 0.62 |
| N03_list_300_lines | 0 | ✅ | ✅ | `WINTER-4471-KQ` | 4 | 3421 | full,ids | `2026-09-12 12:41:02 IN…` (13/2, 0.61) › `WINTER-4471-KQ` (44/2, 0.79) › keep (22, 0.92, spec) | 0.17 | 0.18 | 0.04 | 0.25 / 0.50 / 0.25 |
| N03_list_300_lines | 1 | ✅ | ✅ | `WINTER-4471-KQ` | 4 | 3221 | full,ids | `2026-09-12 12:41:02 IN…` (16/2, 0.55) › `WINTER-4471-KQ` (48/2, 0.88) › keep (22, 0.94, spec) | 0.19 | 0.19 | 0.03 | 0.17 / 0.57 / 0.26 |
| N04_too_big | 0 | ✅ | ✅ | error 400 | 1 | 1559 | full |  | 0.00 | 0.00 | 0.00 | 0.00 / 0.00 / 0.00 |
| N04_too_big | 1 | ✅ | ✅ | error 400 | 1 | 1700 | full |  | 0.00 | 0.00 | 0.00 | 0.00 / 0.00 / 0.00 |
| H01_flat_full_name | 0 | ✅ | ✅ | `Katrin Lechner` | 2 | 1316 | ids | `Katrin Lechner` (21/3, 0.95) › keep (16, 0.98, spec) | 0.02 | 0.01 | 0.02 | 0.13 / 0.86 / 0.01 |
| H01_flat_full_name | 1 | ✅ | ✅ | `Katrin Lechner` | 2 | 1261 | ids | `Katrin Lechner` (17/3, 0.90) › keep (16, 0.98, spec) | 0.03 | 0.00 | 0.06 | 0.14 / 0.85 / 0.01 |
| H02_flat_move_in | 0 | ✅ | ✅ | `1 March 2027` | 2 | 1197 | ids | `1 March 2027` (67/3, 0.68) › keep (11, 0.94, spec) | 0.01 | 0.01 | 0.24 | 0.12 / 0.87 / 0.01 |
| H02_flat_move_in | 1 | ✅ | ✅ | `1 March 2027` | 2 | 1356 | ids | `1 March 2027` (67/3, 0.65) › keep (11, 0.95, spec) | 0.01 | 0.01 | 0.25 | 0.12 / 0.88 / 0.00 |
| H03_event_city | 0 | ✅ | ✅ | `Villach` | 2 | 1894 | ids | `Villach` (36/2, 0.96) › keep (29, 0.99, spec) | 0.01 | 0.01 | 0.02 | 0.23 / 0.74 / 0.03 |
| H03_event_city | 1 | ✅ | ✅ | `Villach` | 2 | 1089 | ids | `Villach` (27/2, 0.97) › keep (29, 0.99, spec) | 0.02 | 0.00 | 0.01 | 0.14 / 0.86 / 0.00 |
| H04_issue_comment | 0 | ✅ | ✅ | `Brunner Holzbau GmbH⏎office@brunne…` | 1 | 574 | ids | keep (255/2, 0.43) | 0.43 | 0.02 | 0.13 | 0.82 / 0.18 / 0.00 |
| H04_issue_comment | 1 | ✅ | ✅ | `Brunner Holzbau GmbH⏎office@brunne…` | 1 | 684 | ids | keep (255/2, 0.42) | 0.42 | 0.03 | 0.16 | 0.83 / 0.17 / 0.00 |
| H05_messages_composer | 0 | ✅ | ✅ | `Brunner Holzbau GmbH⏎office@brunne…` | 1 | 849 | ids | keep (255/2, 0.23) | 0.23 | 0.02 | 0.14 | 0.75 / 0.25 / 0.00 |
| H05_messages_composer | 1 | ✅ | ✅ | `Brunner Holzbau GmbH⏎office@brunne…` | 1 | 891 | ids | keep (255/2, 0.22) | 0.22 | 0.02 | 0.14 | 0.78 / 0.22 / 0.00 |
| H06_company_description | 0 | ✅ | ✅ | `Family carpentry workshop in its t…` | 3 | 1945 | full,ids | `Family carpentry works…` (18/2, 0.93) › keep (255/4, 0.59) | 0.03 | 0.02 | 0.03 | 0.19 / 0.81 / 0.00 |
| H06_company_description | 1 | ✅ | ✅ | `Family carpentry workshop in its t…` | 3 | 2237 | full,ids | `Family carpentry works…` (16/2, 0.90) › keep (255/4, 0.56) | 0.06 | 0.02 | 0.02 | 0.14 / 0.86 / 0.00 |
| H07_url_slack | 0 | ✅ | ✅ | `https://docs.northbeam.example/run…` | 1 | 799 | ids | keep (255/2, 0.44) | 0.44 | 0.04 | 0.04 | 0.66 / 0.33 / 0.01 |
| H07_url_slack | 1 | ✅ | ✅ | `https://docs.northbeam.example/run…` | 1 | 514 | ids | keep (255/2, 0.37) | 0.37 | 0.04 | 0.04 | 0.66 / 0.33 / 0.01 |
| H08_url_teams | 0 | ✅ | ✅ | `https://www.kofler-keramik.example…` | 1 | 588 | ids | keep (255/2, 0.60) | 0.60 | 0.02 | 0.03 | 0.72 / 0.28 / 0.00 |
| H08_url_teams | 1 | ✅ | ✅ | `https://www.kofler-keramik.example…` | 1 | 548 | ids | keep (255/2, 0.59) | 0.59 | 0.02 | 0.02 | 0.73 / 0.27 / 0.00 |
| H09_three_emails_webinar | 0 | ✅ | ✅ | ask → [`Dr. Elif Sommer⏎Senior R…`, `elif.sommer@climatelab.e…`, `Dr. Elif Sommer⏎Senior R…`] | 1 | 584 | ids | ask_user (164, 0.87) | 0.02 | 0.00 | 0.87 | 0.19 / 0.81 / 0.00 |
| H09_three_emails_webinar | 1 | ✅ | ✅ | ask → [`Dr. Elif Sommer⏎Senior R…`, `elif.sommer@climatelab.e…`, `Dr. Elif Sommer⏎Senior R…`, `2041`] | 1 | 476 | ids | ask_user (164, 0.88) | 0.02 | 0.00 | 0.88 | 0.17 / 0.83 / 0.00 |
| H10_three_emails_folio | 0 | ✅ | ✅ | ask → [`nikolai@vargastudio.exam…`, `Nikolai Varga⏎Illustrato…`, `Radio Mur`, `Radio`] | 1 | 966 | ids | ask_user (182, 0.86) | 0.00 | 0.00 | 0.86 | 0.20 / 0.80 / 0.00 |
| H10_three_emails_folio | 1 | ✅ | ✅ | ask → [`Nikolai Varga⏎Illustrato…`, `nikolai@vargastudio.exam…`, `Nikolai Varga⏎Illustrato…`, `Radio`] | 1 | 529 | ids | ask_user (182, 0.85) | 0.02 | 0.00 | 0.85 | 0.20 / 0.80 / 0.00 |
| H11_two_emails_catering | 0 | ✅ | ✅ | ask → [`rosa.hainz@stadtsaal-wel…`, `Rosa Hainz⏎Head of Event…`, `Rosa Hainz⏎Head of Event…`, `rosa.hainz@mailbox.examp…`] | 1 | 1357 | ids | ask_user (127, 0.54) | 0.02 | 0.00 | 0.54 | 0.39 / 0.61 / 0.00 |
| H11_two_emails_catering | 1 | ✅ | ✅ | ask → [`Rosa Hainz⏎Head of Event…`, `rosa.hainz@stadtsaal-wel…`, `Rosa Hainz⏎Head of Event…`, `12`] | 1 | 736 | ids | ask_user (127, 0.81) | 0.02 | 0.00 | 0.81 | 0.15 / 0.85 / 0.00 |
| H12_address_line_1 | 0 | ✅ | ✅ | `Kirchgasse 9` | 2 | 997 | ids | `Kirchgasse 9` (40, 0.50) › keep (14, 0.96) | 0.03 | 0.00 | 0.06 | 0.25 / 0.75 / 0.00 |
| H12_address_line_1 | 1 | ✅ | ✅ | `Kirchgasse 9` | 2 | 1030 | ids | `Kirchgasse 9` (40, 0.51) › keep (14, 0.96) | 0.03 | 0.00 | 0.05 | 0.23 / 0.77 / 0.00 |
| H13_strasse_hausnummer | 0 | ✅ | ✅ | `Leopoldstraße 41` | 2 | 1230 | ids | `Leopoldstraße 41` (42, 0.60) › keep (18, 0.99) | 0.01 | 0.00 | 0.15 | 0.18 / 0.82 / 0.00 |
| H13_strasse_hausnummer | 1 | ✅ | ✅ | `Leopoldstraße 41` | 2 | 1191 | ids | `Leopoldstraße 41` (42, 0.48) › keep (18, 0.99) | 0.02 | 0.00 | 0.17 | 0.21 / 0.79 / 0.00 |
| H14_empfaenger | 0 | ✅ | ✅ | `Brunner Holzbau GmbH` | 3 | 1492 | ids | `Rechnung Nr. 2027-0142…` (132, 0.36) › `Brunner Holzbau GmbH` (34, 0.95) › keep (17, 0.99) | 0.03 | 0.00 | 0.10 | 0.21 / 0.79 / 0.00 |
| H14_empfaenger | 1 | ✅ | ✅ | `Brunner Holzbau GmbH` | 2 | 1020 | ids | `Brunner Holzbau GmbH` (132, 0.47) › keep (17, 0.99) | 0.05 | 0.00 | 0.04 | 0.23 / 0.77 / 0.00 |
| H15_mobile | 0 | ✅ | ✅ | `+43 664 918 2735` | 2 | 1004 | ids | `+43 664 918 2735` (114, 0.56) › keep (20, 0.92) | 0.03 | 0.02 | 0.06 | 0.12 / 0.88 / 0.00 |
| H15_mobile | 1 | ✅ | ✅ | `+43 664 918 2735` | 2 | 945 | ids | `+43 664 918 2735` (114, 0.67) › keep (20, 0.92) | 0.03 | 0.01 | 0.03 | 0.12 / 0.88 / 0.00 |
| H16_postcode | 0 | ✅ | ✅ | `6020` | 2 | 853 | ids | `6020` (40, 0.98) › keep (11, 1.00) | 0.02 | 0.00 | 0.00 | 0.13 / 0.87 / 0.00 |
| H16_postcode | 1 | ✅ | ✅ | `6020` | 2 | 986 | ids | `6020` (40, 0.98) › keep (11, 1.00) | 0.02 | 0.00 | 0.00 | 0.14 / 0.86 / 0.00 |
| H17_birthday_NEG | 0 | ✅ | ✅ | nothing | 1 | 487 | ids | nothing_fits (114, 0.92) | 0.07 | 0.92 | 0.01 | 0.06 / 0.01 / 0.93 |
| H17_birthday_NEG | 1 | ✅ | ✅ | nothing | 1 | 549 | ids | nothing_fits (114, 0.91) | 0.07 | 0.91 | 0.02 | 0.04 / 0.01 / 0.95 |
| H18_phone_NEG | 0 | ✅ | ✅ | nothing | 1 | 832 | ids | nothing_fits (40, 0.95) | 0.03 | 0.95 | 0.02 | 0.03 / 0.01 / 0.96 |
| H18_phone_NEG | 1 | ✅ | ✅ | nothing | 1 | 425 | ids | nothing_fits (40, 0.94) | 0.04 | 0.94 | 0.01 | 0.04 / 0.01 / 0.95 |

## Latency, calls, cost

- all, policy A: n=164, median 1028 ms, p90 1564 ms, max 3421 ms; calls mean 1.74.
- all, policy B: n=164, median 1023 ms, p90 1564 ms, max 3421 ms; calls mean 1.73.
- round-1 cells, policy A: n=128, median 1059 ms, p90 1586 ms, max 3421 ms; calls mean 1.78.
- round-1 cells, policy B: n=128, median 1052 ms, p90 1586 ms, max 3421 ms; calls mean 1.77.
- held-out, policy A: n=36, median 956 ms, p90 1425 ms, max 2237 ms; calls mean 1.58.
- held-out, policy B: n=36, median 956 ms, p90 1425 ms, max 2237 ms; calls mean 1.58.
  - 1 call(s): n=55, median 637 ms, p90 889 ms, max 1404 ms
  - 2 call(s): n=99, median 1162 ms, p90 1514 ms, max 1894 ms
  - 3 call(s): n=8, median 1818 ms, p90 2388 ms, max 2731 ms
  - 4 call(s): n=2, median 3321 ms, p90 3401 ms, max 3421 ms
- Per call: warm n=281 median 581 ms, p90 834 ms, max 1404 ms; cold (first call of a process) n=4, 818 ms, 499 ms, 1381 ms, 1182 ms.
- Calls per paste (A): distribution 1×57, 2×99, 3×8, 4×2; speculative next-step answers used: 33 times (each saved one call).
- Option form per request: {'ids': 279, 'full': 8} (full = fallback when the excerpts would overfill the state).
- Retry waits (429/503; pacing excluded): 106 waits, 2189 s in total (39 × 429, 67 × 503/5xx, 0 network).
- Single calls over 3 s: 0.
- Billed calls round 2: 526 (explore 140, matrix 285; budget 700, stop-and-ask 650); round 1 used 184 → spike total 710 (≤ 900). Round-2 input tokens 4820553; Gateway cost $0.2025.

