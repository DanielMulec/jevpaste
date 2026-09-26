extension ClipboardItem {
    /// Whether `pasteResult` may be used: it must be one of the texts `offered` to Jev or the Candidate Chooser, and
    /// one exact, contiguous, verbatim excerpt of this item. Every piece Jev picks at every Narrowing step, and every
    /// Candidate Chooser pick, passes this check. Both comparisons are byte for byte in UTF-8: Swift's `String`
    /// equality treats canonically equivalent encodings as equal, which would let an unoffered encoding through.
    /// Empty is never a Paste Result.
    func acceptsPasteResult(_ pasteResult: Candidate, offeredAmong offered: [Candidate]) -> Bool {
        offered.contains { $0.text.utf8.elementsEqual(pasteResult.text.utf8) }
            && !pasteResult.text.isEmpty && text[...].containsExactly(pasteResult.text[...])
    }
}
