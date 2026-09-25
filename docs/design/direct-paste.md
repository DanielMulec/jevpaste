# Direct Paste — design

Slice: [Implement Direct Paste for single-line items](https://github.com/DanielMulec/jevpaste/issues/34). Decision: Rule 1 of
[Skip Jev for a single line, and skip Jev when there is nothing to reason about](https://github.com/DanielMulec/jevpaste/issues/32)
(Rule 2 deferred, not built). Glossary: **Direct Paste**, **Smart Paste** in `CONTEXT.md`.

**Doorways** (`CONTEXT.md`): (1) a single-line Active Item — this document; (2) a **Free-text Target** — Jev's
third question answers ≥ 0.8, the whole Active Item is delivered with the same outer-line-break stripping
(`DirectPasteRule.withoutOuterLineBreaks(_:)`), see [free-text-target.md](free-text-target.md); (3) Enter after No
Suitable Match — [Enter pastes everything after No Suitable Match](https://github.com/DanielMulec/jevpaste/issues/42).

## Rule and text (`DirectPasteRule`, Core, pure)
`DirectPasteRule.text(for: ClipboardItem) -> String?` — `nil` means "not a Direct Paste, ask Jev".
- **Single line**: between the first and the last non-whitespace scalar there is no `\n` or `\r` (so `\r\n`, lone
  `\r`, trailing blank lines and leading blank lines are all covered). `"  x@y.org\n"` → yes; `"a\n\nb"` → no.
- **Whitespace-only / empty**: `nil` → existing path: empty Candidates → No Suitable Match, no Jev call. (No
  Pre-check refuses whitespace-only items today.)
- **Text**: outer line breaks stripped, nothing else (GATE A; the decision said *trailing* only — leading breaks are
  the same hazard at a prompt). Cut after the last break of the leading whitespace run and at the first break of
  the trailing one: `"\r\n  \r\n\tx \r\n\n"` → `"\tx "`. Spaces and tabs on the line stay byte for byte.

## Where the branch sits (`hotkeyPressed`)
```
… PreCheck.refusal → refuse                         (unchanged, stays in front)
DirectPasteRule.text(for: item) != nil → deliver it  (no Jev, no Candidates, no chooser, no indicator, no 5 s clock)
otherwise → Candidates → Jev … (unchanged)
```
Delivery is the existing step (Bound Target re-verified, own write, ⌘V, 120 ms Restore Window). `deliver(_ text:)`
replaces `deliver(_: Candidate)`. `RunningAttempt` keeps Jev-only data (screened context, Candidates, deadline) in
an optional `JevConsultation`; `nil` = Direct Paste, which carries no note.

## Outcome and log (item 4)
The path rides on the **presenter call only**, not on `PasteAttemptOutcome`: new Core enum
`SmartPastePath { jev, directPaste }`; `showOutcome(_:note:path:)` with `path: nil` for refusals ended before a
path was taken. `OutcomeMessage` untouched; the visible ✓ is identical. `IndicatorPresenter` logs
`outcome inserted via=directPaste` / `outcome noSuitableMatch via=jev note=…` (enums only, no payload).

## Tests (Swift Testing)
- `DirectPasteRuleTests` (parameterised): single line, outer whitespace, CRLF, lone CR, trailing blank lines,
  leading blank lines, `a\n\nb`, whitespace-only/empty → `nil`; byte-exact slice, spaces/tabs kept.
- `PasteAttemptDirectPasteTests`: no Jev request; pasted text = Direct Paste text; restore / foreign copy /
  target changed as usual; no indicator at 150 ms, no timeout at 5 s; a phone number still pastes into an Email
  field; Pre-check refusal wins (order); whitespace-only → No Suitable Match, no Jev; multi-line asks Jev
  (regression); older single-line Active Item ≠ clipboard Direct Pastes (Rejev stand-in until
  `CopyCapture.select` lands with the history UI); presenter gets `path`. `IndicatorPresenterTests`: `via=`.

## Live run (Daniel, after install)
1. `printf 'JEVPASTE-DP-ONE@example.org' | pbcopy`, click into a Chrome *Email address* field, ⌘⇧V.
   Look: ✓, text in the field. Why: no type check, no Jev call (log `via=directPaste`, no `JevGateway` line).
2. Same item at a Herdr shell prompt, ⌘⇧V. Look: text at the prompt, **nothing runs**. Then Ctrl-C. Why: insert
   only. Repeat 1–2 with `printf 'JEVPASTE-DP-TWO@example.org\n' | pbcopy` — proves the trailing newline is gone.
3. ChatGPT app composer, ⌘⇧V (a cold start may say "Waking ChatGPT…"; press again). Look: text in the
   composer, **not** sent. Why: the composer proof deferred from the ChatGPT resolver ticket.
4. Copy a two-line item, ⌘⇧V in the Chrome field. Look: "Jev is choosing…" then the usual outcome. Why: multi-line
   items still go through Jev.
