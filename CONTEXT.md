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
An explicitly requested insertion of the Active Item into the Target: either the excerpt that belongs there, chosen by Jev, or a Direct Paste. Insert only; never sends or executes.
_Avoid_: Ordinary paste (which inserts clipboard contents without this safety envelope)

**Direct Paste**:
The Active Item inserted whole, without Candidates or the Candidate Chooser — verbatim as copied, leading and trailing line breaks stripped so nothing is sent or executed. Three doorways: the Active Item is a single line (no line break inside, ignoring outer whitespace; Jev is not consulted); the Target is a Free-text Target; or the user presses Enter after No Suitable Match. Pre-checks still apply.
_Avoid_: Plain paste, whole paste, skip-Jev paste

**Free-text Target**:
A Target that Jev judges to accept any text — a chat or message composer, an editor, a document, a terminal — rather than one specific value. Judged per Paste Attempt from the Target Context, never by a local rule; a Free-text Target receives the whole Active Item as a Direct Paste.
_Avoid_: Unlabelled target (labels may exist but be unreadable), chat mode

**Paste Result**:
One exact, contiguous, verbatim excerpt of the Active Item chosen for the Target. Never rewritten, reformatted, combined, or generated.
_Avoid_: Transformation, rewrite, generated text

**Candidate**:
An exact contiguous substring of the Active Item, derived locally, that Jev may choose as the Paste Result.

**No Suitable Match**:
The visible outcome when no Candidate belongs in the Target; nothing is inserted unless the user then presses Enter to paste the whole Active Item as a Direct Paste.

**Candidate Chooser**:
The small in-app prompt shown when several excerpts are plausible for the Target; the app never guesses silently.

**Rejev-paste**:
A Smart Paste using an older Clipboard Item selected from Clipboard History, interpreted afresh for its Target.

**Paste Attempt**:
One Smart Paste from ⌘⇧V to its visible outcome (inserted, no suitable match, refused, cancelled, or failed). Only one exists at a time; a repeated ⌘⇧V during an attempt is ignored. The Active Item and Bound Target are pinned when it starts.

**Bound Target**:
The Target pinned at the start of a Paste Attempt and re-verified immediately before insertion. If it no longer matches, nothing is inserted.

**Wake Wait**:
The interval at the start of a Paste Attempt during which the focused element cannot be read — the Target app's accessibility tree is asleep or not yet populated — and the attempt waits for it, re-reading until it resolves or a fixed limit (3 s) passes. One press, no second ⌘⇧V; the indicator says which app is waking after 150 ms; Esc or a click cancels. Precedes the Bound Target, the Pre-checks and the 5 s Jev clock, on every Smart Paste path. Only after the limit is the refusal "<App> isn't ready — press ⌘⇧V again"; "No text field focused" is reserved for a readable focus with nothing editable.
_Avoid_: Wake retry, warm-up, "press again"

**Pre-check**:
A local refusal evaluated before any Paste Attempt leaves the machine: no editable Target, secure field, or a concealed or suspected-secret Active Item. Refusals are visible and never contact Jev. A suspected secret in the Target Context's surrounding text is not a refusal: that text is withheld from Jev and the outcome shows a note.

**Restore Window**:
The brief interval after insertion during which the clipboard temporarily holds the Paste Result before the original contents are restored. A copy made by the user in this window is kept in preference to restoring.

**Signing Identity**:
The self-signed code-signing certificate `jevpaste-dev` (dedicated keychain) that every installed build is signed with. macOS Accessibility trust keys on it, not on the build's hash, so rebuilds keep the grant; ad-hoc builds are never installed and changing the identity is a migration event.
