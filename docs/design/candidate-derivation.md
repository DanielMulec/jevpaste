# Candidate derivation — rules and tests

> **Superseded — historical record only.** Since [narrowing.md](narrowing.md) (#50) nothing on this page describes the app: no Candidate derivation, no type rules, no 254 cap, no `CandidateExtraction` port. Narrowing cuts pieces by character classes only.

Slices: [Implement Candidate derivation](https://github.com/DanielMulec/jevpaste/issues/19) and
[Add multi-line Candidate kinds](https://github.com/DanielMulec/jevpaste/issues/30). Spec:
[Choose Jev context and excerpt-selection semantics](https://github.com/DanielMulec/jevpaste/issues/7) (resolution
plus the 2026-09-22 amendment) and the granularity spike findings (`spikes/granularity/FINDINGS.md` on
`spike/jev-contract`). Port: `CandidateExtraction` (unchanged). Adapter in `Sources/SmartPasteCore/Candidates/`.

## Derivation rules (`candidates(in:)`) — pure, deterministic
1. **Lines.** Split the item's text at line breaks: `\n`, `\r\n`, `\r` (Swift `Character.isNewline`, so also
   U+0085, U+2028, U+2029). A `\r\n` pair is one break, never part of a line. A line is **blank** when it is
   empty or only whitespace. A line's **indentation** is the number of leading whitespace `Character`s (tab = 1).
2. **Trimming.** Every excerpt starts at the first non-whitespace character of its first line and ends after the
   last non-whitespace character of its last line. Nothing inside changes (inner line breaks, CRLF, tabs and
   indentation of later lines stay byte for byte). Blank lines yield nothing.
3. **Label: value.** A trimmed line is a labelled line when it contains a colon followed by at least one space or
   tab, and the text before that first `": "`/`":\t"` (the label) is 1–40 characters and contains no colon. The
   value is the rest, trimmed; it must be non-empty. The value may contain colons
   (`Website: https://a.example:8443/x` → value `https://a.example:8443/x`; `Time: 10:30` → `10:30`). A colon not
   followed by whitespace never splits (`https://x.com` is a plain line).
4. **Single-line kinds.** A labelled line yields the whole line and its value; any other line yields the line.
5. **Multi-line kinds** — each only when it spans two or more non-blank lines, so it never equals a single-line
   Candidate (it contains a line break):
   - **Paragraph:** a maximal run of consecutive non-blank lines.
   - **Section:** a heading-like line plus its body. The body starts with the next line, which must be non-blank
     (else no section), and always includes it (so `EXPERIENCE` / `CEO` works although `CEO` is heading-like);
     it ends before the first later line that is blank, heading-like, or indented less than the first body line.
   - **Whole item:** from the first to the last non-blank line, blank lines inside included.
6. **Heading-like line** (trimmed text `t`, not labelled), any of: (a) `t` starts with 1–6 `#` and a space
   (Markdown); (b) `t` ends with `:` and has at most 60 characters; (c) `t` has at least two letters, no
   lowercase letter and at most 60 characters (`EXPERIENCE`, `CONTACT DETAILS`); (d) the next line exists, is not
   blank, and is indented deeper than this line; (e) `t` is short — at most 4 words and 60 characters, not ending
   in `.`, `,` or `;` — is the first line or follows a blank line, and the next line exists and is not blank
   (résumé headings such as `Experience`, `Work History`).
7. **Order.** Document order by start; at the same start the longer excerpt first (container before contents);
   at the same start and end the kind that is dropped last first (paragraph, section, whole item).
8. **Dedup.** An excerpt whose UTF-8 bytes equal an earlier one's is dropped; the first in the order above wins.
   Canonically equivalent but differently encoded texts are both kept.
9. **Substrings.** Every Candidate is a slice of the original `String` by index range, so it is a byte-exact
   contiguous substring; nothing is normalised, joined or generated.
10. **Cap 254** (Jev allows 255 options; 256 → HTTP 400; the JevGateway adapter adds `none_of_these`). While more
    than 254 remain, drop in this order, within a kind the last in document order first: the whole item →
    sections → paragraphs → whole labelled lines; then the remaining excerpts from the end of the document.
    The result stays in document order.

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
Single-line tests look only at the Candidates without a line break. Derivation:
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
  (`PasteAttemptHarness`, fake Jev choosing it) and ends `.inserted`, i.e. passes Core's verbatim check; plus
  `everyCandidateOfAThousandLineSourceIsAByteExactSubstring` (UTF-8 `firstRange` for all 254 Candidates).
- `derivationIsDeterministic` (same input twice → identical output).

Multi-line kinds:
- `paragraphOfTwoOrMoreLinesSpansItsLineBreaksByteForByte` (inner CRLF, tabs and indentation kept)
- `singleLineParagraphsAddNothing`; `singleLineItemHasNoWholeItemCandidate`
- `wholeItemSpansBlankLinesAndIsTrimmedOfOuterBlankLines`; `singleParagraphItemIsOfferedOnce`
- `colonHeadingLeadsASectionUntilTheNextBlankLine`; `markdownHeadingLeadsASection`;
  `upperCaseHeadingLeadsASectionEvenWhenItsFirstBodyLineIsUpperCase`; `lineFollowedByDeeperIndentedLinesLeadsASection`;
  `shortLineAfterABlankLineLeadsASection`
- `sectionEndsBeforeTheNextHeadingLikeLine`; `sectionEndsBeforeALineIndentedLessThanItsBody`
- `headingWithoutBodyYieldsNoSection`; `labelledLinesAndShortLinesInsideAParagraphAreNotHeadingLike`
- `multiLineCandidatesComeInDocumentOrderContainersFirst` (full expected list of a small document)
- `paragraphIsTheAnswerInAMixedDocumentAndIsDeliveredVerbatim`,
  `wholeItemIsTheAnswerInAMixedDocumentAndIsDeliveredVerbatim` (through `PasteAttemptHarness`: offered, then
  written to the clipboard byte for byte, `.inserted`)
- Cap: `overCapDropsTheWholeItemFirst`; `overCapDropsSectionsBeforeParagraphs`;
  `overCapDropsParagraphsBeforeWholeLabelledLines`; the single-line cap tests above keep passing unchanged.

Same type:
- `emailsShareATypeAndIncludeTheChosenOne`; `urlsShareAType`; `phonesShareAType`; `handlesShareAType`
- `emailAndHandleAreDifferentTypes`; `wholeLabelledLineHasNoType`; `shortNumbersTimesAndYearsAreNotPhones`
- `untypedChosenReturnsOnlyItself`; `chosenNotAmongCandidatesReturnsOnlyItself`;
  `chosenInADifferentEncodingThanItsCandidateReturnsOnlyItself`
- `singleEmailAmongOtherTypesReturnsOnlyItself`

## Open questions
1. Issue text says "with source ranges"; the port's `Candidate` carries text only. Ranges are not exposed; Core's
   validation re-finds the text. No Core change proposed.
2. No per-Candidate length cap: excerpts over 255 characters (long lines, most paragraphs, the whole item) are
   offered whole; Jev's option-description limit is the JevGateway adapter's concern.
3. Resolved by the amendment: multi-line kinds (rules 5–6). Range selection by Jev stays the fallback if the cap
   bites on real documents.
4. The adapter is renamed `LineAndLabelCandidateExtraction` → `StructuralCandidateExtraction` (it now derives
   paragraphs, sections and the whole item too). Nothing outside the tests refers to it.
