# Nearby text around the text cursor — design

Slice: [Read nearby text around the text cursor, without an app list](https://github.com/DanielMulec/jevpaste/issues/51).
Decision: [Decide the extraction engine for any-field Smart Paste](https://github.com/DanielMulec/jevpaste/issues/47#issuecomment-5845599979)
("No app names in behaviour"; reading bounds of inventory item 9 kept). Gate A evidence:
`docs/acceptance/run-2026-09-26-cursor-context-gate-a.log` (probe branch `cursor-context-probe`, never merged).

## Gate A — what the focused element reports (`AXSelectedTextRange`, one call, 32–139 µs)
| Target | role | own text (chars) | cursor | reading |
|---|---|---|---|---|
| Ghostty (Herdr) | `AXTextArea` | 13 266: the visible window, every Herdr pane; Herdr's scrollback is not in it | `(0,0)` always — the top of the text, not the prompt (NEAR at +12 749) | no usable cursor |
| Terminal.app | `AXTextArea` | 20 138: the whole scrollback | `(20137,0)` = the prompt (NEAR −17, OLD −19 903) | real |
| TextEdit | `AXTextArea` | 7 218 | `(0,0)` as opened; `(3609,0)` after an AX set (BEFORE −18, AFTER +3) | real |
| Chrome `<textarea>` | — | — | unmeasured: a modal consent sheet was open (`AXSheet`), not an AX limit | step-5 live proof |
| ChatGPT composer | `AXGroup` | 0 | `(0,0)` (after the Wake Wait) | short: page walk |

Units: `location`/`length` are UTF-16 offsets into the element's `AXValue` (NSString), per the AX API.

## The rule (every app, no app identity anywhere)
`SurroundingTextCollector.surroundingText(of:until:)`:
1. Read the focused element's own `AXValue` (not for a secure field: those get no context at all, unchanged).
2. **Own text ≤ 2 000 characters** → the page walk, exactly as today (≤ 600 elements, first 2 000 characters).
3. **Own text > 2 000 characters** → one `AXSelectedTextRange` read (skipped once the 250 ms budget is spent), then a
   2 000-character window of the own text:
   - **usable cursor** → the window around it, **1 500 characters before, 500 after**; a side with less text gives its
     unused share to the other, so the window always holds 2 000 characters.
   - **no usable cursor** → the **last** 2 000 characters.

A cursor is usable when the element reports a range with `location ≥ 0`, `length ≥ 0`, `location + length ≤` the own
text's UTF-16 length, **and it is not the empty range at the very start `(0,0)`**. The anchor is `location` (a
selection's start: the pasted text replaces the selection, whose text then counts as "after"). The UTF-16 anchor is
converted once and rounded down to a Character boundary; the 2 000 are counted in Swift Characters from there, so
no edge of the window splits a grapheme cluster or a surrogate pair.

### Why 1 500 before / 500 after
What precedes the caret is what the user has been reading or writing into: the command output above a prompt, the
conversation above a reply, the question or label above an answer line. What follows is the rest of the document —
still useful (a template's next labels), so it keeps a quarter rather than nothing. At the end of a text (terminal
prompt, Terminal.app's `(20137,0)`) the rule yields the same 2 000 characters as today's terminal tail.

### Why `(0,0)` counts as no cursor
Ghostty reports `(0,0)` whatever its cursor; taken at face value the window would be the **top** of its window, the
opposite of the prompt (today's terminal list reads the tail). An app gives no other signal to tell a real caret at 0
from this (`AXInsertionPointLineNumber` is unsupported in Ghostty, and a second read would break "one call"). The cost
of the rule: a real caret at the very start of a text longer than 2 000 characters (TextEdit right after opening a
long file) gets the text's end instead of its start — rare, and still text of the same field.

Options weighed for a reported cursor that cannot be trusted (app-neutral; per measured row):
| option | Ghostty/Herdr `(0,0)` | Terminal `(20137,0)` | TextEdit opened `(0,0)` | TextEdit `(3609,0)` | ChatGPT (0 chars) |
|---|---|---|---|---|---|
| **1 `(0,0)` = no cursor → last 2 000** (chosen) | tail: NEAR in | 2 000 before the prompt | end of the file (FAREND in, FARSTART out) | around the caret | page walk |
| 2 `(0,0)` → 1 000 from the start + 1 000 from the end | two joined pieces; half the budget on the window's top rows | same as 1 | start and end | same as 1 | page walk |
| 3 another attribute tells real from fake | `AXVisibleCharacterRange` = `0+13266` and `AXNumberOfCharacters` = length in Ghostty *and* TextEdit: no signal. Only `AXInsertionPointLineNumber` differs (Ghostty unsupported, TextEdit 0), but ChatGPT reports garbage there, Chrome is unmeasured, and it is a second call | | | | |

Option 2 halves the useful text in the one measured target that needs the rule and sends a seam between unrelated
text; option 3 has no measured single-call signal. Ghostty with option 1: the last 2 000 characters **contain NEAR
(518 UTF-16 units before the end) = true**; **OLD = excluded (true)** — trivially: Herdr's scrollback never reaches
Ghostty's AX text. Ghostty's text is the whole window across every Herdr pane, so the bottom rows of other panes
reach Jev as well (as with today's suffix branch); Core's secret screening of surrounding text still applies.

## Seam change
- `AccessibilityNode` gains `var selectedTextRange: SelectedTextRange? { get }` — the reported range as is (UTF-16
  `location`, `length`), `nil` when the element offers none. Judging it (bounds, `(0,0)`) is the collector's rule, not the node's.
- `AXElementNode`: one `AXUIElementCopyAttributeValue(kAXSelectedTextRangeAttribute)`, decoded only when it is an
  `AXValue` of type `.cfRange`.
- `FakeNode` stores whatever range a test sets, unvalidated (missing, out of range, `(0,0)`, mid-surrogate), like an app.
- `FocusedElement.bundleIdentifier` goes (its only reader was the terminal list); `AXFocusSource` keeps logging the
  bundle id of an unreadable app on its own. `PasteboardMarkers` stays (out of scope).
- New pure value type `CursorTextWindow` (own text + cursor → the window), unit-tested without AX.

## Bounds and budget (unchanged)
2 000 characters, 600 elements, 10 sibling labels, 250 ms shared deadline. The new read is one synchronous call,
checked against the deadline before it is made (like every walk step); an expired budget means "no usable cursor".

## Probe left in `main`
Nothing: the Gate A probe lives only on `cursor-context-probe` (pushed as a primary source, never merged).
