# PROTOTYPE — history-probe, never merged

Question ([Validate history selection and visible paste feedback](https://github.com/DanielMulec/jevpaste/issues/9)):
what minimal in-app interaction makes (a) which item is Active and (b) what happened on paste unambiguous?
Three variants of a history surface, switchable at runtime from the status-item menu ("Probe variant ▸ A/B/C"),
in the installed signed app over the real SQLite history. Throwaway code on branch `history-probe`.

## Variants (structurally different: surface, primary affordance, where "Active" is shown)

**A — Menu.** The status-item menu itself lists the 15 most recent items (first line, truncated) above the
existing entries. The Active Item carries a ✓ and a header line "Active: <first line>". Click an item = select it.
Hold ⌥ and the items turn into "Delete <first line>" (alternate menu items). "Clear History…" at the bottom.
No panel, no keys beyond the menu's own; the menu never takes focus from the frontmost app.

**B — Panel list.** A menu item "Show History" opens a key-capable non-activating panel under the status item, the
same kind as the Candidate Chooser: a pinned "ACTIVE" block on top showing the Active Item's first three lines, then
the list (newest first). ↑/↓ move, Enter or click selects, ⌫ deletes the highlighted row, a "Clear all" button in
the footer, Esc/click-away closes. On close focus is handed back to the app that was frontmost when it opened
(`TargetAppFocusReturn`).

**C — Search-first + always-visible Active.** The Active Item's first line (≤ 24 chars) is shown **permanently next
to the status-item icon** in the menu bar. "Search History" opens a panel whose only initial content is a search
field (type to filter, substring, case-insensitive); results appear as you type (top 8, empty query = 8 newest).
↑/↓ + Enter selects, ⌘⌫ deletes the highlighted result, Esc closes; focus handed back as in B. Clear-all lives in
the status-item menu only.

Shared in all three (so only the surface differs): after every selection **and** every copy the indicator shows
"Active: <first line>" for 2.5 s; a selection makes the item Active through one probe-only Core call
`CopyCapture.select(_:)` (Active Item = that item; history order unchanged); a fresh ⌘C replaces it as today.

## Run script for Daniel (same for each variant)

Setup (I do it): three synthetic copies via `pbcopy`, oldest first: `JEVPASTE-HIST-ONE alpha.one@example.org`,
`JEVPASTE-HIST-TWO beta.two@example.net`, `JEVPASTE-HIST-THREE gamma.three@example.com`. THREE is now Active.
Target: Chrome `data:` page with an "Email address" textarea and a plain non-editable paragraph.

1. Switch to the variant (status item › Probe variant). *Why:* same starting point for every variant.
2. Without opening anything, say which item is Active. *Why:* is the Active Item visible at rest (a)?
3. Open the history surface and select **ONE**. Look at what changed. *Why:* is the selection feedback unmistakable?
4. Click into the textarea, ⌘⇧V. Expect `alpha.one@example.org` + "Pasted". *Why:* selected item is what pastes (item 2).
5. Switch to another app and back, ⌘⇧V again. Expect ONE's email again. *Why:* app switching leaves the selection alone.
6. Delete **TWO** in the surface; then look for clear-all (don't press it). *Why:* where delete/clear-all sit.
7. Tell me in your words: what did you like, what confused you, anything you want from another variant.

After Daniel picks a variant, on that variant only:
8. Select ONE, click the non-editable paragraph, ⌘⇧V → "No text field focused"; open the surface: ONE still Active?
   (item 3, refusal)
9. A failed attempt: I make Jev unreachable for one attempt (probe menu toggle "Probe: fail next Jev call" — the
   decision service reports unavailable) → "Jev unavailable"; ONE still Active? ⌘⇧V again → pastes. (item 3, failure;
   ⌘⇧V is the retry)
10. `pbcopy` a fresh `JEVPASTE-HIST-FOUR delta.four@example.com` (or Daniel ⌘C's it) → indicator "Active: …FOUR";
    ⌘⇧V pastes FOUR. (item 2, fresh copy replaces)
11. Focus: after selecting in B/C, type a letter without clicking — does it land in Chrome? (item 4)

## Findings template

1. Preferred variant (or mix) and why — Daniel's words: …
2. Lifecycle — select→⌘⇧V pastes selected: … / fresh ⌘C replaces: … / app switch keeps selection: …
3. Failure feedback — refusal seen+understood: … / failed attempt seen+understood: … / selection still Active after both: …
4. Focus return after choosing — keys/⌘⇧V land in target: …
5. Core seam — probe added `CopyCapture.select(_ item: ClipboardItem)` (sets Active Item, no history write); open
   points for production: …

## Staged commands (supervisor runs verbatim, from the worktree)
- `probe/setup-rows.sh` — copies ONE, TWO, THREE ~1 s apart (THREE Active). Run once after launch.
- `probe/open-target-page.sh` — opens `probe/target.html` in Chrome ("Email address" textarea + non-editable paragraph).
- `probe/fresh-copy-four.sh` — step 10's fresh copy.
Before each variant after the first: if ONE is still Active, `probe/setup-rows.sh` again (re-copy moves rows to the
top and makes THREE Active); if TWO was deleted, the script re-creates it.

## Instruction blocks for Daniel

### Variant A — Menu
1. Click the jevpaste clipboard icon in the menu bar › "Probe variant" › "A — Menu". *(Same start for each variant.)*
2. Click the icon again and just look: the bold top line says "Active: …", and one item has a ✓. Which item is
   Active? Close the menu (Esc). *(Can you tell what ⌘⇧V will use?)*
3. Open the menu, click the row "JEVPASTE-HIST-ONE alpha.one@example.org". Watch below the icon: a note
   "Active: JEVPASTE-HIST-ONE …" appears for ~2 s. Open the menu again: ✓ moved to ONE. *(Is the change obvious?)*
4. Click into the Chrome textarea, press ⌘⇧V. Expected: `alpha.one@example.org` and "Pasted".
   *(The selected item is what pastes.)*
5. ⌘Tab to another app and back to Chrome, click into the textarea, ⌘⇧V again. Expected: ONE's email again.
   *(Switching apps keeps the selection.)*
6. Open the menu, hold ⌥: every row turns into "Delete …". Click "Delete JEVPASTE-HIST-TWO …". Open again: TWO is
   gone. Find "Clear History" (a submenu — do **not** click "Delete all"; it deletes your real history).
   *(Where do delete and clear-all live?)*
7. Say in your words: what worked, what confused you, what you'd want from another variant.

### Variant B — Panel list
1. Icon › "Probe variant" › "B — Panel list".
2. Icon › "Show History…". A panel opens under the icon: the top block "ACTIVE — the next ⌘⇧V uses this" shows the
   Active Item; rows below, the Active one marked ●. Which is Active? Press Esc. *(Visible at rest? only here.)*
3. Icon › "Show History…", press ↓ until ONE is highlighted, Enter (or click the row). Panel closes; note
   "Active: JEVPASTE-HIST-ONE …" appears. *(Is the change obvious?)*
4. **Without clicking**, press ⌘⇧V — the textarea should still have the cursor. Expected: ONE's email + "Pasted".
   *(Does focus come back to Chrome by itself?)*
5. ⌘Tab away and back, ⌘⇧V. Expected: ONE's email again.
6. Icon › "Show History…", highlight TWO, press ⌫ (Delete): the row disappears. See "Clear all…" in the footer (don't
   click twice — it deletes your real history). Esc.
7. Your words: likes, confusions, bits you'd take.

### Variant C — Search-first
1. Icon › "Probe variant" › "C — Search-first". The Active Item's first words now sit **next to the icon in the
   menu bar**.
2. Look only at the menu bar: which item is Active? *(Always visible, without opening anything.)*
3. Icon › "Search History…". Type `one` — the list filters to ONE. Enter. The menu-bar text changes to
   "JEVPASTE-HIST-ONE…", and the note appears. *(Is the change obvious?)*
4. Without clicking, ⌘⇧V in the textarea. Expected: ONE's email + "Pasted". *(Focus returned?)*
5. ⌘Tab away and back, ⌘⇧V. Expected: ONE's email again.
6. Icon › "Search History…", type `two`, press ⌘⌫ (Command-Delete): TWO disappears. Esc. Clear-all is in the icon's
   menu ("Clear History" submenu — don't confirm).
7. Your words: likes, confusions, bits you'd take.

### Checks on the preferred variant (items 2–4)
8. Refusal: select ONE, click the **paragraph** (not the textarea), ⌘⇧V. Expected: "No text field focused". Then
   look: is ONE still Active?
9. Failure: icon › "Probe: fail next Jev call" (✓ appears). Click into the textarea, ⌘⇧V. Expected: "Jev
   unavailable", nothing inserted. Is ONE still Active? Press ⌘⇧V again (the retry): ONE's email + "Pasted".
10. Fresh copy: supervisor runs `probe/fresh-copy-four.sh` (or Daniel copies any JEVPASTE text). Expected: note
    "Active: JEVPASTE-HIST-FOUR …"; ⌘⇧V in the textarea pastes `delta.four@example.com`.
11. Focus (B/C only): select ONE in the panel, then just type `x` — it should land in the textarea.

What to report back per variant: Daniel's words verbatim; per step, what he saw (expected / not); anything odd.

## Findings (live run 2026-09-23, installed signed probe build, Variant A only)

Scope decided by the supervisor: only Variant A was run live; B, C and checks 8–11 were not run with Daniel
(Daniel too tired) — **not live-verified; covered by unit tests / deferred to the history UI's acceptance**.

1. **Variant preference.** Daniel delegates the design: "I'm too tired to feedback that. The UI is a bit human
   unfriendly, you guiding Opus can do the UI for me much better (+ make it look like something apple would be proud
   shipping)". Requirements taken from the run: the Active Item unambiguous at a glance, selection feedback obvious,
   delete and clear-all discoverable; quality bar Apple-shippable. On A he answered: Active at rest → "The one with
   HIST-THREE is active" (correct); selection feedback → "works, yes obvious"; ⌥-delete / Clear History submenu →
   "looks like it works fine, all obvious".
2. **Lifecycle.** Selecting ONE in the menu made it Active (log `selected from menu`, ✓ moved, note shown). Step 4
   (⌘⇧V in the textarea) ended **No suitable match**; step 5 (after ⌘Tab away and back, same Active Item — no
   Active Item change logged between the two attempts) **inserted** ONE's email. So app switching left the selection
   alone and the selected older item is what pastes. The step-4 miss is a fixture problem, not a history finding:
   `JEVPASTE-HIST-ONE alpha.one@example.org` is one line = one whole-line Candidate that is not a pure email, so Jev's
   gate is borderline (said no once, yes once) — evidence for
   [Extract typed tokens embedded in lines as Candidates](https://github.com/DanielMulec/jevpaste/issues/31). Fresh
   ⌘C replacing a selection: not live-run (setup copies showed each copy becoming Active, 3× `active item changed`).
3. **Failure feedback.** The step-4 "No suitable match" was visible and the selection stayed Active (step 5 pasted
   it without re-selecting). Refusal (non-editable) and a failed Jev call: not live-verified (deferred).
4. **Focus.** A's menu never takes focus, so ⌘⇧V landed in Chrome. Panel focus return (B/C): not live-verified.
5. **Core seam (probe-only, this branch):** `CopyCapture.select(_ item: ClipboardItem)` — sets the Active Item, no
   history write/reorder; plus `onActiveItemChange` so the shell can show the change. Production needs both (as a
   proper observation port), with tests: select → Active; later copy replaces; select during an in-flight attempt
   does not change the pinned item; selecting a concealed/deleted item.

Fixture lesson: synthetic rows must follow the payload rule — one pure value per line (e.g. `JEVPASTE-HIST-ONE` on
line 1, `alpha.one@example.org` on line 2), otherwise the paste outcome measures candidate extraction, not history.

## Recommendation for [Implement the history UI](https://github.com/DanielMulec/jevpaste/issues/27) (accepted at GATE C)
- Surface: Spotlight-style key non-activating panel under the status item (chooser parts), search field on top,
  8–10 rows; opened from the status-item menu and an optional hotkey; the status-item menu itself stays short.
- Selection: ↑/↓ + Enter or click → Active, panel closes, focus returned via `TargetAppFocusReturn`; Esc/click-away
  close without change.
- Active indication: pinned "Active" row at the top of the panel (symbol + 2–3 preview lines) + brief
  "Active: <first line>" note after a selection via `IndicatorNoticeSurface` (never masks ✓/reasons); no permanent
  menu-bar text.
- Delete: hover ✕ per row + ⌫/⌘⌫ on the highlighted row; clear-all: footer button with a confirmation alert.
- Core: promote `CopyCapture.select(_:)` + an Active-Item observation port, with tests.
