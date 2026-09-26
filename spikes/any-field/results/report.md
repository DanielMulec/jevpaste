## Per-cell results (Engine J, gate v7, threshold 0.5)

Hit = final pasted text byte-equal to the expected excerpt (or a listed accept). `J` = J's own answer; `prod` = after production's free_text ≥ 0.8 override (whole item). s1 = stage-1 choice (prob), more = `contains_more` P(true), free = `free_text` P(true), s2 = stage-2 span (prob, spans offered).

| cell | field | expected | run | s1 (prob) | more | free | s2 (prob, #spans) | J | prod | noise |
|---|---|---|---|---|---|---|---|---|---|---|
| A01_vorname | Vorname | `Mira` | 0 | `Mira Holzner` (0.95) | 0.30 | 0.04 | – | ❌ | ❌ `Mira Holzner` |  |
| A01_vorname | Vorname | `Mira` | 1 | `Mira Holzner` (0.93) | 0.13 | 0.03 | – | ❌ | ❌ `Mira Holzner` |  |
| A02_nachname | Nachname | `Holzner` | 0 | `Mira Holzner` (0.65) | 0.19 | 0.03 | – | ❌ | ❌ `Mira Holzner` |  |
| A02_nachname | Nachname | `Holzner` | 1 | `Mira Holzner` (0.76) | 0.65 | 0.03 | `Holzner` (1.00, 3) | ✅ | ✅ |  |
| A03_strasse ⚠ | Straße | `Prankergasse` | 0 | `Prankergasse 77` (0.95) | 0.36 | 0.05 | – | ❌ | ❌ `Prankergasse 77` |  |
| A03_strasse ⚠ | Straße | `Prankergasse` | 1 | `Prankergasse 77` (0.96) | 0.33 | 0.05 | – | ❌ | ❌ `Prankergasse 77` |  |
| A04_hausnummer | Hausnummer | `77` | 0 | `Prankergasse 77` (0.80) | 0.64 | 0.03 | `77` (1.00, 3) | ✅ | ✅ |  |
| A04_hausnummer | Hausnummer | `77` | 1 | `Prankergasse 77` (0.80) | 0.58 | 0.03 | `77` (1.00, 3) | ✅ | ✅ |  |
| A05_adresszusatz | Adresszusatz | `Top 11` | 0 | `Top 11` (0.99) | 0.16 | 0.05 | – | ✅ | ✅ |  |
| A05_adresszusatz | Adresszusatz | `Top 11` | 1 | `Top 11` (0.99) | 0.15 | 0.06 | – | ✅ | ✅ |  |
| A06_plz | PLZ | `8020` | 0 | `8020 Graz` (0.94) | 0.68 | 0.03 | `8020` (1.00, 3) | ✅ | ✅ |  |
| A06_plz | PLZ | `8020` | 1 | `8020 Graz` (0.96) | 0.62 | 0.03 | `8020` (1.00, 3) | ✅ | ✅ |  |
| A07_ort | Ort | `Graz` | 0 | `8020 Graz` (0.92) | 0.55 | 0.04 | `Graz` (0.99, 3) | ✅ | ✅ |  |
| A07_ort | Ort | `Graz` | 1 | `8020 Graz` (0.91) | 0.36 | 0.04 | – | ❌ | ❌ `8020 Graz` |  |
| A08_land | Land | `Österreich` | 0 | `Österreich` (1.00) | 0.19 | 0.04 | – | ✅ | ✅ |  |
| A08_land | Land | `Österreich` | 1 | `Österreich` (0.99) | 0.14 | 0.04 | – | ✅ | ✅ |  |
| A09_email | E-Mail | `mira.holzner@example.org` | 0 | `mira.holzner@example.org` (1.00) | 0.09 | 0.04 | – | ✅ | ✅ |  |
| A09_email | E-Mail | `mira.holzner@example.org` | 1 | `mira.holzner@example.org` (1.00) | 0.09 | 0.04 | – | ✅ | ✅ |  |
| A10_website | Website | `https://www.miraholzner.example` | 0 | `https://www.miraholzner.e…` (1.00) | 0.09 | 0.07 | – | ✅ | ✅ |  |
| A10_website | Website | `https://www.miraholzner.example` | 1 | `https://www.miraholzner.e…` (1.00) | 0.09 | 0.06 | – | ✅ | ✅ |  |
| A11_telefon | Telefon | `06608405534` | 0 | `06608405534` (1.00) | 0.08 | 0.04 | – | ✅ | ✅ |  |
| A11_telefon | Telefon | `06608405534` | 1 | `06608405534` (1.00) | 0.08 | 0.04 | – | ✅ | ✅ |  |
| A12_strasse_hnr | Straße und Hausnummer | `Prankergasse 77` | 0 | `Prankergasse 77` (0.98) | 0.15 | 0.04 | – | ✅ | ✅ |  |
| A12_strasse_hnr | Straße und Hausnummer | `Prankergasse 77` | 1 | `Prankergasse 77` (0.97) | 0.14 | 0.05 | – | ✅ | ✅ |  |
| A13_passwort_NEG | Passwort | ∅ (none) | 0 | ∅ (none) (1.00) | 0.14 | 0.04 | – | ✅ | ✅ |  |
| A13_passwort_NEG | Passwort | ∅ (none) | 1 | ∅ (none) (0.99) | 0.15 | 0.04 | – | ✅ | ✅ |  |
| A14_fax_NEG | Fax | ∅ (none) | 0 | ∅ (none) (0.98) | 0.13 | 0.05 | – | ✅ | ✅ |  |
| A14_fax_NEG | Fax | ∅ (none) | 1 | ∅ (none) (0.98) | 0.12 | 0.04 | – | ✅ | ✅ |  |
| S01_first_name | First name | `Jonas` | 0 | `Jonas Prell · Product Lead` (0.88) | 0.93 | 0.04 | `Jonas` (1.00, 15) | ✅ | ✅ |  |
| S01_first_name | First name | `Jonas` | 1 | `Jonas Prell · Product Lead` (0.88) | 0.92 | 0.04 | `Jonas` (1.00, 15) | ✅ | ✅ |  |
| S02_last_name | Last name | `Prell` | 0 | `Jonas Prell · Product Lead` (0.77) | 0.91 | 0.04 | `Prell` (1.00, 15) | ✅ | ✅ |  |
| S02_last_name | Last name | `Prell` | 1 | `Jonas Prell · Product Lead` (0.78) | 0.90 | 0.04 | `Prell` (1.00, 15) | ✅ | ✅ |  |
| S03_job_title | Job title | `Product Lead` | 0 | `Jonas Prell · Product Lead` (0.89) | 0.79 | 0.05 | `Product Lead` (1.00, 15) | ✅ | ✅ |  |
| S03_job_title | Job title | `Product Lead` | 1 | `Jonas Prell · Product Lead` (0.89) | 0.72 | 0.05 | `Product Lead` (1.00, 15) | ✅ | ✅ |  |
| S04_phone | Phone | `+43 1 2345678` | 0 | `Phone +43 1 2345678 · Mob…` (0.96) | 0.96 | 0.04 | `+43 1 2345678` (0.99, 44) | ✅ | ✅ | 2 |
| S04_phone | Phone | `+43 1 2345678` | 1 | `Phone +43 1 2345678 · Mob…` (0.96) | 0.96 | 0.04 | `+43 1 2345678` (0.99, 44) | ✅ | ✅ | 2 |
| S05_mobile | Mobile | `+43 660 1112233` | 0 | `Phone +43 1 2345678 · Mob…` (0.96) | 0.96 | 0.04 | `+43 660 1112233` (0.99, 44) | ✅ | ✅ | 2 |
| S05_mobile | Mobile | `+43 660 1112233` | 1 | `Phone +43 1 2345678 · Mob…` (0.97) | 0.96 | 0.04 | `+43 660 1112233` (0.99, 44) | ✅ | ✅ | 2 |
| S06_email | Email | `jonas.prell@example.com` | 0 | `jonas.prell@example.com |…` (0.95) | 0.77 | 0.04 | `jonas.prell@example.com` (1.00, 6) | ✅ | ✅ |  |
| S06_email | Email | `jonas.prell@example.com` | 1 | `jonas.prell@example.com |…` (0.95) | 0.75 | 0.04 | `jonas.prell@example.com` (1.00, 6) | ✅ | ✅ |  |
| S07_website | Website | `www.prell.example` | 0 | `jonas.prell@example.com |…` (0.93) | 0.63 | 0.05 | `www.prell.example` (1.00, 6) | ✅ | ✅ |  |
| S07_website | Website | `www.prell.example` | 1 | `jonas.prell@example.com |…` (0.95) | 0.63 | 0.06 | `www.prell.example` (1.00, 6) | ✅ | ✅ |  |
| S08_iban ⚠ | IBAN | `AT61 1904 3002 3457 3201` | 0 | `IBAN AT61 1904 3002 3457 …` (0.99) | 0.76 | 0.04 | `AT61 1904 3002 3457 3201` (1.00, 21) | ✅ | ✅ |  |
| S08_iban ⚠ | IBAN | `AT61 1904 3002 3457 3201` | 1 | `IBAN AT61 1904 3002 3457 …` (0.98) | 0.87 | 0.05 | `AT61 1904 3002 3457 3201` (1.00, 21) | ✅ | ✅ |  |
| S09_fax_NEG | Fax | ∅ (none) | 0 | ∅ (none) (1.00) | 0.15 | 0.05 | – | ✅ | ✅ |  |
| S09_fax_NEG | Fax | ∅ (none) | 1 | ∅ (none) (1.00) | 0.15 | 0.05 | – | ✅ | ✅ |  |
| R01_full_name | Full name | `Anna Reisinger` | 0 | `Anna Reisinger` (0.99) | 0.23 | 0.04 | – | ✅ | ✅ |  |
| R01_full_name | Full name | `Anna Reisinger` | 1 | `Anna Reisinger` (0.98) | 0.18 | 0.05 | – | ✅ | ✅ |  |
| R02_birthdate | Date of birth | `14 March 1991` | 0 | `Born 14 March 1991 in Linz` (0.92) | 0.89 | 0.03 | `14 March 1991` (0.99, 21) | ✅ | ✅ |  |
| R02_birthdate | Date of birth | `14 March 1991` | 1 | `Born 14 March 1991 in Linz` (0.93) | 0.90 | 0.04 | `14 March 1991` (1.00, 21) | ✅ | ✅ |  |
| R03_birthplace | Place of birth | `Linz` | 0 | `Born 14 March 1991 in Linz` (0.93) | 0.84 | 0.06 | `Linz` (0.99, 21) | ✅ | ✅ |  |
| R03_birthplace | Place of birth | `Linz` | 1 | `Born 14 March 1991 in Linz` (0.91) | 0.88 | 0.06 | `Linz` (0.99, 21) | ✅ | ✅ |  |
| R04_nationality | Nationality | `Austrian` | 0 | `Austrian` (0.85) | 0.59 | 0.05 | `Austrian` (1.00, 1) | ✅ | ✅ |  |
| R04_nationality | Nationality | `Austrian` | 1 | `Austrian` (0.87) | 0.62 | 0.05 | `Austrian` (1.00, 1) | ✅ | ✅ |  |
| R05_about | About | `Data engineer with eight years of…` | 0 | `Data engineer with eight …` (0.98) | 0.52 | 0.84 | ∅ (none) (0.18, 254) † | ❌ | ❌ `Anna Reisinger⏎Born 1…` |  |
| R05_about | About | `Data engineer with eight years of…` | 1 | `Data engineer with eight …` (0.99) | 0.50 | 0.82 | ∅ (none) (0.14, 254) † | ❌ | ❌ `Anna Reisinger⏎Born 1…` |  |
| R06_country ⚠ | Country of residence | `Austria` | 0 | `Senior Data Engineer, Voe…` (0.29) | 0.38 | 0.05 | – | ❌ | ❌ ∅ (none) |  |
| R06_country ⚠ | Country of residence | `Austria` | 1 | `Senior Data Engineer, Voe…` (0.30) | 0.29 | 0.05 | – | ❌ | ❌ ∅ (none) |  |
| R07_linkedin_NEG | LinkedIn URL | ∅ (none) | 0 | ∅ (none) (1.00) | 0.16 | 0.05 | – | ✅ | ✅ |  |
| R07_linkedin_NEG | LinkedIn URL | ∅ (none) | 1 | ∅ (none) (1.00) | 0.13 | 0.05 | – | ✅ | ✅ |  |
| R08_summary | Profile summary | `Data engineer with eight years of…` | 0 | `Data engineer with eight …` (1.00) | 0.29 | 0.87 | – | ✅ | ❌ `Anna Reisinger⏎Born 1…` |  |
| R08_summary | Profile summary | `Data engineer with eight years of…` | 1 | `Data engineer with eight …` (1.00) | 0.27 | 0.86 | – | ✅ | ❌ `Anna Reisinger⏎Born 1…` |  |
| R09_biography ⚠ | Biography | `Data engineer with eight years of…` | 0 | `Data engineer with eight …` (0.93) | 0.39 | 0.80 | – | ❌ | ❌ `Anna Reisinger⏎Born 1…` |  |
| R09_biography ⚠ | Biography | `Data engineer with eight years of…` | 1 | `Data engineer with eight …` (0.96) | 0.42 | 0.79 | – | ❌ | ❌ ∅ (none) |  |
| R10_description ⚠ | Description | `Data engineer with eight years of…` | 0 | `Data engineer with eight …` (0.99) | 0.33 | 0.90 | – | ✅ | ❌ `Anna Reisinger⏎Born 1…` |  |
| R10_description ⚠ | Description | `Data engineer with eight years of…` | 1 | `Data engineer with eight …` (0.98) | 0.34 | 0.92 | – | ✅ | ❌ `Anna Reisinger⏎Born 1…` |  |
| O01_email | Email used for the order | `wren.castellan@example.net` | 0 | `Order 4711 for wren.caste…` (0.93) | 0.91 | 0.04 | `wren.castellan@example.net` (0.99, 10) | ✅ | ✅ |  |
| O01_email | Email used for the order | `wren.castellan@example.net` | 1 | `Order 4711 for wren.caste…` (0.94) | 0.89 | 0.05 | `wren.castellan@example.net` (0.99, 10) | ✅ | ✅ |  |
| O02_order_number | Order number | `4711` | 0 | `Order 4711 for wren.caste…` (0.86) | 0.93 | 0.05 | `4711` (0.97, 10) | ✅ | ✅ |  |
| O02_order_number | Order number | `4711` | 1 | `Order 4711 for wren.caste…` (0.88) | 0.94 | 0.04 | `4711` (0.97, 10) | ✅ | ✅ |  |
| O03_recipient | Recipient name | `Lise Adler` | 0 | `Lise Adler, Hauptstr. 5, …` (0.67) | 0.95 | 0.04 | `Lise Adler` (1.00, 21) | ✅ | ✅ |  |
| O03_recipient | Recipient name | `Lise Adler` | 1 | `Lise Adler, Hauptstr. 5, …` (0.65) | 0.94 | 0.04 | `Lise Adler` (1.00, 21) | ✅ | ✅ |  |
| O04_street | Street | `Hauptstr. 5` | 0 | `Lise Adler, Hauptstr. 5, …` (0.63) | 0.95 | 0.04 | `Hauptstr. 5` (0.99, 21) | ✅ | ✅ |  |
| O04_street | Street | `Hauptstr. 5` | 1 | `Lise Adler, Hauptstr. 5, …` (0.63) | 0.94 | 0.04 | `Hauptstr. 5` (0.99, 21) | ✅ | ✅ |  |
| O05_postal_code | Postal code | `4020` | 0 | `Lise Adler, Hauptstr. 5, …` (0.56) | 0.95 | 0.04 | `4020` (1.00, 21) | ✅ | ✅ |  |
| O05_postal_code | Postal code | `4020` | 1 | `Lise Adler, Hauptstr. 5, …` (0.52) | 0.94 | 0.04 | `4020` (1.00, 21) | ✅ | ✅ |  |
| O06_city | City | `Linz` | 0 | `Lise Adler, Hauptstr. 5, …` (0.75) | 0.96 | 0.04 | `Linz` (1.00, 21) | ✅ | ✅ |  |
| O06_city | City | `Linz` | 1 | `Lise Adler, Hauptstr. 5, …` (0.79) | 0.94 | 0.04 | `Linz` (1.00, 21) | ✅ | ✅ |  |
| O07_amount ⚠ | Amount paid | `129,90` | 0 | `Total EUR 129,90` (0.98) | 0.93 | 0.05 | `129,90` (0.56, 10) | ✅ | ✅ |  |
| O07_amount ⚠ | Amount paid | `129,90` | 1 | `Total EUR 129,90` (0.98) | 0.91 | 0.05 | `129,90` (0.52, 10) | ✅ | ✅ |  |
| O08_tracking | Tracking number of the original parcel | `00340434161234567890` | 0 | `Tracking DHL 003404341612…` (0.97) | 0.97 | 0.06 | `00340434161234567890` (0.92, 6) | ✅ | ✅ |  |
| O08_tracking | Tracking number of the original parcel | `00340434161234567890` | 1 | `Tracking DHL 003404341612…` (0.96) | 0.97 | 0.05 | `00340434161234567890` (0.95, 6) | ✅ | ✅ |  |
| O09_coupon_NEG | Coupon code (if any) | ∅ (none) | 0 | ∅ (none) (0.97) | 0.37 | 0.06 | – | ✅ | ✅ |  |
| O09_coupon_NEG | Coupon code (if any) | ∅ (none) | 1 | ∅ (none) (0.95) | 0.33 | 0.05 | – | ✅ | ✅ |  |
| B01_handle | Instagram handle | `@mira_h` | 0 | `I post new glazes and kil…` (0.58) | 0.82 | 0.06 | `@mira_h` (0.99, 101) | ✅ | ✅ |  |
| B01_handle | Instagram handle | `@mira_h` | 1 | `I post new glazes and kil…` (0.65) | 0.80 | 0.05 | `@mira_h` (0.99, 101) | ✅ | ✅ |  |
| B02_city | City | `Innsbruck` | 0 | `Hi, I'm Lena Vogt, a cera…` (0.84) | 0.91 | 0.05 | `Innsbruck.` (0.84, 113) | ❌ | ❌ `Innsbruck.` |  |
| B02_city | City | `Innsbruck` | 1 | `Hi, I'm Lena Vogt, a cera…` (0.84) | 0.89 | 0.05 | `Innsbruck.` (0.86, 113) | ❌ | ❌ `Innsbruck.` |  |
| B03_bio ⚠ | Bio | `Hi, I'm Lena Vogt, a ceramicist w…` | 0 | `Hi, I'm Lena Vogt, a cera…` (0.65) | 0.33 | 0.86 | – | ✅ | ✅ |  |
| B03_bio ⚠ | Bio | `Hi, I'm Lena Vogt, a ceramicist w…` | 1 | `Hi, I'm Lena Vogt, a cera…` (0.75) | 0.33 | 0.87 | – | ✅ | ✅ |  |
| B04_birth_year | Birth year | `1994` | 0 | `Born in 1994 and raised o…` (0.70) | 0.92 | 0.04 | `1994` (1.00, 149) | ✅ | ✅ |  |
| B04_birth_year | Birth year | `1994` | 1 | `Born in 1994 and raised o…` (0.68) | 0.92 | 0.04 | `1994` (1.00, 149) | ✅ | ✅ |  |
| B05_phone_NEG | Phone | ∅ (none) | 0 | ∅ (none) (0.96) | 0.13 | 0.05 | – | ✅ | ✅ |  |
| B05_phone_NEG | Phone | ∅ (none) | 1 | ∅ (none) (0.98) | 0.16 | 0.05 | – | ✅ | ✅ |  |
| B06_biography ⚠ | Biography | `Hi, I'm Lena Vogt, a ceramicist w…` | 0 | `Hi, I'm Lena Vogt, a cera…` (0.62) | 0.39 | 0.74 | – | ❌ | ❌ ∅ (none) |  |
| B06_biography ⚠ | Biography | `Hi, I'm Lena Vogt, a ceramicist w…` | 1 | `Hi, I'm Lena Vogt, a cera…` (0.62) | 0.37 | 0.71 | – | ❌ | ❌ ∅ (none) |  |
| B07_about_me ⚠ | About me | `Hi, I'm Lena Vogt, a ceramicist w…` | 0 | `Hi, I'm Lena Vogt, a cera…` (0.64) | 0.31 | 0.87 | – | ✅ | ✅ |  |
| B07_about_me ⚠ | About me | `Hi, I'm Lena Vogt, a ceramicist w…` | 1 | `Hi, I'm Lena Vogt, a cera…` (0.63) | 0.35 | 0.88 | – | ✅ | ✅ |  |
| B08_short_bio ⚠ | Short bio | `Hi, I'm Lena Vogt, a ceramicist w…` | 0 | `Hi, I'm Lena Vogt, a cera…` (0.53) | 0.46 | 0.25 | – | ✅ | ✅ |  |
| B08_short_bio ⚠ | Short bio | `Hi, I'm Lena Vogt, a ceramicist w…` | 1 | `Hi, I'm Lena Vogt, a cera…` (0.54) | 0.52 | 0.22 | `a ceramicist working out …` (0.22, 254) | ❌ | ❌ `a ceramicist working …` |  |
| T01_email_two_lines ⚠ | Email | `wren.castellan@example.net` | 0 | `Ticket 4711 wren.castella…` (0.54) | 0.94 | 0.11 | `wren.castellan@example.net` (0.85, 6) | ✅ | ✅ |  |
| T01_email_two_lines ⚠ | Email | `wren.castellan@example.net` | 1 | `Ticket 4711 wren.castella…` (0.42) | 0.94 | 0.08 | `wren.castellan@example.net` (0.67, 20) | ✅ | ✅ | 1 |
| C01_cover_letter ⚠ | Cover letter | `I am writing to apply for the Jun…` | 0 | `Dear Ms Hofer,⏎⏎I am writ…` (0.69) | 0.47 | 0.97 | – | ✅ | ✅ |  |
| C01_cover_letter ⚠ | Cover letter | `I am writing to apply for the Jun…` | 1 | `Dear Ms Hofer,⏎⏎I am writ…` (0.74) | 0.43 | 0.97 | – | ✅ | ✅ |  |
| C02_motivation | Motivation | `What draws me to Grünraum is your…` | 0 | `What draws me to Grünraum…` (0.92) | 0.47 | 0.59 | – | ✅ | ✅ |  |
| C02_motivation | Motivation | `What draws me to Grünraum is your…` | 1 | `What draws me to Grünraum…` (0.92) | 0.38 | 0.60 | – | ✅ | ✅ |  |
| C03_availability | Availability | `I can start on 1 December 2026 an…` | 0 | `I can start on 1 December…` (0.66) | 0.62 | 0.22 | `1 December 2026 and am av…` (0.78, 125) | ❌ | ❌ `1 December 2026 and a…` |  |
| C03_availability | Availability | `I can start on 1 December 2026 an…` | 1 | `I can start on 1 December…` (0.68) | 0.66 | 0.31 | `1 December 2026 and am av…` (0.82, 125) | ❌ | ❌ `1 December 2026 and a…` |  |
| C04_name | Name | `Theo Brandner` | 0 | `Theo Brandner` (0.97) | 0.64 | 0.43 | `Theo Brandner` (1.00, 3) | ✅ | ✅ |  |
| C04_name | Name | `Theo Brandner` | 1 | `Theo Brandner` (0.98) | 0.62 | 0.51 | `Theo Brandner` (1.00, 3) | ✅ | ✅ |  |
| C05_notes_freetext ⚠ | Notes | `Dear Ms Hofer,⏎⏎I am writing to a…` | 0 | ∅ (none) (0.55) | 0.35 | 0.88 | – | ❌ | ✅ |  |
| C05_notes_freetext ⚠ | Notes | `Dear Ms Hofer,⏎⏎I am writing to a…` | 1 | ∅ (none) (0.50) | 0.28 | 0.87 | – | ❌ | ✅ |  |

⚠ = borderline cell (see fixtures). † = stage 2 would not run in production (free_text override).

## Hit counts

| item | observations | J hits | production hits | stage-1 choice already the excerpt |
|---|---|---|---|---|
| address | 28 | 22 | 22 | 16 |
| signature | 18 | 18 | 18 | 2 |
| resume | 20 | 14 | 10 | 14 |
| order | 18 | 18 | 18 | 2 |
| bio | 16 | 11 | 11 | 10 |
| tickets | 2 | 2 | 2 | 0 |
| cover | 10 | 6 | 8 | 6 |
| **all** | 112 | 91 | 89 | 50 |

## Pass criteria (fixed by Daniel)

1. Address, signature, résumé — every listed field, both runs: **FAIL** (10 misses of 52).
   - A01_vorname run 0: pasted `Mira Holzner` via stage1_candidate (expected `Mira`)
   - A01_vorname run 1: pasted `Mira Holzner` via stage1_candidate (expected `Mira`)
   - A02_nachname run 0: pasted `Mira Holzner` via stage1_candidate (expected `Holzner`)
   - A03_strasse run 0: pasted `Prankergasse 77` via stage1_candidate (expected `Prankergasse`); borderline
   - A03_strasse run 1: pasted `Prankergasse 77` via stage1_candidate (expected `Prankergasse`); borderline
   - A07_ort run 1: pasted `8020 Graz` via stage1_candidate (expected `Graz`)
   - R05_about run 0: pasted `Anna Reisinger⏎Born 14 March 1991 in Linz⏎Nationality: Aust…` via free_text_whole_item (expected `Data engineer with eight years of exper…`)
   - R05_about run 1: pasted `Anna Reisinger⏎Born 14 March 1991 in Linz⏎Nationality: Aust…` via free_text_whole_item (expected `Data engineer with eight years of exper…`)
   - R06_country run 0: pasted ∅ (none) via no_suitable_match (expected `Austria`); borderline
   - R06_country run 1: pasted ∅ (none) via no_suitable_match (expected `Austria`); borderline
2. `contains_more` fires correctly on every cell: **FAIL** (17 wrong of 100 observations).
   - A01_vorname run 0: P=0.30, should fire
   - A01_vorname run 1: P=0.13, should fire
   - A02_nachname run 0: P=0.19, should fire
   - A03_strasse run 0: P=0.36, should fire
   - A03_strasse run 1: P=0.33, should fire
   - A07_ort run 1: P=0.36, should fire
   - R04_nationality run 0: P=0.59, should stay low
   - R04_nationality run 1: P=0.62, should stay low
   - R05_about run 0: P=0.52, should stay low
   - R05_about run 1: P=0.50, should stay low
   - R06_country run 0: P=0.38, should fire
   - R06_country run 1: P=0.29, should fire
   - B08_short_bio run 1: P=0.52, should stay low
   - C03_availability run 0: P=0.62, should stay low
   - C03_availability run 1: P=0.66, should stay low
   - C04_name run 0: P=0.64, should stay low
   - C04_name run 1: P=0.62, should stay low
3. Negative cells end in `none_of_these`/No Suitable Match: **PASS** (12 of 12).

## Gate 2×2 (positive cells, both runs; threshold 0.5)

| | gate fired (≥ 0.5) | gate low |
|---|---|---|
| needs a sub-span | 50 | 8 |
| expected is a whole Candidate | 9 | 33 |

P(contains_more) — needs sub-span: min 0.13, median 0.90; whole Candidate: max 0.66, median 0.34. Negatives (not in the 2×2): A13_passwort_NEG r0 0.14, A13_passwort_NEG r1 0.15, A14_fax_NEG r0 0.13, A14_fax_NEG r1 0.12, S09_fax_NEG r0 0.15, S09_fax_NEG r1 0.15, R07_linkedin_NEG r0 0.16, R07_linkedin_NEG r1 0.13, O09_coupon_NEG r0 0.37, O09_coupon_NEG r1 0.33, B05_phone_NEG r0 0.13, B05_phone_NEG r1 0.16.

## Gate tuning history (before the v7 matrix)

P(contains_more) per wording; ▲ = should fire, ▽ = should stay low. v5/v6 withdrawn (named field types).

| cell | | v1 | v2 | v3 | v4 | v5 | v6 |
|---|---|---|---|---|---|---|---|
| A01_vorname | ▲ | 0.50 | 0.40 | 0.44 | 0.29 | 0.64 | 0.85 |
| A06_plz | ▲ | 0.29 | 0.48 | 0.58 | 0.55 | 0.68 | 0.46 |
| A08_land | ▽ | 0.27 | 0.12 | 0.17 | 0.17 | 0.17 | 0.17 |
| A12_strasse_hnr | ▽ | 0.32 | 0.13 | 0.25 | 0.42 | 0.17 | 0.18 |
| B01_handle | ▲ | 0.90 |  |  |  |  |  |
| B03_bio | ▽ |  |  | 0.43 |  | 0.50 | 0.28 |
| B07_about_me | ▽ |  |  |  |  |  | 0.24 |
| O07_amount | ▲ |  |  | 0.89 |  | 0.40 | 0.65 |
| R04_nationality | ▽ |  |  | 0.43 |  | 0.08 | 0.10 |
| R05_about | ▽ | 0.48 |  |  |  |  |  |
| S01_first_name | ▲ |  |  |  |  |  | 0.73 |
| S04_phone | ▲ | 0.94 |  | 0.95 | 0.91 | 0.86 | 0.85 |

## Withdrawn v6 matrix (run 0, 37 cells before the stop)

J hits 29/37, production hits 26/37; gate wrong on 8: A03_strasse, A04_hausnummer, A07_ort, S06_email, S07_website, S08_iban, R06_country, R09_biography.

Shadow stage 2 during that run (gate low, Candidate ≤ 12 tokens so it is offered whole among its spans; stage-2 wording has no field vocabulary, so this stays valid): would a gate-free J keep or cut the Candidate?

| cell | stage-1 Candidate | shadow span (prob) | shadow hit | J hit |
|---|---|---|---|---|
| A03_strasse | `Prankergasse 77` | `Prankergasse` (0.85) | ✅ | ❌ |
| A04_hausnummer | `Prankergasse 77` | `77` (1.00) | ✅ | ❌ |
| A05_adresszusatz | `Top 11` | `Top 11` (0.98) | ✅ | ✅ |
| A07_ort | `8020 Graz` | `Graz` (0.99) | ✅ | ❌ |
| A10_website | `https://www.miraholzner.examp…` | `https://www.miraholzner.examp…` (1.00) | ✅ | ✅ |
| A12_strasse_hnr | `Prankergasse 77` | `Prankergasse 77` (0.98) | ✅ | ✅ |
| R01_full_name | `Anna Reisinger` | `Anna Reisinger` (1.00) | ✅ | ✅ |
| S06_email | `jonas.prell@example.com | www…` | `jonas.prell@example.com` (1.00) | ✅ | ❌ |
| S07_website | `jonas.prell@example.com | www…` | `www.prell.example` (1.00) | ✅ | ❌ |
| S08_iban | `IBAN AT61 1904 3002 3457 3201` | `AT61 1904 3002 3457 3201` (1.00) | ✅ | ❌ |

## Stage 3 — recursive refinement below the token

| cell | start piece | level | gate P | options (before cap) | pick (prob) | stop | final | hit | calls/paste |
|---|---|---|---|---|---|---|---|---|---|
| B02_city | `Innsbruck.` | 3 | 0.10 | – | – | gate says no | `Innsbruck.` | ❌ | 3 |
| N01_strasse_glued | `Prankergasse77` | 3 | 0.73 | 100 (100) | `Prankergasse` (0.51) |  | `Prankergasse` | ✅ | 3 |
|  |  | 4 | 0.14 | – | – | gate says no |  |  |  |
| N02_hausnummer_glued | `Prankergasse77` | 3 | 0.88 | 100 (100) | `77` (0.82) |  | `77` | ✅ | 3 |
|  |  | 4 | 0.14 | – | – | gate says no |  |  |  |
| N03_benutzername | ∅ (none) | – | – | – | – |  | ∅ (none) | ❌ | 1 |

Stage-3 call latency: n=5, median 893 ms, p90 997 ms, max 1049 ms.

## Reachability (was the expected excerpt offered at all?)

Offline, from the item alone: every positive cell's expected excerpt (or a listed accept) is a whole Candidate, a span of some Candidate, or unreachable by the cut rules.

| cell | expected | reachable as | reason if not | offered in the run's stage 2 (r0/r1) |
|---|---|---|---|---|
| A01_vorname | `Mira` | span |  | –/– |
| A02_nachname | `Holzner` | span |  | –/yes |
| A03_strasse | `Prankergasse` | span |  | –/– |
| A04_hausnummer | `77` | span |  | yes/yes |
| A05_adresszusatz | `Top 11` | whole Candidate |  | –/– |
| A06_plz | `8020` | span |  | yes/yes |
| A07_ort | `Graz` | span |  | yes/– |
| A08_land | `Österreich` | whole Candidate |  | –/– |
| A09_email | `mira.holzner@example.org` | whole Candidate |  | –/– |
| A10_website | `https://www.miraholzner.examp…` | whole Candidate |  | –/– |
| A11_telefon | `06608405534` | whole Candidate |  | –/– |
| A12_strasse_hnr | `Prankergasse 77` | whole Candidate |  | –/– |
| S01_first_name | `Jonas` | span |  | yes/yes |
| S02_last_name | `Prell` | span |  | yes/yes |
| S03_job_title | `Product Lead` | span |  | yes/yes |
| S04_phone | `+43 1 2345678` | span |  | yes/yes |
| S05_mobile | `+43 660 1112233` | span |  | yes/yes |
| S06_email | `jonas.prell@example.com` | span |  | yes/yes |
| S07_website | `www.prell.example` | span |  | yes/yes |
| S08_iban | `AT61 1904 3002 3457 3201` | span |  | yes/yes |
| R01_full_name | `Anna Reisinger` | whole Candidate |  | –/– |
| R02_birthdate | `14 March 1991` | span |  | yes/yes |
| R03_birthplace | `Linz` | span |  | yes/yes |
| R04_nationality | `Austrian` | whole Candidate |  | yes/yes |
| R05_about | `Data engineer with eight year…` | whole Candidate |  | no/no |
| R06_country | `Austria` | span |  | –/– |
| R08_summary | `Data engineer with eight year…` | whole Candidate |  | –/– |
| R09_biography | `Data engineer with eight year…` | whole Candidate |  | –/– |
| R10_description | `Data engineer with eight year…` | whole Candidate |  | –/– |
| O01_email | `wren.castellan@example.net` | span |  | yes/yes |
| O02_order_number | `4711` | span |  | yes/yes |
| O03_recipient | `Lise Adler` | span |  | yes/yes |
| O04_street | `Hauptstr. 5` | span |  | yes/yes |
| O05_postal_code | `4020` | span |  | yes/yes |
| O06_city | `Linz` | span |  | yes/yes |
| O07_amount | `129,90` | span |  | yes/yes |
| O08_tracking | `00340434161234567890` | span |  | yes/yes |
| B01_handle | `@mira_h` | span |  | yes/yes |
| B02_city | `Innsbruck` | stage-3 substring of `Innsbruck.` | no cut after: `.` | no/no |
| B03_bio | `Hi, I'm Lena Vogt, a ceramici…` | whole Candidate |  | –/– |
| B04_birth_year | `1994` | span |  | yes/yes |
| B06_biography | `Hi, I'm Lena Vogt, a ceramici…` | whole Candidate |  | –/– |
| B07_about_me | `Hi, I'm Lena Vogt, a ceramici…` | whole Candidate |  | –/– |
| B08_short_bio | `Hi, I'm Lena Vogt, a ceramici…` | whole Candidate |  | –/no |
| T01_email_two_lines | `wren.castellan@example.net` | span |  | yes/yes |
| C01_cover_letter | `I am writing to apply for the…` | UNREACHABLE (accept: whole Candidate) | 86 tokens > 12 (and not inside one token) | –/– |
| C02_motivation | `What draws me to Grünraum is …` | whole Candidate |  | –/– |
| C03_availability | `I can start on 1 December 202…` | whole Candidate |  | no/no |
| C04_name | `Theo Brandner` | whole Candidate |  | yes/yes |
| C05_notes_freetext | `Dear Ms Hofer,⏎⏎I am writing …` | whole Candidate |  | –/– |

Unreachable cells: **1** (counted apart from Jev misses). Spans per stage-2 call: min 1, median 20, max 254 (n=59); the same parents with the extended cut set `@ . - _`: min 1, median 21, max 254 (both after the 254 cap).

## Latency (billed calls, client-side round trip)

| call | warm | cold |
|---|---|---|
| j_stage1 | n=148, median 564 ms, p90 906 ms, max 2327 ms | n=13, median 731 ms, p90 1072 ms, max 1416 ms |
| j_stage2 | n=76, median 533 ms, p90 864 ms, max 2562 ms | – |
| tune | n=30, median 524 ms, p90 755 ms, max 1265 ms | n=5, median 575 ms, p90 1328 ms, max 1707 ms |
| j_stage2_shadow | n=10, median 517 ms, p90 629 ms, max 698 ms | – |

J total per paste (production calls only): n=112, median 945 ms, p90 1540 ms, max 3181 ms. Pastes that needed stage 2: n=57, median 1184 ms, p90 1848 ms, max 3181 ms.

## Chooser noise (same-type spans next to the stage-2 winner)

| cell | run | winner | type | other same-type spans |
|---|---|---|---|---|
| A02_nachname | 1 | `Holzner` | – | 0  |
| A04_hausnummer | 0 | `77` | – | 0  |
| A04_hausnummer | 1 | `77` | – | 0  |
| A06_plz | 0 | `8020` | – | 0  |
| A06_plz | 1 | `8020` | – | 0  |
| A07_ort | 0 | `Graz` | – | 0  |
| S01_first_name | 0 | `Jonas` | – | 0  |
| S01_first_name | 1 | `Jonas` | – | 0  |
| S02_last_name | 0 | `Prell` | – | 0  |
| S02_last_name | 1 | `Prell` | – | 0  |
| S03_job_title | 0 | `Product Lead` | – | 0  |
| S03_job_title | 1 | `Product Lead` | – | 0  |
| S04_phone | 0 | `+43 1 2345678` | phone | 2 `+43 660 1112233` `660 1112233` |
| S04_phone | 1 | `+43 1 2345678` | phone | 2 `+43 660 1112233` `660 1112233` |
| S05_mobile | 0 | `+43 660 1112233` | phone | 2 `+43 1 2345678` `660 1112233` |
| S05_mobile | 1 | `+43 660 1112233` | phone | 2 `+43 1 2345678` `660 1112233` |
| S06_email | 0 | `jonas.prell@example.com` | email | 0  |
| S06_email | 1 | `jonas.prell@example.com` | email | 0  |
| S07_website | 0 | `www.prell.example` | url | 0  |
| S07_website | 1 | `www.prell.example` | url | 0  |
| S08_iban | 0 | `AT61 1904 3002 3457 3201` | – | 0  |
| S08_iban | 1 | `AT61 1904 3002 3457 3201` | – | 0  |
| R02_birthdate | 0 | `14 March 1991` | – | 0  |
| R02_birthdate | 1 | `14 March 1991` | – | 0  |
| R03_birthplace | 0 | `Linz` | – | 0  |
| R03_birthplace | 1 | `Linz` | – | 0  |
| R04_nationality | 0 | `Austrian` | – | 0  |
| R04_nationality | 1 | `Austrian` | – | 0  |
| R05_about | 0 | ∅ (none) | – | 0  |
| R05_about | 1 | ∅ (none) | – | 0  |
| O01_email | 0 | `wren.castellan@example.net` | email | 0  |
| O01_email | 1 | `wren.castellan@example.net` | email | 0  |
| O02_order_number | 0 | `4711` | – | 0  |
| O02_order_number | 1 | `4711` | – | 0  |
| O03_recipient | 0 | `Lise Adler` | – | 0  |
| O03_recipient | 1 | `Lise Adler` | – | 0  |
| O04_street | 0 | `Hauptstr. 5` | – | 0  |
| O04_street | 1 | `Hauptstr. 5` | – | 0  |
| O05_postal_code | 0 | `4020` | – | 0  |
| O05_postal_code | 1 | `4020` | – | 0  |
| O06_city | 0 | `Linz` | – | 0  |
| O06_city | 1 | `Linz` | – | 0  |
| O07_amount | 0 | `129,90` | – | 0  |
| O07_amount | 1 | `129,90` | – | 0  |
| O08_tracking | 0 | `00340434161234567890` | – | 0  |
| O08_tracking | 1 | `00340434161234567890` | – | 0  |
| B01_handle | 0 | `@mira_h` | handle | 0  |
| B01_handle | 1 | `@mira_h` | handle | 0  |
| B02_city | 0 | `Innsbruck.` | – | 0  |
| B02_city | 1 | `Innsbruck.` | – | 0  |
| B04_birth_year | 0 | `1994` | – | 0  |
| B04_birth_year | 1 | `1994` | – | 0  |
| B08_short_bio | 1 | `a ceramicist working out of…` | – | 0  |
| T01_email_two_lines | 0 | `wren.castellan@example.net` | email | 0  |
| T01_email_two_lines | 1 | `wren.castellan@example.net` | email | 1 `lise.adler@example.net` |
| C03_availability | 0 | `1 December 2026 and am avai…` | – | 0  |
| C03_availability | 1 | `1 December 2026 and am avai…` | – | 0  |
| C04_name | 0 | `Theo Brandner` | – | 0  |
| C04_name | 1 | `Theo Brandner` | – | 0  |

## L rescue

| cell | model | route | status | answer | byte-exact substring | hit | latency |
|---|---|---|---|---|---|---|---|
| A01_vorname | deepseek/deepseek-v4.1-flash | gateway | stopped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| A02_nachname | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| A03_strasse | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| A07_ort | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| R05_about | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| R06_country | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| R08_summary | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| R09_biography | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| R10_description | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| B02_city | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| B06_biography | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| B08_short_bio | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| C03_availability | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| C05_notes_freetext | deepseek/deepseek-v4.1-flash | gateway | skipped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| A01_vorname | openai/gpt-6-luna | gateway | stopped: HTTP 403 after 3 retries: {'error':… | ∅ (none) | – | – | – |
| A01_vorname | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 4581 ms |
| A02_nachname | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 3731 ms |
| A03_strasse | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 4444 ms |
| A07_ort | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 3799 ms |
| R05_about | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 3813 ms |
| R06_country | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 4219 ms |
| R08_summary | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 4773 ms |
| R09_biography | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 6421 ms |
| R10_description | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 4186 ms |
| B02_city | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 4785 ms |
| B06_biography | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 6172 ms |
| B08_short_bio | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 5124 ms |
| C03_availability | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 3757 ms |
| C05_notes_freetext | openai/gpt-6-luna | codex exec | exit 1 no content | ∅ (none) | – | – | 3836 ms |
| A01_vorname | codex/gpt-5.6-luna (substitute) | codex exec | ok | `Mira` | yes | ✅ | 5504 ms |
| A02_nachname | codex/gpt-5.6-luna (substitute) | codex exec | ok | `Holzner` | yes | ✅ | 6140 ms |
| A03_strasse | codex/gpt-5.6-luna (substitute) | codex exec | ok | `Prankergasse` | yes | ✅ | 6240 ms |
| A07_ort | codex/gpt-5.6-luna (substitute) | codex exec | ok | `Graz` | yes | ✅ | 5501 ms |
| R05_about | codex/gpt-5.6-luna (substitute) | codex exec | ok | `Data engineer with eight year…` | yes | ✅ | 6780 ms |
| R06_country | codex/gpt-5.6-luna (substitute) | codex exec | ok | `NONE` | yes | ❌ | 7606 ms |
| R08_summary | codex/gpt-5.6-luna (substitute) | codex exec | ok | `Data engineer with eight year…` | yes | ✅ | 7600 ms |
| R09_biography | codex/gpt-5.6-luna (substitute) | codex exec | ok | `Data engineer with eight year…` | yes | ✅ | 8847 ms |
| R10_description | codex/gpt-5.6-luna (substitute) | codex exec | ok | `Data engineer with eight year…` | yes | ✅ | 6883 ms |
| B02_city | codex/gpt-5.6-luna (substitute) | codex exec | ok | `Innsbruck` | yes | ✅ | 5125 ms |
| B06_biography | codex/gpt-5.6-luna (substitute) | codex exec | ok | `Hi, I'm Lena Vogt, a ceramici…` | yes | ✅ | 10023 ms |
| B08_short_bio | codex/gpt-5.6-luna (substitute) | codex exec | ok | `Born in 1994 and raised on a …` | yes | ❌ | 8195 ms |
| C03_availability | codex/gpt-5.6-luna (substitute) | codex exec | ok | `I can start on 1 December 202…` | yes | ❌ | 7227 ms |
| C05_notes_freetext | codex/gpt-5.6-luna (substitute) | codex exec | ok | `I am happy to relocate for th…` | yes | ❌ | 7694 ms |

## Calls and cost

Billed Jev calls logged: 288 (j_stage1 161, j_stage2 76, tune 35, j_stage2_shadow 10, stage3_gate 3, stage3_choice 3) + 3 smoke calls reported but not logged. Jev cost (Gateway metadata): $0.01774 for 422476 input tokens.

Production calls per paste (matrix): mean 1.51; pastes needing stage 2: 57 of 112.

