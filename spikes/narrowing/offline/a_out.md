## A summary
| rule | group | pastes | known hit | known miss | fixed vs A0 | broken vs A0 | unknown: step exact / path / miss | unknown where A0 hit / missed |
|---|---|---|---|---|---|---|---|---|
| A0 | round-1 | 128 | 121 | 7 | 0 | 0 | 0 / 0 / 0 | 0 / 0 |
| A0 | held-out | 36 | 36 | 0 | 0 | 0 | 0 / 0 / 0 | 0 / 0 |
| A1(0.5) | round-1 | 128 | 111 | 3 | 0 | 0 | 1 / 12 / 1 | 10 / 4 |
| A1(0.5) | held-out | 36 | 31 | 0 | 0 | 0 | 0 / 2 / 3 | 5 / 0 |
| A1(0.6) | round-1 | 128 | 108 | 9 | 0 | 4 | 0 / 11 / 0 | 9 / 2 |
| A1(0.6) | held-out | 36 | 29 | 0 | 0 | 0 | 0 / 5 / 2 | 7 / 0 |
| A1(0.7) | round-1 | 128 | 102 | 15 | 0 | 8 | 0 / 11 / 0 | 11 / 0 |
| A1(0.7) | held-out | 36 | 27 | 1 | 0 | 1 | 0 / 8 / 0 | 8 / 0 |

## A changes vs A0 (first differing step)
| rule | cell | run | group | A0 result | A0 | step | Jev pick (p) | rule pick | rule result |
|---|---|---|---|---|---|---|---|---|---|
| A1(0.5) | A03_strasse | 0 | round-1 | hit | `Prankergasse` | 1 | `Prankergasse` (0.39) | `Prankergasse 77` | unknown; step path |
| A1(0.5) | R05_about | 1 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.49) | `Anna Reisinger⏎Born 14…` | unknown; step path |
| A1(0.5) | R08_summary | 0 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.49) | `Anna Reisinger⏎Born 14…` | unknown; step path |
| A1(0.5) | R09_biography | 0 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.37) | `Anna Reisinger⏎Born 14…` | unknown; step path |
| A1(0.5) | R09_biography | 1 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.29) | `Anna Reisinger⏎Born 14…` | unknown; step path |
| A1(0.5) | R10_description | 0 | round-1 | MISS | `Anna Reisinger⏎Born 14…` | 1 | keep (0.37) | `Anna Reisinger⏎Born 14…` | unknown; step path |
| A1(0.5) | R10_description | 1 | round-1 | MISS | `Anna Reisinger⏎Born 14…` | 1 | keep (0.30) | `Anna Reisinger⏎Born 14…` | unknown; step path |
| A1(0.5) | O02_order_number | 0 | round-1 | hit | `4711` | 1 | `4711` (0.46) | `Order 4711` | unknown; step path |
| A1(0.5) | O02_order_number | 1 | round-1 | hit | `4711` | 1 | `4711` (0.42) | `Order 4711` | unknown; step path |
| A1(0.5) | O04_street | 0 | round-1 | hit | `Hauptstr. 5` | 1 | `Hauptstr. 5` (0.47) | `, Hauptstr. 5` | unknown; step path |
| A1(0.5) | B08_short_bio | 1 | round-1 | hit | `Hi, I'm Lena Vogt, a c…` | 1 | keep (0.18) | `Hi, I'm Lena Vogt, a c…` | unknown; step path |
| A1(0.5) | C03_availability | 0 | round-1 | MISS | `I can start on 1 Decem…` | 1 | `I can start on 1 Decem…` (0.39) | `I can start on 1 Decem…` | unknown; step exact |
| A1(0.5) | C03_availability | 1 | round-1 | MISS | `I can start on 1 Decem…` | 1 | `I can start on 1 Decem…` (0.38) | `I want to learn how pl…` | unknown; step miss |
| A1(0.5) | C04_name | 1 | round-1 | hit | `Theo Brandner` | 1 | `Theo Brandner` (0.45) | `I am happy to relocate…` | unknown; step path |
| A1(0.5) | H05_messages_composer | 0 | held-out | hit | `Brunner Holzbau GmbH⏎o…` | 1 | keep (0.23) | `Brunner Holzbau GmbH⏎o…` | unknown; step miss |
| A1(0.5) | H05_messages_composer | 1 | held-out | hit | `Brunner Holzbau GmbH⏎o…` | 1 | keep (0.22) | `Brunner Holzbau GmbH⏎o…` | unknown; step miss |
| A1(0.5) | H07_url_slack | 1 | held-out | hit | `https://docs.northbeam…` | 1 | keep (0.37) | `ttps://docs.northbeam.…` | unknown; step miss |
| A1(0.5) | H13_strasse_hausnummer | 1 | held-out | hit | `Leopoldstraße 41` | 1 | `Leopoldstraße 41` (0.48) | `Sabine Gruber⏎Leopolds…` | unknown; step path |
| A1(0.5) | H14_empfaenger | 1 | held-out | hit | `Brunner Holzbau GmbH` | 1 | `Brunner Holzbau GmbH` (0.47) | `Rechnung Nr. 2027-0142…` | unknown; step path |
| A1(0.6) | A03_strasse | 0 | round-1 | hit | `Prankergasse` | 1 | `Prankergasse` (0.39) | `Mira Holzner⏎Prankerga…` | unknown; step path |
| A1(0.6) | A12_strasse_hnr | 0 | round-1 | hit | `Prankergasse 77` | 1 | `Prankergasse 77` (0.55) | `Mira Holzner⏎Prankerga…` | unknown; step path |
| A1(0.6) | R05_about | 0 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.55) | `Anna Reisinger⏎Born 14…` | unknown; step path |
| A1(0.6) | R05_about | 1 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.49) | `Anna Reisinger⏎Born 14…` | unknown; step path |
| A1(0.6) | R08_summary | 0 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.49) | keep | MISS `Anna Reisinger⏎Born 14…` |
| A1(0.6) | R09_biography | 0 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.37) | keep | MISS `Anna Reisinger⏎Born 14…` |
| A1(0.6) | R09_biography | 1 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.29) | keep | MISS `Anna Reisinger⏎Born 14…` |
| A1(0.6) | O02_order_number | 0 | round-1 | hit | `4711` | 1 | `4711` (0.46) | `Order 4711` | unknown; step path |
| A1(0.6) | O02_order_number | 1 | round-1 | hit | `4711` | 1 | `4711` (0.42) | `Order 4711` | unknown; step path |
| A1(0.6) | O04_street | 0 | round-1 | hit | `Hauptstr. 5` | 1 | `Hauptstr. 5` (0.47) | `Lise Adler, Hauptstr. …` | unknown; step path |
| A1(0.6) | O07_amount | 0 | round-1 | hit | `129,90` | 1 | `129,90` (0.50) | `Total EUR 129,90` | unknown; step path |
| A1(0.6) | C03_availability | 0 | round-1 | MISS | `I can start on 1 Decem…` | 1 | `I can start on 1 Decem…` (0.39) | `I want to learn how pl…` | unknown; step path |
| A1(0.6) | C03_availability | 1 | round-1 | MISS | `I can start on 1 Decem…` | 1 | `I can start on 1 Decem…` (0.38) | `Dear Ms Hofer,⏎⏎I am w…` | unknown; step path |
| A1(0.6) | C04_name | 1 | round-1 | hit | `Theo Brandner` | 1 | `Theo Brandner` (0.45) | `ear Ms Hofer,⏎⏎I am wr…` | unknown; step path |
| A1(0.6) | N03_list_300_lines | 1 | round-1 | hit | `WINTER-4471-KQ` | 1 | `2026-09-12 12:41:02 IN…` (0.55) | keep | MISS `2026-09-12 08:00:03 IN…` |
| A1(0.6) | H05_messages_composer | 0 | held-out | hit | `Brunner Holzbau GmbH⏎o…` | 1 | keep (0.23) | `Brunner Holzbau GmbH⏎o…` | unknown; step miss |
| A1(0.6) | H05_messages_composer | 1 | held-out | hit | `Brunner Holzbau GmbH⏎o…` | 1 | keep (0.22) | `Brunner Holzbau GmbH⏎o…` | unknown; step miss |
| A1(0.6) | H12_address_line_1 | 0 | held-out | hit | `Kirchgasse 9` | 1 | `Kirchgasse 9` (0.50) | `Florian Mair⏎Kirchgass…` | unknown; step path |
| A1(0.6) | H12_address_line_1 | 1 | held-out | hit | `Kirchgasse 9` | 1 | `Kirchgasse 9` (0.51) | `Florian Mair⏎Kirchgass…` | unknown; step path |
| A1(0.6) | H13_strasse_hausnummer | 1 | held-out | hit | `Leopoldstraße 41` | 1 | `Leopoldstraße 41` (0.48) | `Sabine Gruber⏎Leopolds…` | unknown; step path |
| A1(0.6) | H14_empfaenger | 1 | held-out | hit | `Brunner Holzbau GmbH` | 1 | `Brunner Holzbau GmbH` (0.47) | `Rechnung Nr. 2027-0142…` | unknown; step path |
| A1(0.6) | H15_mobile | 0 | held-out | hit | `+43 664 918 2735` | 1 | `+43 664 918 2735` (0.56) | `Mobile +43 664 918 273…` | unknown; step path |
| A1(0.7) | A03_strasse | 0 | round-1 | hit | `Prankergasse` | 1 | `Prankergasse` (0.39) | `Mira Holzner⏎Prankerga…` | unknown; step path |
| A1(0.7) | A12_strasse_hnr | 0 | round-1 | hit | `Prankergasse 77` | 1 | `Prankergasse 77` (0.55) | `Mira Holzner⏎Prankerga…` | unknown; step path |
| A1(0.7) | A12_strasse_hnr | 1 | round-1 | hit | `Prankergasse 77` | 1 | `Prankergasse 77` (0.60) | `Mira Holzner⏎Prankerga…` | unknown; step path |
| A1(0.7) | S08_iban | 0 | round-1 | hit | `AT61 1904 3002 3457 32…` | 1 | `AT61 1904 3002 3457 32…` (0.64) | `IBAN AT61 1904 3002 34…` | unknown; step path |
| A1(0.7) | R05_about | 0 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.55) | keep | MISS `Anna Reisinger⏎Born 14…` |
| A1(0.7) | R05_about | 1 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.49) | keep | MISS `Anna Reisinger⏎Born 14…` |
| A1(0.7) | R08_summary | 0 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.49) | keep | MISS `Anna Reisinger⏎Born 14…` |
| A1(0.7) | R08_summary | 1 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.65) | `Anna Reisinger⏎Born 14…` | unknown; step path |
| A1(0.7) | R09_biography | 0 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.37) | keep | MISS `Anna Reisinger⏎Born 14…` |
| A1(0.7) | R09_biography | 1 | round-1 | hit | `Data engineer with eig…` | 1 | `Data engineer with eig…` (0.29) | keep | MISS `Anna Reisinger⏎Born 14…` |
| A1(0.7) | O02_order_number | 0 | round-1 | hit | `4711` | 1 | `4711` (0.46) | `Order 4711` | unknown; step path |
| A1(0.7) | O02_order_number | 1 | round-1 | hit | `4711` | 1 | `4711` (0.42) | `Order 4711` | unknown; step path |
| A1(0.7) | O04_street | 0 | round-1 | hit | `Hauptstr. 5` | 1 | `Hauptstr. 5` (0.47) | `Lise Adler, Hauptstr. …` | unknown; step path |
| A1(0.7) | O04_street | 1 | round-1 | hit | `Hauptstr. 5` | 1 | `Hauptstr. 5` (0.57) | `Lise Adler, Hauptstr. …` | unknown; step path |
| A1(0.7) | O07_amount | 0 | round-1 | hit | `129,90` | 1 | `129,90` (0.50) | `Total EUR 129,90` | unknown; step path |
| A1(0.7) | C02_motivation | 1 | round-1 | hit | `What draws me to Grünr…` | 1 | `What draws me to Grünr…` (0.54) | `Dear Ms Hofer,⏎⏎I am w…` | unknown; step path |
| A1(0.7) | C03_availability | 0 | round-1 | MISS | `I can start on 1 Decem…` | 1 | `I can start on 1 Decem…` (0.39) | keep | MISS `Dear Ms Hofer,⏎⏎I am w…` |
| A1(0.7) | C03_availability | 1 | round-1 | MISS | `I can start on 1 Decem…` | 1 | `I can start on 1 Decem…` (0.38) | keep | MISS `Dear Ms Hofer,⏎⏎I am w…` |
| A1(0.7) | C04_name | 1 | round-1 | hit | `Theo Brandner` | 1 | `Theo Brandner` (0.45) | keep | MISS `Dear Ms Hofer,⏎⏎I am w…` |
| A1(0.7) | N03_list_300_lines | 0 | round-1 | hit | `WINTER-4471-KQ` | 1 | `2026-09-12 12:41:02 IN…` (0.61) | keep | MISS `2026-09-12 08:00:03 IN…` |
| A1(0.7) | N03_list_300_lines | 1 | round-1 | hit | `WINTER-4471-KQ` | 1 | `2026-09-12 12:41:02 IN…` (0.55) | keep | MISS `2026-09-12 08:00:03 IN…` |
| A1(0.7) | H02_flat_move_in | 0 | held-out | hit | `1 March 2027` | 1 | `1 March 2027` (0.68) | `on 1 March 2027` | MISS `on 1 March 2027` |
| A1(0.7) | H02_flat_move_in | 1 | held-out | hit | `1 March 2027` | 1 | `1 March 2027` (0.65) | `to move in on 1 March …` | unknown; step path |
| A1(0.7) | H12_address_line_1 | 0 | held-out | hit | `Kirchgasse 9` | 1 | `Kirchgasse 9` (0.50) | `Florian Mair⏎Kirchgass…` | unknown; step path |
| A1(0.7) | H12_address_line_1 | 1 | held-out | hit | `Kirchgasse 9` | 1 | `Kirchgasse 9` (0.51) | `Florian Mair⏎Kirchgass…` | unknown; step path |
| A1(0.7) | H13_strasse_hausnummer | 0 | held-out | hit | `Leopoldstraße 41` | 1 | `Leopoldstraße 41` (0.60) | `Sabine Gruber⏎Leopolds…` | unknown; step path |
| A1(0.7) | H13_strasse_hausnummer | 1 | held-out | hit | `Leopoldstraße 41` | 1 | `Leopoldstraße 41` (0.48) | `Sabine Gruber⏎Leopolds…` | unknown; step path |
| A1(0.7) | H14_empfaenger | 1 | held-out | hit | `Brunner Holzbau GmbH` | 1 | `Brunner Holzbau GmbH` (0.47) | `Rechnung Nr. 2027-0142…` | unknown; step path |
| A1(0.7) | H15_mobile | 0 | held-out | hit | `+43 664 918 2735` | 1 | `+43 664 918 2735` (0.56) | `Mobile +43 664 918 273…` | unknown; step path |
| A1(0.7) | H15_mobile | 1 | held-out | hit | `+43 664 918 2735` | 1 | `+43 664 918 2735` (0.67) | `Mobile +43 664 918 273…` | unknown; step path |

## Masses at the known misses' step 1 deciding choice (top 5 by mass among pieces)
R10_description r0 keep-mass 0.94 p_keep 0.37 p_nothing 0.04 | `Anna Reisinger⏎Born 14 M…` m=0.51 p=0.03; `Anna Reisinger⏎Born 14 M…` m=0.48 p=0.00; `Anna Reisinger⏎Born 14 M…` m=0.43 p=0.00; `nna Reisinger⏎Born 14 Ma…` m=0.43 p=0.02; `Anna Reisinger⏎Born 14 M…` m=0.41 p=0.11
R10_description r1 keep-mass 0.93 p_keep 0.30 p_nothing 0.05 | `Anna Reisinger⏎Born 14 M…` m=0.58 p=0.03; `Anna Reisinger⏎Born 14 M…` m=0.55 p=0.00; `Anna Reisinger⏎Born 14 M…` m=0.50 p=0.00; `Anna Reisinger⏎Born 14 M…` m=0.48 p=0.13; `nna Reisinger⏎Born 14 Ma…` m=0.47 p=0.02
B06_biography r0 keep-mass 0.59 p_keep 0.30 p_nothing 0.38 | `Hi, I'm Lena Vogt, a cer…` m=0.26 p=0.15; `i, I'm Lena Vogt, a cera…` m=0.12 p=0.00; `I post new glazes and ki…` m=0.06 p=0.00; `Born in 1994 and raised …` m=0.06 p=0.02; `and teach weekend wheel …` m=0.04 p=0.00
B06_biography r1 keep-mass 0.75 p_keep 0.21 p_nothing 0.22 | `Hi, I'm Lena Vogt, a cer…` m=0.48 p=0.11; `i, I'm Lena Vogt, a cera…` m=0.43 p=0.02; `, I'm Lena Vogt, a ceram…` m=0.41 p=0.00; `I post new glazes and ki…` m=0.39 p=0.02; `Hi, I'm Lena Vogt, a cer…` m=0.37 p=0.00
C03_availability r0 keep-mass 0.81 p_keep 0.13 p_nothing 0.03 | `Dear Ms Hofer,⏎⏎I am wri…` m=0.65 p=0.03; `Dear Ms Hofer,⏎⏎I am wri…` m=0.62 p=0.03; `I want to learn how plan…` m=0.61 p=0.00; `I am writing to apply fo…` m=0.58 p=0.00; `I want to learn how plan…` m=0.58 p=0.00
C03_availability r1 keep-mass 0.83 p_keep 0.14 p_nothing 0.06 | `Dear Ms Hofer,⏎⏎I am wri…` m=0.66 p=0.04; `Dear Ms Hofer,⏎⏎I am wri…` m=0.61 p=0.04; `ear Ms Hofer,⏎⏎I am writ…` m=0.60 p=0.01; `I want to learn how plan…` m=0.58 p=0.00; `I am writing to apply fo…` m=0.56 p=0.01
C04_name r0 keep-mass 0.88 p_keep 0.44 p_nothing 0.06 | `ear Ms Hofer,⏎⏎I am writ…` m=0.41 p=0.06; `I want to learn how plan…` m=0.29 p=0.00; `Dear Ms Hofer,⏎⏎I am wri…` m=0.26 p=0.03; `I can start on 1 Decembe…` m=0.22 p=0.00; `I am happy to relocate f…` m=0.21 p=0.01
C04_name r1 keep-mass 0.93 p_keep 0.27 p_nothing 0.04 | `ear Ms Hofer,⏎⏎I am writ…` m=0.64 p=0.06; `I want to learn how plan…` m=0.53 p=0.00; `I can start on 1 Decembe…` m=0.51 p=0.00; `I am happy to relocate f…` m=0.51 p=0.00; `Kind regards,⏎Theo Brand…` m=0.49 p=0.00

## A compact: every paste that any A1 rule changes
`=` unchanged · `hit` / `MISS` full paste known · `?exact` / `?path` / `?miss` full paste unknown, deciding step class
| cell | run | group | A0 | A1(0.5) | A1(0.6) | A1(0.7) |
|---|---|---|---|---|---|---|
| A03_strasse | 0 | round-1 | hit | ?path | ?path | ?path |
| A12_strasse_hnr | 0 | round-1 | hit | = | ?path | ?path |
| A12_strasse_hnr | 1 | round-1 | hit | = | = | ?path |
| S08_iban | 0 | round-1 | hit | = | = | ?path |
| R05_about | 0 | round-1 | hit | = | ?path | **MISS** |
| R05_about | 1 | round-1 | hit | ?path | ?path | **MISS** |
| R08_summary | 0 | round-1 | hit | ?path | **MISS** | **MISS** |
| R08_summary | 1 | round-1 | hit | = | = | ?path |
| R09_biography | 0 | round-1 | hit | ?path | **MISS** | **MISS** |
| R09_biography | 1 | round-1 | hit | ?path | **MISS** | **MISS** |
| R10_description | 0 | round-1 | **MISS** | ?path | = | = |
| R10_description | 1 | round-1 | **MISS** | ?path | = | = |
| O02_order_number | 0 | round-1 | hit | ?path | ?path | ?path |
| O02_order_number | 1 | round-1 | hit | ?path | ?path | ?path |
| O04_street | 0 | round-1 | hit | ?path | ?path | ?path |
| O04_street | 1 | round-1 | hit | = | = | ?path |
| O07_amount | 0 | round-1 | hit | = | ?path | ?path |
| B08_short_bio | 1 | round-1 | hit | ?path | = | = |
| C02_motivation | 1 | round-1 | hit | = | = | ?path |
| C03_availability | 0 | round-1 | **MISS** | ?exact | ?path | **MISS** |
| C03_availability | 1 | round-1 | **MISS** | ?miss | ?path | **MISS** |
| C04_name | 1 | round-1 | hit | ?path | ?path | **MISS** |
| N03_list_300_lines | 0 | round-1 | hit | = | = | **MISS** |
| N03_list_300_lines | 1 | round-1 | hit | = | **MISS** | **MISS** |
| H02_flat_move_in | 0 | held-out | hit | = | = | **MISS** |
| H02_flat_move_in | 1 | held-out | hit | = | = | ?path |
| H05_messages_composer | 0 | held-out | hit | ?miss | ?miss | = |
| H05_messages_composer | 1 | held-out | hit | ?miss | ?miss | = |
| H07_url_slack | 1 | held-out | hit | ?miss | = | = |
| H12_address_line_1 | 0 | held-out | hit | = | ?path | ?path |
| H12_address_line_1 | 1 | held-out | hit | = | ?path | ?path |
| H13_strasse_hausnummer | 0 | held-out | hit | = | = | ?path |
| H13_strasse_hausnummer | 1 | held-out | hit | ?path | ?path | ?path |
| H14_empfaenger | 1 | held-out | hit | ?path | ?path | ?path |
| H15_mobile | 0 | held-out | hit | = | ?path | ?path |
| H15_mobile | 1 | held-out | hit | = | = | ?path |
