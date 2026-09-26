#!/bin/bash
# PROTOTYPE — menu-settings, never merged. Round-1 contact sheets from /tmp/proto-shots.
D=/tmp/proto-shots; O=docs/prototype/menu-settings; C=scripts/prototype-contact-sheet.py
python3 $C $O/sheet-menu.png "Q1 — History Search: Menu A (real NSMenu) vs Menu B (menu-shaped panel)" \
 $D/menu-1.png "A — empty: placeholder = Active Item" $D/menu-2.png "A — typed “ex”" \
 $D/menu-3.png "B — empty: placeholder = Active Item" $D/menu-4.png "B — typed “ex”"
python3 $C $O/sheet-rows.png "Q2 — row look (query “ex”; Active Item = first row)" \
 $D/rows-1.png "Rows 1 plain + ✓ — in A" $D/rows-2.png "Rows 1 plain + ✓ — in B" \
 $D/rows-3.png "Rows 2 two lines + dot — in A" $D/rows-4.png "Rows 2 two lines + dot — in B" \
 $D/rows-5.png "Rows 3 symbol + Active tag — in A" $D/rows-6.png "Rows 3 symbol + Active tag — in B"
python3 $C $O/sheet-settings.png "Q3 — Settings layouts (row 1: tabs · row 2: sidebar · row 3: one page)" \
 $D/settings-1.png "S1 Jev Provider, Test ✓" $D/settings-2.png "S1 refusal → Typesafe key" \
 $D/settings-3.png "S1 … Test on empty key" $D/settings-4.png "S1 Full History" \
 $D/settings-5.png "S2 Jev Provider, Test ✓" $D/settings-6.png "S2 refusal → Typesafe key" \
 $D/settings-7.png "S2 … Test on empty key" $D/settings-8.png "S2 Full History" \
 $D/settings-9.png "S3 Jev Provider, Test ✓" $D/settings-10.png "S3 refusal → Typesafe key" \
 $D/settings-11.png "S3 … Test on empty key" $D/settings-12.png "S3 Full History"
