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

**Target**:
The focused editable destination into which a Paste Result is intended to be inserted.

**Target Context**:
Information about the Target and its surroundings that helps establish what text belongs there.

**Smart Paste**:
An explicitly requested selection of the excerpt of the Active Item that belongs in the Target, followed by insertion. Insert only; never sends or executes.
_Avoid_: Ordinary paste (which inserts clipboard contents without this transformation)

**Paste Result**:
One exact, contiguous, verbatim excerpt of the Active Item chosen for the Target. Never rewritten, reformatted, combined, or generated.
_Avoid_: Transformation, rewrite, generated text

**Candidate**:
An exact contiguous substring of the Active Item, derived locally, that Jev may choose as the Paste Result.

**No Suitable Match**:
The visible outcome when no Candidate belongs in the Target; nothing is inserted.

**Candidate Chooser**:
The small in-app prompt shown when several excerpts are plausible for the Target; the app never guesses silently.

**Rejev-paste**:
A Smart Paste using an older Clipboard Item selected from Clipboard History, interpreted afresh for its Target.
