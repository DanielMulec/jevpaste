import SmartPasteCore

/// The brief confirmation after a selection from Clipboard History: which item ⌘⇧V pastes from now. It shares the
/// history panel's pin symbol for "Active", and waits behind a Paste Attempt's indicator like every notice.
extension IndicatorNotice {
    private static let selectionDuration = Duration.milliseconds(2500)
    private static let maximumFirstLineLength = 40

    init(activeItemSelected item: ClipboardItem) {
        let line = item.firstLine
        let shown =
            line.count > Self.maximumFirstLineLength
            ? line.prefix(Self.maximumFirstLineLength - 1) + "…" : line
        self.init(symbolName: ActiveItemView.symbolName, text: "Active: " + shown, for: Self.selectionDuration)
    }
}
