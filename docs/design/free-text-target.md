# Free-text Target — design

Slice: [Implement Free-text Target via Jev's third question](https://github.com/DanielMulec/jevpaste/issues/41).
Decision: [Skip Jev when the target gives it nothing to reason about](https://github.com/DanielMulec/jevpaste/issues/35#issuecomment-5821465655);
wording and numbers: [Spike: does Jev reliably tell free-text places from value fields?](https://github.com/DanielMulec/jevpaste/issues/40#issuecomment-5821700475).

## The third question (same call, id `free_text`, spike wording verbatim)
```
type: boolean
instructions: "Judge only the place described by `target_context`, not `source_document`. Is `target_context` a free-text place — a chat or message composer, a document or text editor, a code editor, a terminal — where the user would paste whatever they copied, as it is? Or is it a field that expects one specific value, such as a name, an email address, a phone number, an address line or a single short entry?"
criteria.true:  "A free-text place: the user would paste whatever they copied, whole."
criteria.false: "A field for one specific value."
```
Parsed like `contains_value` (missing or outside 0…1 → `.failed`); `Decision` gains `freeTextProbability`
(init default `0`, existing call sites unchanged). Cost (spike): +~135 input tokens, median 436 vs 360 ms.

## Request body — two new `target_context` keys, absent/empty omitted
`app_name` (localized name of the focused element's process, `NSRunningApplication(processIdentifier:)`) and
`window_title` (`AXTitle` of the focused element's `AXWindow`). `TargetContext` gains `appName: String?`,
`windowTitle: String?`. Both are single AX/AppKit reads, bounded by the messaging timeout like the label reads.
The bundle id is never sent. Secure field → empty `TargetContext()` as today (no app name, no title).

## Core rule (`PasteAttemptCoordinator+Decision.swift`)
`static let freeTextThreshold = 0.8` beside `containsValueThreshold`. First statement of `decided(_:)`:
`guard decision.freeTextProbability < freeTextThreshold else { return pasteWholeItem(...) }` → the whole pinned
Active Item through `DirectPasteRule`'s outer-line-break stripping (refactored into a shared
`DirectPasteRule.withoutOuterLineBreaks(_:)`; the single-line test stays on top of it) → `deliver(_:)`. Wins over
any choice, `none_of_these` and the gate. Below → unchanged. Pre-checks already ran at ⌘⇧V.

## Proposals for GATE A
1. **Path reporting.** `SmartPastePath` gains payloads: `.jev(freeTextProbability: Double?)` (nil = no decision
   arrived: timeout, failure, cancel), `.freeTextTarget(probability: Double)`, `.directPaste` unchanged.
   `RunningAttempt.path` turns from computed into a stored `var` (set to `.directPaste` / `.jev(nil)` at start;
   `decided(_:)` sets the probability or `.freeTextTarget`). No port signature change; the log formats the
   payload in `outcomeLogLine`. Cost: `.jev` → `.jev(freeTextProbability: …)` in 2 existing test files.
2. **Note shape.** `PasteAttemptNote` stays the one enum: `.surroundingTextWithheld`, `.windowTitleWithheld`,
   `.surroundingTextAndWindowTitleWithheld` (log `note=<case>`). The title is scanned with the same
   `SuspectedSecretRules`; a hit sends the context without `window_title`. App name is not scanned (like labels).
   Needs two lines in `OutcomeMessage.text(for:)` (owned by #42): "window title withheld (suspected secret)",
   "nearby text and window title withheld (suspected secret)" — ask to touch only that switch.
3. **Validation.** The whole-item text is not passed through `RunningAttempt.accepts`: it is derived locally from
   the pinned item (Jev supplied a probability, not text) — the same trust as a single-line Direct Paste. A test
   proves the delivered bytes are the pinned item minus outer line breaks, never a Candidate.

## Log (`IndicatorPresenter.outcomeLogLine` only)
`via=freeTextTarget p=0.93` / `via=jev p=0.12` / `via=jev` (no decision) / `via=directPaste`; `p` = `%.2f`.

## Tests (Swift Testing, new files)
- `JevGatewayTests/FreeTextTargetRequestTests`: third question wording/criteria verbatim; `app_name`/`window_title`
  sent, omitted when nil/empty; probability parsed; missing/out-of-range → `.failed`; two questions unchanged.
- `SmartPasteCoreTests/FreeTextTargetScreeningTests` (`LocalPreChecks`): title with secret withheld + note; both
  withheld → combined note; clean title sent; app name never withheld.
- `SmartPasteCoreTests/FreeTextTargetTests` (coordinator): p=0.8 → whole multi-line item (outer breaks stripped),
  no chooser even with a same-type group, not a Candidate; p=0.79 → old flow; free-text wins over `none_of_these`
  and a low gate; labelled Email field p=0.05 → excerpt only; Pre-check refusal first; single-line item never
  asks Jev; paths `.freeTextTarget(0.8)` / `.jev(0.79)` / `.jev(nil)` on timeout.
- `MacInteropTests/FreeTextTargetContextTests`: title via `AXWindow`, no window → nil; app name. Existing
  `DirectPasteRuleTests` keep the shared stripping byte-exact. `JevPasteAppTests/FreeTextTargetLogLineTests`: log.

## Live run (after `make install`, gated)
Payload (3 lines): `JEVPASTE-FT-NAME Marlene Example` / `ft41@example.org` / `+41 79 555 01 23`. Evidence per
step: the `outcome … via=… p=…` log line (`log show --info`, no payloads) and what landed (DOM / pane read).
- (a) Chrome `data:` page with a bare `<textarea>` → whole item lands, `via=freeTextTarget`. Why: an unlabelled
  web composer is the case that used to end in No Suitable Match.
- (b) Chrome `data:` page with a labelled *Email address* input → only `ft41@example.org`, `via=jev`, low `p`.
  Why: the third question must not turn value fields into whole pastes.
- (c) Herdr shell prompt → whole item at the prompt, nothing runs; then `C-c`. Why: terminal = free text, and
  outer line breaks never execute.
- (d, Daniel) ChatGPT composer → whole item, not sent ("Waking ChatGPT…" → press again). Why: the original
  failure. (e, Daniel) WhatsApp composer → whole item, not sent. Why: lowest spike margin (0.83).
