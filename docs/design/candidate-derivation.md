# Candidate derivation — rules and tests

Slice: [Implement Candidate derivation](https://github.com/DanielMulec/jevpaste/issues/19). Spec:
[Choose Jev context and excerpt-selection semantics](https://github.com/DanielMulec/jevpaste/issues/7) and the
granularity spike findings (`spikes/granularity/FINDINGS.md` on `spike/jev-contract`). Port:
`CandidateExtraction` (unchanged). Adapter: `LineAndLabelCandidateExtraction` in `Sources/SmartPasteCore/Candidates/`.

## Derivation rules (`candidates(in:)`) — pure, deterministic
1. **Lines.** Split the item's text at line breaks: `\n`, `\r\n`, `\r` (Swift `Character.isNewline`, so also
   U+0085, U+2028, U+2029). A `\r\n` pair is one break, never part of a line.
2. **Trimming.** Each line is trimmed of leading and trailing whitespace (space, tab, other Unicode
   `isWhitespace`). Nothing inside the line changes. Empty and whitespace-only lines yield nothing.
3. **Label: value.** A trimmed line is a labelled line when it contains a colon followed by at least one space or
   tab, and the text before that first `": "`/`":\t"` (the label) is 1–40 characters, contains no colon and is
   not only whitespace. The value is the rest, trimmed; it must be non-empty. The value may contain colons
   (`Website: https://a.example:8443/x` → value `https://a.example:8443/x`; `Time: 10:30` → `10:30`). A colon not
   followed by whitespace never splits (`https://x.com` is a plain line).
4. **Both.** A labelled line yields the whole trimmed line, then its value. Other lines yield the trimmed line.
5. **Order and dedup.** Document order. A Candidate whose UTF-8 bytes equal an earlier one is dropped (first
   occurrence wins). Canonically equivalent but differently encoded texts are both kept.
6. **Substrings.** Every Candidate is a slice of the original `String` by index range, so it is a byte-exact
   contiguous substring; nothing is normalised, joined or generated.
7. **Cap 254** (Jev allows 255 options; 256 → HTTP 400; the JevGateway adapter adds `none_of_these` as one
   option). When more than 254 remain, drop first the whole lines of
   labelled lines, last in document order first (their value stays, and the spike shows the value is what a field
   wants); if still more than 254, drop the remaining Candidates from the end of the document. The result is
   always in document order.

## Same-type detection (`sameTypeAlternatives(to:among:)`)
A Candidate's type is detected on its **whole** text (so `Email: a@b.example` has no type; its value does):

| type | regex (whole match, case-insensitive) |
|---|---|
| email | `[A-Z0-9._%+\-]+@[A-Z0-9\-]+(\.[A-Z0-9\-]+)*\.[A-Z]{2,}` |
| URL | `(https?://\|www\.)\S+` (pipe escaped for the table) |
| handle | `@[A-Z0-9_]{1,30}` (and not an email) |
| phone | digit groups (optionally in parentheses) joined by at most one of ` ./-`, optional leading `+`; 7–15 digits; without `+` also ≥ 3 groups or ≥ 10 digits (so `2021-2024` is not a phone) |

Checked in the order above; the first match wins, so a Candidate has at most one type. Result: every Candidate in
`candidates` (in their order) with the same type as `chosen`. If `chosen` has no type, or is not among
`candidates` (UTF-8 byte for byte), the result is `[chosen]`, which never opens the chooser.

## Tests (Swift Testing, `Tests/SmartPasteCoreTests/Candidate*Tests.swift`)
Derivation:
- `eachNonBlankLineIsACandidateInDocumentOrder`
- `leadingAndTrailingSpacesAndTabsAreTrimmedInnerWhitespaceKept`
- `emptyAndWhitespaceOnlyLinesYieldNothing`; `emptySourceYieldsNoCandidates`
- `crlfAndLoneCarriageReturnSplitLinesWithoutLeavingCarriageReturns`
- `labelledLineYieldsTheWholeLineAndTheValue`
- `valueContainingAURLKeepsAllItsColons`; `urlLineWithoutLabelIsNotSplit`
- `colonWithoutFollowingSpaceDoesNotSplit`; `labelLongerThanFortyCharactersDoesNotSplit`;
  `labelWithEmptyValueYieldsOnlyTheLine`; `labelContainingAColonDoesNotSplitAtALaterSeparator`
- `identicalTextIsOfferedOnce`; `differentlyEncodedEqualTextIsKeptAsTwoCandidates`
- `unicodeAndEmojiLinesAreKeptByteForByte`
- `thousandLineSourceIsCappedAt254KeepingTheFirstLinesInDocumentOrder`
- `exactly254CandidatesAreAllKeptAnd255LoseTheLast`; `overCapDropsWholeLabelledLinesBeforeValuesAndPlainLines`;
  `whenValuesAndPlainLinesAloneExceedTheCapTheDocumentEndIsDropped`
- `everyCandidateOfAMixedSourceIsAcceptedByPasteResultValidation` — each Candidate goes through a Paste Attempt
  (`PasteAttemptHarness`, fake Jev choosing it) and ends `.inserted`, i.e. passes Core's verbatim check; plus a
  UTF-8 `firstRange` check for all 254 Candidates of the 1 000-line source.
- `derivationIsDeterministic` (same input twice → identical output).

Same type:
- `emailsShareATypeAndIncludeTheChosenOne`; `urlsShareAType`; `phonesShareAType`; `handlesShareAType`
- `emailAndHandleAreDifferentTypes`; `wholeLabelledLineHasNoType`; `shortNumbersTimesAndYearsAreNotPhones`
- `untypedChosenReturnsOnlyItself`; `chosenNotAmongCandidatesReturnsOnlyItself`;
  `chosenInADifferentEncodingThanItsCandidateReturnsOnlyItself`
- `singleEmailAmongOtherTypesReturnsOnlyItself`

## Open questions
1. Issue text says "with source ranges"; the port's `Candidate` carries text only. Ranges are not exposed; Core's
   validation re-finds the text. No Core change proposed.
2. No per-Candidate length cap: lines over 255 characters are offered whole (Jev's option-description limit is
   the JevGateway adapter's concern).
3. The whole multi-line item is not a Candidate (not in the spec); a multi-line Paste Result is therefore
   impossible for now.
