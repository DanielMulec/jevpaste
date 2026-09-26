# Round-2 matrix report (design `r2`, frozen at GATE A)

Pastes: 29 (round-1 cells 29, held-out 0). Both runs of every cell.

### Round-1 cells — policy A

| # | criterion | result |
|---|---|---|
| 1 | every positive cell hits (borderline reported, not gating) | **FAIL** — 22/23 pastes; misses: A04_hausnummer r0 → `7`. Borderline: 3/3 |
| 2 | every trap cell ends in No Suitable Match | PASS — 3/3 |
| 3 | whole copy in W01_chrome_textarea, W02_terminal_prompt, W03_chatgpt_composer, W04_whatsapp_composer, C05_notes_freetext; paragraph in R05_about, R08_summary, R10_description | PASS — 1/1 |
| 4 | chooser opens on T01_email_two_lines, K01_three_emails, nowhere else | PASS — opened 0/0; asks elsewhere: none |
| 5 | every paste byte-exact | PASS — 29/29 |
| 6 | median < 2 s, nothing > 5 s | PASS — median 1224 ms, p90 1789 ms, max 2003 ms (n=29) |
| 7 | new cells | N01_address_line_ort 0/0 (); N02_url_chat 0/0 (); N03_list_300_lines 0/0 (); N04_too_big 0/0 () |

### Held-out cells — policy A

| # | criterion | result |
|---|---|---|
| 1 | every positive cell hits (borderline reported, not gating) | PASS — 0/0 pastes. Borderline: 0/0 |
| 2 | every trap cell ends in No Suitable Match | PASS — 0/0 |
| 3 | whole copy in H04_issue_comment, H05_messages_composer; paragraph in H06_company_description | PASS — 0/0 |
| 4 | chooser opens on H09_three_emails_webinar, H10_three_emails_folio, H11_two_emails_catering, nowhere else | PASS — opened 0/0; asks elsewhere: none |
| 5 | every paste byte-exact | PASS — 0/0 |
| 7 | new cells | H07_url_slack 0/0 (); H08_url_teams 0/0 () |

### Round-1 cells — policy B

| # | criterion | result |
|---|---|---|
| 1 | every positive cell hits (borderline reported, not gating) | **FAIL** — 22/23 pastes; misses: A04_hausnummer r0 → `7`. Borderline: 2/3 (misses: R06_country r0 → nothing) |
| 2 | every trap cell ends in No Suitable Match | PASS — 3/3 |
| 3 | whole copy in W01_chrome_textarea, W02_terminal_prompt, W03_chatgpt_composer, W04_whatsapp_composer, C05_notes_freetext; paragraph in R05_about, R08_summary, R10_description | PASS — 1/1 |
| 4 | chooser opens on T01_email_two_lines, K01_three_emails, nowhere else | PASS — opened 0/0; asks elsewhere: none |
| 5 | every paste byte-exact | PASS — 29/29 |
| 6 | median < 2 s, nothing > 5 s | PASS — median 1205 ms, p90 1789 ms, max 2003 ms (n=29) |
| 7 | new cells | N01_address_line_ort 0/0 (); N02_url_chat 0/0 (); N03_list_300_lines 0/0 (); N04_too_big 0/0 () |

### Held-out cells — policy B

| # | criterion | result |
|---|---|---|
| 1 | every positive cell hits (borderline reported, not gating) | PASS — 0/0 pastes. Borderline: 0/0 |
| 2 | every trap cell ends in No Suitable Match | PASS — 0/0 |
| 3 | whole copy in H04_issue_comment, H05_messages_composer; paragraph in H06_company_description | PASS — 0/0 |
| 4 | chooser opens on H09_three_emails_webinar, H10_three_emails_folio, H11_two_emails_catering, nowhere else | PASS — opened 0/0; asks elsewhere: none |
| 5 | every paste byte-exact | PASS — 0/0 |
| 7 | new cells | H07_url_slack 0/0 (); H08_url_teams 0/0 () |

### Summary: failing criteria

- round-1, policy A: 1
- held-out, policy A: none
- round-1, policy B: 1
- held-out, policy B: none

## Every miss, with what Jev chose instead

| cell | run | policy | expected | pasted | steps (pick (options/choices, p)) | place (every/part/nothing) |
|---|---|---|---|---|---|---|
| A04_hausnummer | 0 | A | `77` | `7` | `77` (115, 0.86) › `7` (4, 0.54) | 0.32 / 0.67 / 0.01 |
| A04_hausnummer | 0 | B | `77` | `7` | `77` (115, 0.86) › `7` (4, 0.54) | 0.32 / 0.67 / 0.01 |
| R06_country ⚠ | 0 | B | `Austria` | nothing | `Austria` (60/3, 0.75) › keep (30, 0.92, spec) | 0.25 / 0.26 / 0.49 |

## Expectation questions for Daniel


## Per-paste table

Steps: `pick (options[/choices], p)`; `spec` = answered by a speculative question (no extra call). p(all) = p(everything / keep) of the deciding choice at step 1; max p(nothing) and p(ask) over steps.

| cell | run | A | B | pasted (A) | calls | ms | forms | steps | p(all) s1 | p(nothing) | p(ask) | place every/part/nothing |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A01_vorname | 0 | ✅ | ✅ | `Mira` | 2 | 1787 | ids | `Mira` (115, 0.89) › keep (12, 0.95) | 0.01 | 0.01 | 0.01 | 0.17 / 0.83 / 0.00 |
| A02_nachname | 0 | ✅ | ✅ | `Holzner` | 2 | 946 | ids | `Holzner` (115, 0.93) › keep (30, 0.92) | 0.02 | 0.01 | 0.01 | 0.16 / 0.84 / 0.00 |
| A03_strasse | 0 | ✅ | ✅ | `Prankergasse` | 3 | 1796 | ids | `Prankergasse 77` (115, 0.47) › `Prankergasse` (17, 0.75) › keep (76, 0.69) | 0.03 | 0.03 | 0.05 | 0.20 / 0.80 / 0.00 |
| A04_hausnummer | 0 | ❌ | ❌ | `7` | 2 | 1093 | ids | `77` (115, 0.86) › `7` (4, 0.54) | 0.06 | 0.00 | 0.03 | 0.32 / 0.67 / 0.01 |
| A05_adresszusatz | 0 | ✅ | ✅ | `Top 11` | 2 | 1027 | ids | `Top 11` (115, 0.82) › keep (8, 0.58) | 0.05 | 0.03 | 0.07 | 0.17 / 0.83 / 0.00 |
| A06_plz | 0 | ✅ | ✅ | `8020` | 2 | 1172 | ids | `8020` (115, 0.98) › keep (11, 0.99) | 0.02 | 0.00 | 0.00 | 0.19 / 0.81 / 0.00 |
| A07_ort | 0 | ✅ | ✅ | `Graz` | 2 | 1354 | ids | `Graz` (115, 0.97) › keep (12, 0.72) | 0.02 | 0.00 | 0.00 | 0.17 / 0.83 / 0.00 |
| A08_land | 0 | ✅ | ✅ | `Österreich` | 2 | 908 | ids | `Österreich` (115, 0.97) › keep (55, 0.88) | 0.02 | 0.04 | 0.03 | 0.15 / 0.85 / 0.00 |
| A09_email | 0 | ✅ | ✅ | `mira.holzner@example.org` | 2 | 1040 | ids | `mira.holzner@example.o…` (115, 0.93) › keep (34, 0.99) | 0.02 | 0.00 | 0.00 | 0.20 / 0.80 / 0.00 |
| A10_website | 0 | ✅ | ✅ | `https://www.miraholzner.example` | 2 | 1205 | ids | `https://www.miraholzne…` (115, 0.89) › keep (55, 0.89) | 0.03 | 0.00 | 0.03 | 0.17 / 0.83 / 0.00 |
| A11_telefon | 0 | ✅ | ✅ | `06608405534` | 2 | 1150 | ids | `06608405534` (115, 0.97) › keep (63, 0.75) | 0.03 | 0.00 | 0.06 | 0.14 / 0.86 / 0.00 |
| A12_strasse_hnr | 0 | ✅ | ✅ | `Prankergasse 77` | 2 | 1600 | ids | `Prankergasse 77` (115, 0.62) › keep (17, 0.92) | 0.02 | 0.03 | 0.11 | 0.24 / 0.76 / 0.00 |
| A13_passwort_NEG | 0 | ✅ | ✅ | nothing | 1 | 816 | ids | nothing_fits (115, 0.94) | 0.04 | 0.94 | 0.01 | 0.07 / 0.02 / 0.91 |
| A14_fax_NEG | 0 | ✅ | ✅ | nothing | 1 | 718 | ids | nothing_fits (115, 0.52) | 0.20 | 0.52 | 0.07 | 0.30 / 0.04 / 0.66 |
| S01_first_name | 0 | ✅ | ✅ | `Jonas` | 2 | 1329 | ids | `Jonas` (186, 0.92) › keep (17, 0.54) | 0.01 | 0.00 | 0.07 | 0.19 / 0.81 / 0.00 |
| S02_last_name | 0 | ✅ | ✅ | `Prell` | 2 | 1083 | ids | `Prell` (186, 0.90) › keep (16, 0.64) | 0.04 | 0.02 | 0.03 | 0.18 / 0.82 / 0.00 |
| S03_job_title | 0 | ✅ | ✅ | `Product Lead` | 2 | 1092 | ids | `Product Lead` (186, 0.92) › keep (14, 0.97) | 0.03 | 0.01 | 0.02 | 0.14 / 0.86 / 0.00 |
| S04_phone | 0 | ✅ | ✅ | `+43 1 2345678` | 3 | 2003 | ids | `Phone +43 1 2345678` (186, 0.79) › `+43 1 2345678` (27, 0.64) › keep (18, 0.87) | 0.02 | 0.02 | 0.05 | 0.18 / 0.82 / 0.00 |
| S05_mobile | 0 | ✅ | ✅ | `+43 660 1112233` | 2 | 1224 | ids | `+43 660 1112233` (186, 0.93) › keep (18, 0.90) | 0.02 | 0.00 | 0.01 | 0.16 / 0.84 / 0.00 |
| S06_email | 0 | ✅ | ✅ | `jonas.prell@example.com` | 2 | 1055 | ids | `jonas.prell@example.co…` (186, 0.97) › keep (35, 0.99) | 0.02 | 0.00 | 0.00 | 0.14 / 0.86 / 0.00 |
| S07_website | 0 | ✅ | ✅ | `www.prell.example` | 2 | 1330 | ids | `www.prell.example` (186, 0.95) › keep (24, 0.86) | 0.02 | 0.01 | 0.03 | 0.12 / 0.88 / 0.00 |
| S08_iban | 0 | ✅ | ✅ | `AT61 1904 3002 3457 3201` | 3 | 1809 | ids | `IBAN AT61 1904 3002 34…` (186, 0.85) › `AT61 1904 3002 3457 32…` (29, 0.89) › keep (23, 0.96) | 0.00 | 0.02 | 0.02 | 0.34 / 0.65 / 0.01 |
| S09_fax_NEG | 0 | ✅ | ✅ | nothing | 1 | 643 | ids | nothing_fits (186, 0.91) | 0.05 | 0.91 | 0.02 | 0.04 / 0.01 / 0.95 |
| R01_full_name | 0 | ✅ | ✅ | `Anna Reisinger` | 2 | 1275 | ids | `Anna Reisinger` (7/3, 0.94) › keep (16, 0.96, spec) | 0.02 | 0.01 | 0.03 | 0.10 / 0.90 / 0.00 |
| R02_birthdate | 0 | ✅ | ✅ | `14 March 1991` | 2 | 1538 | ids | `14 March 1991` (53/3, 0.65) › keep (12, 0.93, spec) | 0.02 | 0.07 | 0.08 | 0.31 / 0.66 / 0.03 |
| R03_birthplace | 0 | ✅ | ✅ | `Linz` | 2 | 1430 | ids | `Linz` (25/3, 0.95) › keep (12, 0.98, spec) | 0.03 | 0.01 | 0.02 | 0.06 / 0.94 / 0.00 |
| R04_nationality | 0 | ✅ | ✅ | `Austrian` | 2 | 1586 | ids | `Austrian` (22/3, 0.83) › keep (38, 0.93, spec) | 0.01 | 0.01 | 0.12 | 0.05 / 0.95 / 0.00 |
| R05_about | 0 | ✅ | ✅ | `Data engineer with eight years of …` | 2 | 1306 | ids | `Data engineer with eig…` (72/3, 0.47) › keep (255, 0.85, spec) | 0.18 | 0.04 | 0.07 | 0.23 / 0.77 / 0.00 |
| R06_country | 0 | ✅ | ❌ | `Austria` | 2 | 1413 | ids | `Austria` (60/3, 0.75) › keep (30, 0.92, spec) | 0.05 | 0.04 | 0.10 | 0.25 / 0.26 / 0.49 |

## Latency, calls, cost

- all, policy A: n=29, median 1224 ms, p90 1789 ms, max 2003 ms; calls mean 2.00.
- all, policy B: n=29, median 1205 ms, p90 1789 ms, max 2003 ms; calls mean 1.97.
- round-1 cells, policy A: n=29, median 1224 ms, p90 1789 ms, max 2003 ms; calls mean 2.00.
- round-1 cells, policy B: n=29, median 1205 ms, p90 1789 ms, max 2003 ms; calls mean 1.97.
  - 1 call(s): n=3, median 718 ms, p90 796 ms, max 816 ms
  - 2 call(s): n=23, median 1224 ms, p90 1577 ms, max 1787 ms
  - 3 call(s): n=3, median 1809 ms, p90 1964 ms, max 2003 ms
- Per call: warm n=57 median 619 ms, p90 771 ms, max 1084 ms; cold (first call of a process) n=1, 1111 ms.
- Calls per paste (A): distribution 1×3, 2×23, 3×3; speculative next-step answers used: 6 times (each saved one call).
- Option form per request: {'ids': 58} (full = fallback when the excerpts would overfill the state).
- Retry waits (429/503; pacing excluded): 42 waits, 1008 s in total (18 × 429, 24 × 503/5xx, 0 network).
- Single calls over 3 s: 0.
- Billed calls round 2: 198 (explore 140, matrix 58; budget 700, stop-and-ask 650); round 1 used 184 → spike total 382 (≤ 900). Round-2 input tokens 2411547; Gateway cost $0.1013.

