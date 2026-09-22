extension RunningAttempt {
    /// Whether `pasteResult` may be delivered: it must be one of the Candidates `offered` to Jev or the Candidate
    /// Chooser, and one exact, contiguous, verbatim excerpt of the pinned Active Item. Every Paste Result passes
    /// this check before delivery.
    func accepts(_ pasteResult: Candidate, offeredAmong offered: [Candidate]) -> Bool {
        offered.contains(pasteResult) && item.containsVerbatim(pasteResult.text)
    }
}

extension ClipboardItem {
    /// Whether `excerpt` is one exact, contiguous, verbatim excerpt of this item — compared byte for byte in UTF-8,
    /// so a canonically equivalent but differently encoded answer is rejected. Empty is never a Paste Result.
    fileprivate func containsVerbatim(_ excerpt: String) -> Bool {
        !excerpt.isEmpty && text.utf8.firstRange(of: excerpt.utf8) != nil
    }
}
