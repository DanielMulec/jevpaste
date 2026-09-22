extension ClipboardItem {
    /// Whether `excerpt` is one exact, contiguous, verbatim excerpt of this item — compared byte for byte in UTF-8,
    /// so a canonically equivalent but differently encoded answer is rejected. Empty is never a Paste Result.
    func containsVerbatim(_ excerpt: String) -> Bool {
        !excerpt.isEmpty && text.utf8.firstRange(of: excerpt.utf8) != nil
    }
}
