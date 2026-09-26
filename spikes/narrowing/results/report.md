## Verdict against the 7 fixed criteria (both runs of every cell)

| # | criterion | result |
|---|---|---|
| 1 | every positive cell hits (borderline reported, not gating) | **FAIL**: 49/55 pastes hit; misses: A12_strasse_hnr r0 → `Prankergasse 77⏎Top 11`, A12_strasse_hnr r1 → `Prankergasse 77⏎Top 11`, B02_city r0 → `Hi, I'm Lena Vogt, a ceramicist wo…`, C02_motivation r0 → `Dear Ms Hofer,⏎⏎I am writing to ap…`, C03_availability r0 → `Dear Ms Hofer,⏎⏎I am writing to ap…`, C04_name r0 → `Dear Ms Hofer,⏎⏎I am writing to ap…`. Borderline: 12/13 hit |
| 2 | every trap cell ends in No Suitable Match | PASS: 8/8 trap pastes (A13_passwort_NEG, A14_fax_NEG, S09_fax_NEG, R07_linkedin_NEG, O09_coupon_NEG, B05_phone_NEG) |
| 3 | whole copy in W01_chrome_textarea, W02_terminal_prompt, W03_chatgpt_composer, W04_whatsapp_composer, C05_notes_freetext; paragraph in R05_about, R08_summary, R10_description | **FAIL**: 6/8; misses: W01_chrome_textarea r0 → `Product designer with nine years o…`, W03_chatgpt_composer r0 → `Product designer with nine years o…` |
| 4 | chooser opens on two and three emails (T01_email_two_lines, K01_three_emails), nowhere else (incl. S04_phone, S05_mobile) | **FAIL**: opened 1/2; asks elsewhere: none; not opened: K01_three_emails r0 → `marcus@anything.com` |
| 5 | every paste byte-exact | PASS: 86/86 |
| 6 | median < 2 s, nothing > 5 s (summed call latency per paste) | PASS: median 1228 ms, p90 1986 ms, max 4006 ms (n=85) |
| 7 | new cells | N01_address_line_ort 1/1 (`Graz`); N02_url_chat 0/1 (nothing); N03_list_300_lines 1/1 (`WINTER-4471-KQ`); N04_too_big 1/1 (error 400) |

## Per-cell table

Steps: `pick (options[/choices], p)`, `keep` = the current piece unchanged. ⚠ = borderline (not gating), ✎ = tuned.

| cell | expected | run | outcome | hit | calls | ms | steps | p(ask) max | p(nothing) max |
|---|---|---|---|---|---|---|---|---|---|
| A01_vorname | `Mira` | 0 | `Mira` | ✅ | 2 | 1297 | `Mira` (113, 0.85) › keep (10, 0.99) | 0.00 | 0.01 |
| A01_vorname | `Mira` | 1 | `Mira` | ✅ | 2 | 1086 | `Mira` (113, 0.88) › keep (10, 1.00) | 0.00 | 0.00 |
| A02_nachname | `Holzner` | 0 | `Holzner` | ✅ | 2 | 1826 | `Holzner` (113, 0.90) › keep (28, 1.00) | 0.00 | 0.00 |
| A02_nachname | `Holzner` | 1 | `Holzner` | ✅ | 2 | 961 | `Holzner` (113, 0.90) › keep (28, 0.99) | 0.00 | 0.00 |
| A03_strasse ⚠ | `Prankergasse` | 0 | `Prankergasse` | ✅ | 3 | 1629 | `Prankergasse 77` (113, 0.65) › `Prankergasse` (15, 0.56) › keep (74, 0.98) | 0.02 | 0.01 |
| A03_strasse ⚠ | `Prankergasse` | 1 | `Prankergasse` | ✅ | 3 | 1587 | `Prankergasse 77` (113, 0.70) › `Prankergasse` (15, 0.56) › keep (74, 0.97) | 0.02 | 0.01 |
| A04_hausnummer | `77` | 0 | `77` | ✅ | 2 | 1138 | `77` (113, 0.86) › keep (2, 1.00) | 0.00 | 0.02 |
| A04_hausnummer | `77` | 1 | `77` | ✅ | 2 | 1010 | `77` (113, 0.84) › keep (2, 1.00) | 0.00 | 0.03 |
| A05_adresszusatz | `Top 11` | 0 | `Top 11` | ✅ | 2 | 2198 | `Top 11` (113, 0.84) › keep (6, 0.92) | 0.01 | 0.04 |
| A05_adresszusatz | `Top 11` | 1 | `Top 11` | ✅ | 2 | 1410 | `Top 11` (113, 0.83) › keep (6, 0.93) | 0.01 | 0.01 |
| A06_plz | `8020` | 0 | `8020` | ✅ | 2 | 1223 | `8020` (113, 0.91) › keep (9, 1.00) | 0.00 | 0.03 |
| A06_plz | `8020` | 1 | `8020` | ✅ | 2 | 1253 | `8020` (113, 0.84) › keep (9, 1.00) | 0.00 | 0.00 |
| A07_ort | `Graz` | 0 | `Graz` | ✅ | 2 | 1298 | `Graz` (113, 0.95) › keep (10, 1.00) | 0.00 | 0.02 |
| A07_ort | `Graz` | 1 | `Graz` | ✅ | 2 | 1063 | `Graz` (113, 0.95) › keep (10, 1.00) | 0.00 | 0.01 |
| A08_land | `Österreich` | 0 | `Österreich` | ✅ | 2 | 1134 | `Österreich` (113, 0.92) › keep (53, 0.98) | 0.00 | 0.01 |
| A08_land | `Österreich` | 1 | `Österreich` | ✅ | 2 | 1186 | `Österreich` (113, 0.88) › keep (53, 0.98) | 0.00 | 0.01 |
| A09_email | `mira.holzner@example.org` | 0 | `mira.holzner@example.org` | ✅ | 2 | 1295 | `mira.holzner@example.o…` (113, 0.93) › keep (32, 1.00) | 0.00 | 0.00 |
| A09_email | `mira.holzner@example.org` | 1 | `mira.holzner@example.org` | ✅ | 2 | 931 | `mira.holzner@example.o…` (113, 0.98) › keep (32, 1.00) | 0.00 | 0.00 |
| A10_website | `https://www.miraholzner.ex…` | 0 | `https://www.miraholzner.example` | ✅ | 2 | 1082 | `https://www.miraholzne…` (113, 0.92) › keep (53, 0.98) | 0.00 | 0.00 |
| A10_website | `https://www.miraholzner.ex…` | 1 | `https://www.miraholzner.example` | ✅ | 2 | 1356 | `https://www.miraholzne…` (113, 0.91) › keep (53, 0.96) | 0.00 | 0.02 |
| A11_telefon | `06608405534` | 0 | `06608405534` | ✅ | 2 | 1626 | `06608405534` (113, 0.97) › keep (61, 0.99) | 0.00 | 0.01 |
| A11_telefon | `06608405534` | 1 | `06608405534` | ✅ | 2 | 1496 | `06608405534` (113, 0.97) › keep (61, 0.99) | 0.00 | 0.01 |
| A12_strasse_hnr | `Prankergasse 77` | 0 | `Prankergasse 77⏎Top 11` | ❌ | 2 | 1493 | `Prankergasse 77⏎Top 11` (113, 0.84) › keep (11, 0.64) | 0.02 | 0.00 |
| A12_strasse_hnr | `Prankergasse 77` | 1 | `Prankergasse 77⏎Top 11` | ❌ | 2 | 1588 | `Prankergasse 77⏎Top 11` (113, 0.89) › keep (11, 0.71) | 0.02 | 0.00 |
| A13_passwort_NEG | ∅ (nothing) | 0 | nothing | ✅ | 1 | 578 | nothing_fits (113, 0.84) | 0.06 | 0.84 |
| A13_passwort_NEG | ∅ (nothing) | 1 | nothing | ✅ | 1 | 752 | nothing_fits (113, 0.88) | 0.05 | 0.88 |
| A14_fax_NEG | ∅ (nothing) | 0 | nothing | ✅ | 1 | 652 | nothing_fits (113, 0.61) | 0.02 | 0.61 |
| A14_fax_NEG | ∅ (nothing) | 1 | nothing | ✅ | 1 | 754 | nothing_fits (113, 0.62) | 0.02 | 0.62 |
| S01_first_name | `Jonas` | 0 | `Jonas` | ✅ | 2 | 1191 | `Jonas` (203, 0.54) › keep (15, 0.99) | 0.02 | 0.02 |
| S01_first_name | `Jonas` | 1 | `Jonas` | ✅ | 2 | 1209 | `Jonas` (203, 0.51) › keep (15, 1.00) | 0.02 | 0.02 |
| S02_last_name | `Prell` | 0 | `Prell` | ✅ | 2 | 1447 | `Prell` (203, 0.86) › keep (14, 0.99) | 0.00 | 0.01 |
| S02_last_name | `Prell` | 1 | `Prell` | ✅ | 2 | 1353 | `Prell` (203, 0.62) › keep (14, 0.99) | 0.00 | 0.01 |
| S03_job_title | `Product Lead` | 0 | `Product Lead` | ✅ | 2 | 1779 | `Product Lead` (203, 0.77) › keep (12, 1.00) | 0.00 | 0.04 |
| S03_job_title | `Product Lead` | 1 | `Product Lead` | ✅ | 2 | 1067 | `Product Lead` (203, 0.80) › keep (12, 1.00) | 0.00 | 0.04 |
| S04_phone | `+43 1 2345678` | 0 | `+43 1 2345678` | ✅ | 3 | 1915 | `Phone +43 1 2345678` (203, 0.47) › `+43 1 2345678` (25, 0.85) › keep (16, 1.00) | 0.00 | 0.02 |
| S04_phone | `+43 1 2345678` | 1 | `+43 1 2345678` | ✅ | 3 | 2237 | `Phone +43 1 2345678` (203, 0.45) › `+43 1 2345678` (25, 0.83) › keep (16, 1.00) | 0.01 | 0.02 |
| S05_mobile | `+43 660 1112233` | 0 | `+43 660 1112233` | ✅ | 2 | 1369 | `+43 660 1112233` (203, 0.70) › keep (16, 1.00) | 0.00 | 0.00 |
| S05_mobile | `+43 660 1112233` | 1 | `+43 660 1112233` | ✅ | 2 | 2192 | `+43 660 1112233` (203, 0.80) › keep (16, 1.00) | 0.00 | 0.00 |
| S06_email | `jonas.prell@example.com` | 0 | `jonas.prell@example.com` | ✅ | 2 | 1388 | `jonas.prell@example.co…` (203, 0.95) › keep (33, 1.00) | 0.00 | 0.00 |
| S06_email | `jonas.prell@example.com` | 1 | `jonas.prell@example.com` | ✅ | 2 | 931 | `jonas.prell@example.co…` (203, 0.94) › keep (33, 1.00) | 0.00 | 0.00 |
| S07_website | `www.prell.example` | 0 | `www.prell.example` | ✅ | 2 | 1250 | `www.prell.example` (203, 0.81) › keep (22, 1.00) | 0.00 | 0.04 |
| S07_website | `www.prell.example` | 1 | `www.prell.example` | ✅ | 2 | 1487 | `www.prell.example` (203, 0.83) › keep (22, 1.00) | 0.00 | 0.04 |
| S08_iban ⚠ | `AT61 1904 3002 3457 3201` | 0 | `AT61 1904 3002 3457 3201` | ✅ | 2 | 1087 | `AT61 1904 3002 3457 32…` (203, 0.68) › keep (21, 1.00) | 0.00 | 0.00 |
| S09_fax_NEG | ∅ (nothing) | 0 | nothing | ✅ | 1 | 440 | nothing_fits (203, 0.81) | 0.00 | 0.81 |
| R01_full_name | `Anna Reisinger` | 0 | `Anna Reisinger` | ✅ | 2 | 1179 | `Anna Reisinger` (48, 0.96) › keep (14, 1.00) | 0.00 | 0.00 |
| R02_birthdate | `14 March 1991` | 0 | `14 March 1991` | ✅ | 3 | 2299 | `Born 14 March 1991 in …` (48, 0.58) › `14 March 1991` (27, 0.94) › keep (10, 1.00) | 0.03 | 0.15 |
| R03_birthplace | `Linz` | 0 | `Linz` | ✅ | 3 | 2508 | `Born 14 March 1991 in …` (48, 0.62) › `Linz` (27, 0.77) › keep (10, 1.00) | 0.03 | 0.10 |
| R04_nationality | `Austrian` | 0 | `Austrian` | ✅ | 3 | 2245 | `Nationality: Austrian` (48, 0.92) › `Austrian` (23, 0.90) › keep (36, 0.97) | 0.01 | 0.03 |
| R05_about | `Data engineer with eight y…` | 0 | `Data engineer with eight years of …` | ✅ | 2 | 1578 | `Data engineer with eig…` (48, 0.70) › keep (9, 0.94) | 0.03 | 0.01 |
| R06_country ⚠ | `Austria` | 0 | nothing | ❌ | 1 | 758 | nothing_fits (48, 0.34) | 0.04 | 0.34 |
| R07_linkedin_NEG | ∅ (nothing) | 0 | nothing | ✅ | 1 | 435 | nothing_fits (48, 0.57) | 0.04 | 0.57 |
| R08_summary | `Data engineer with eight y…` | 0 | `Data engineer with eight years of …` | ✅ | 2 | 1455 | `Data engineer with eig…` (48, 0.71) › keep (9, 0.97) | 0.03 | 0.00 |
| R09_biography ⚠ | `Data engineer with eight y…` | 0 | `Data engineer with eight years of …` | ✅ | 2 | 1493 | `Data engineer with eig…` (48, 0.49) › keep (9, 0.77) | 0.05 | 0.03 |
| R10_description ⚠ | `Data engineer with eight y…` | 0 | `Data engineer with eight years of …` | ✅ | 2 | 2340 | `Data engineer with eig…` (48, 0.48) › keep (9, 0.98) | 0.02 | 0.00 |
| O01_email | `wren.castellan@example.net` | 0 | `wren.castellan@example.net` | ✅ | 2 | 989 | `wren.castellan@example…` (160, 0.97) › keep (32, 1.00) | 0.00 | 0.00 |
| O02_order_number | `4711` | 0 | `4711` | ✅ | 2 | 1969 | `4711` (160, 0.80) › keep (9, 1.00) | 0.03 | 0.00 |
| O03_recipient | `Lise Adler` | 0 | `Lise Adler` | ✅ | 2 | 1306 | `Lise Adler` (160, 0.91) › keep (10, 0.99) | 0.00 | 0.00 |
| O04_street | `Hauptstr. 5` | 0 | `Hauptstr. 5` | ✅ | 2 | 1167 | `Hauptstr. 5` (160, 0.69) › keep (13, 1.00) | 0.03 | 0.02 |
| O05_postal_code | `4020` | 0 | `4020` | ✅ | 2 | 1809 | `4020` (160, 0.78) › keep (9, 1.00) | 0.05 | 0.02 |
| O06_city | `Linz` | 0 | `Linz` | ✅ | 2 | 1314 | `Linz` (160, 0.91) › keep (10, 1.00) | 0.02 | 0.02 |
| O07_amount ⚠ | `129,90` | 0 | `129,90` | ✅ | 3 | 1725 | `Total EUR 129,90` (160, 0.63) › `129,90` (20, 0.68) › keep (9, 0.98) | 0.03 | 0.02 |
| O08_tracking | `00340434161234567890` | 0 | `00340434161234567890` | ✅ | 2 | 1181 | `00340434161234567890` (160, 0.67) › keep (198, 0.99) | 0.00 | 0.01 |
| O09_coupon_NEG | ∅ (nothing) | 0 | nothing | ✅ | 1 | 597 | nothing_fits (160, 0.74) | 0.04 | 0.74 |
| B01_handle | `@mira_h` | 0 | `@mira_h` | ✅ | 3 | 1998 | `I post new glazes and …` (13, 0.34) › `@mira_h` (170, 0.40) › keep (10, 0.96) | 0.03 | 0.28 |
| B02_city | `Innsbruck` | 0 | `Hi, I'm Lena Vogt, a ceramicist wo…` | ❌ | 2 | 1184 | `Hi, I'm Lena Vogt, a c…` (13, 0.47) › keep (189, 0.26) | 0.02 | 0.25 |
| B03_bio ⚠ | `Hi, I'm Lena Vogt, a ceram…` | 0 | `Hi, I'm Lena Vogt, a ceramicist wo…` | ✅ | 1 | 541 | keep (13, 0.78) | 0.03 | 0.00 |
| B04_birth_year | `1994` | 0 | `1994` | ✅ | 3 | 1801 | `Born in 1994 and raise…` (13, 0.54) › `1994` (212, 0.35) › keep (9, 1.00) | 0.02 | 0.21 |
| B05_phone_NEG | ∅ (nothing) | 0 | nothing | ✅ | 1 | 778 | nothing_fits (13, 0.50) | 0.02 | 0.50 |
| B06_biography ⚠ | `Hi, I'm Lena Vogt, a ceram…` | 0 | `Hi, I'm Lena Vogt, a ceramicist wo…` | ✅ | 1 | 798 | keep (13, 0.46) | 0.07 | 0.13 |
| B07_about_me ⚠ | `Hi, I'm Lena Vogt, a ceram…` | 0 | `Hi, I'm Lena Vogt, a ceramicist wo…` | ✅ | 1 | 517 | keep (13, 0.73) | 0.05 | 0.00 |
| B08_short_bio ⚠ | `Hi, I'm Lena Vogt, a ceram…` | 0 | `Hi, I'm Lena Vogt, a ceramicist wo…` | ✅ | 2 | 1047 | `Hi, I'm Lena Vogt, a c…` (13, 0.28) › keep (6, 0.73) | 0.16 | 0.01 |
| T01_email_two_lines | ask | 0 | ask → [`wren.castellan@example.n…`, `Ticket 4711 wren.castell…`, `4711 wren.castellan@exam…`, `lise.adler@example.net`] | ✅ | 1 | 446 | ask_user (82, 0.25) | 0.25 | 0.03 |
| C01_cover_letter ⚠ | `I am writing to apply for …` | 0 | `Dear Ms Hofer,⏎⏎I am writing to ap…` | ✅ | 1 | 832 | keep (49, 0.82) | 0.01 | 0.00 |
| C02_motivation | `What draws me to Grünraum …` | 0 | `Dear Ms Hofer,⏎⏎I am writing to ap…` | ❌ | 1 | 1228 | keep (49, 0.33) | 0.01 | 0.00 |
| C03_availability | `I can start on 1 December …` | 0 | `Dear Ms Hofer,⏎⏎I am writing to ap…` | ❌ | 1 | 678 | keep (49, 0.63) | 0.02 | 0.00 |
| C04_name | `Theo Brandner` | 0 | `Dear Ms Hofer,⏎⏎I am writing to ap…` | ❌ | 1 | 510 | keep (49, 0.67) | 0.04 | 0.00 |
| C05_notes_freetext ⚠ | `Dear Ms Hofer,⏎⏎I am writi…` | 0 | `Dear Ms Hofer,⏎⏎I am writing to ap…` | ✅ | 1 | 806 | keep (49, 0.55) | 0.07 | 0.06 |
| W01_chrome_textarea | `Marlene Oberholzer⏎marlene…` | 0 | `Product designer with nine years o…` | ❌ | 2 | 1755 | `Product designer with …` (24, 0.48) › keep (1374/6, 0.91) | 0.03 | 0.23 |
| W02_terminal_prompt | `Marlene Oberholzer⏎marlene…` | 0 | `Marlene Oberholzer⏎marlene.oberhol…` | ✅ | 1 | 421 | keep (24, 0.51) | 0.09 | 0.21 |
| W03_chatgpt_composer | `Marlene Oberholzer⏎marlene…` | 0 | `Product designer with nine years o…` | ❌ | 2 | 1774 | `Product designer with …` (24, 0.68) › keep (1374/6, 0.92) | 0.00 | 0.01 |
| W04_whatsapp_composer | `Marlene Oberholzer⏎marlene…` | 0 | `Marlene Oberholzer⏎marlene.oberhol…` | ✅ | 1 | 667 | keep (24, 0.68) | 0.02 | 0.00 |
| K01_three_emails | ask | 0 | `marcus@anything.com` | ❌ | 2 | 1545 | `marcus@anything.com` (234, 0.79) › keep (22, 0.81) | 0.18 | 0.05 |
| N01_address_line_ort | `Graz` | 0 | `Graz` | ✅ | 2 | 1112 | `Graz` (41, 0.86) › keep (10, 0.98) | 0.01 | 0.01 |
| N02_url_chat | `https://www.miraholzner.ex…` | 0 | nothing | ❌ | 1 | 574 | nothing_fits (233, 0.56) | 0.02 | 0.56 |
| N03_list_300_lines | `WINTER-4471-KQ` | 0 | `WINTER-4471-KQ` | ✅ | 5 | 4006 | `2026-09-12 12:41:02 IN…` (303/2, 0.77) › `WINTER-4471-KQ` (322/2, 0.54) › keep (20, 0.85) | 0.00 | 0.37 |
| N04_too_big | too long | 0 | error 400 | ✅ | 1 | 1853 | None (3001/12, –) | 0.00 | 0.00 |

## Latency, calls, cost

- Per paste (summed call latency, 429 waits excluded): n=85, median 1228 ms, p90 1986 ms, max 4006 ms.
  - 1 call(s): n=21, median 652 ms, p90 806 ms, max 1228 ms
  - 2 call(s): n=53, median 1298 ms, p90 1803 ms, max 2340 ms
  - 3 call(s): n=10, median 1956 ms, p90 2320 ms, max 2508 ms
  - 5 call(s): n=1, median 4006 ms, p90 4006 ms, max 4006 ms
- Per call: warm n=160 median 633 ms, p90 1006 ms; cold (first call of a process) n=2 median 698 ms.
- Calls per paste (matrix, both runs): mean 1.90; distribution 1×22, 2×53, 3×10, 5×1.
- Retry waits (429/503, pacing excluded) during the matrix: 103 waits, 2581 s in total.
- Billed Jev calls for the whole spike: 184 (budget 900); input tokens 1087430; Gateway cost $0.0457.
- Follow-up carry list cut: never.

