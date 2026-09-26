# Smart Paste

Smart paste adapts copied text to its intended destination. Clipboard history lets Daniel reuse earlier source material.

## Language

**Clipboard Item**:
A captured piece of copied text that can serve as the source of a smart paste.

**Clipboard History**:
The collection of retained Clipboard Items available for later selection and reuse.

**Active Item**:
The Clipboard Item selected as the source for the next smart paste. A new copy or an explicit history selection replaces the active item.
_Avoid_: Latest item (an older item may be active)

**Launch Adoption**:
At launch, the text already on the clipboard is adopted exactly like a live copy: it becomes the Active Item and is recorded in Clipboard History unless concealed. No text → no Active Item.
_Avoid_: Seeding (ambiguous with test fixtures), prefill

**Target**:
The focused editable destination into which a Paste Result is intended to be inserted.

**Target Context**:
Information about the Target and its surroundings that helps establish what text belongs there.

**Smart Paste**:
An explicitly requested insertion of the Active Item into the Target: either the excerpt that belongs there, found by Jev through Narrowing, or a Direct Paste. Insert only; never sends or executes.
_Avoid_: Ordinary paste (which inserts clipboard contents without this safety envelope)

**Direct Paste**:
The whole Active Item inserted because the user pressed Enter after No Suitable Match — the only doorway; never automatic, never a local rule. Verbatim as copied, leading and trailing line breaks stripped so nothing is sent or executed. Pre-checks still apply. When Jev itself keeps the whole Active Item during Narrowing (a chat box or terminal takes everything), that is a Paste Result, not a Direct Paste.
_Avoid_: Plain paste, whole paste, skip-Jev paste, Free-text Target (retired: Jev no longer judges the place separately; it chooses the whole item like any other piece)

**Paste Result**:
One exact, contiguous, verbatim excerpt of the Active Item chosen for the Target. Never rewritten, reformatted, combined, or generated.
_Avoid_: Transformation, rewrite, generated text

**Candidate**:
An exact contiguous substring of the Active Item, cut locally at cut points without judging meaning, that Jev may choose during Narrowing. No Candidate is ever dropped for lack of room; more choices are asked instead.

**Narrowing**:
How Jev finds the Paste Result: starting from the whole Active Item, Jev repeatedly chooses among the current piece unchanged and the Candidates cut from it. It ends when Jev keeps a piece unchanged (that piece is the Paste Result), chooses "nothing fits" (No Suitable Match), or asks the user (Candidate Chooser). Every step is a choice; no yes/no question and no local rule decides what the piece means.
_Avoid_: Stage, drill-down, refinement, gate

**Embedded Value**:
A piece of a line of the Active Item — an email, a phone number, a city, a postal code, a date, a street — that belongs in a field on its own, offered as its own Candidate rather than only inside the line that holds it.
_Avoid_: Token (reads as an LLM token), entity, fragment

**No Suitable Match**:
The visible outcome when no Candidate belongs in the Target; nothing is inserted unless the user then presses Enter to paste the whole Active Item as a Direct Paste.

**Candidate Chooser**:
The small in-app prompt shown when Jev answers during Narrowing that more than one excerpt could be meant; the app never guesses silently. Opened by Jev's choice, never by a local type rule.

**Rejev-paste**:
A Smart Paste using an older Clipboard Item selected from Clipboard History, interpreted afresh for its Target.

**Paste Attempt**:
One Smart Paste from ⌘⇧V to its visible outcome (inserted, no suitable match, refused, cancelled, or failed). Only one exists at a time; a repeated ⌘⇧V during an attempt is ignored. The Active Item is pinned when it starts; the Bound Target once the focus is readable (at ⌘⇧V, or after a Wake Wait).

**Bound Target**:
The Target pinned once the focus is readable — at ⌘⇧V, or after a Wake Wait if needed — and re-verified immediately before insertion. If it no longer matches, nothing is inserted.

**Wake Wait**:
The interval at the start of a Paste Attempt during which the focused element cannot be read — the Target app's accessibility tree is asleep or not yet populated — and the attempt waits for it, re-reading until it resolves or a fixed limit (3 s) passes. One press, no second ⌘⇧V; the indicator says which app is waking after 150 ms; a click on the indicator cancels (as on the processing indicator; Esc does not reach a non-key indicator). Precedes the Bound Target, the Pre-checks and the 5 s Jev clock, on every Smart Paste path. Only after the limit is the refusal "<App> isn't ready — press ⌘⇧V again"; "No text field focused" is reserved for a readable focus with nothing editable.
_Avoid_: Wake retry, warm-up, "press again"

**Pre-check**:
A local refusal evaluated before any Paste Attempt leaves the machine: no editable Target, secure field, or a concealed or suspected-secret Active Item. Refusals are visible and never contact Jev. A suspected secret in the Target Context's surrounding text is not a refusal: that text is withheld from Jev and the outcome shows a note.

**Restore Window**:
The brief interval after insertion during which the clipboard temporarily holds the Paste Result before the original contents are restored. A copy made by the user in this window is kept in preference to restoring.

**Signing Identity**:
The self-signed code-signing certificate `jevpaste-dev` (dedicated keychain) that every installed build is signed with. macOS Accessibility trust keys on it, not on the build's hash, so rebuilds keep the grant; ad-hoc builds are never installed and changing the identity is a migration event.
