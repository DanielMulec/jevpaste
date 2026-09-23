import SmartPasteCore
import Testing

/// The text on the clipboard when the app launches counts as a copy: it becomes the Active Item and is recorded in
/// Clipboard History unless it is concealed.
@MainActor
struct CopyCaptureSeedingTests {
    private let clipboard = FakeClipboard(log: DeliveryLog(clock: ManualClock()), initialText: "")
    private let history = FakeHistoryRepository()

    private func capture(contentsAtLaunch: ClipboardItem?) -> CopyCapture {
        CopyCapture(clipboard: clipboard, history: history, contentsAtLaunch: contentsAtLaunch)
    }

    @Test func textPresentAtLaunchBecomesTheActiveItemAndIsRecorded() {
        let card = ClipboardItem(text: "Tamsin Vorlage\ntamsin.vorlage@example.com")

        let capture = capture(contentsAtLaunch: card)

        #expect(capture.activeItem == card)
        #expect(history.items() == [card])
    }

    @Test func concealedTextPresentAtLaunchBecomesTheActiveItemButIsNeverRecorded() {
        let password = ClipboardItem(text: "correct horse battery staple", isConcealed: true)

        let capture = capture(contentsAtLaunch: password)

        #expect(capture.activeItem == password)
        #expect(history.recordedItems.isEmpty)
    }

    @Test func clipboardWithoutTextAtLaunchLeavesNoActiveItemAndRecordsNothing() {
        let capture = capture(contentsAtLaunch: nil)

        #expect(capture.activeItem == nil)
        #expect(history.recordedItems.isEmpty)
    }

    @Test func emptyTextAtLaunchIsTreatedLikeAnEmptyLiveCopyAndStaysOutOfHistory() {
        let empty = ClipboardItem(text: "")

        let capture = capture(contentsAtLaunch: empty)

        #expect(capture.activeItem == empty)
        #expect(history.items().isEmpty)
    }

    @Test func aLaterCopyReplacesTheItemPresentAtLaunch() {
        let atLaunch = ClipboardItem(text: "Tamsin Vorlage")
        let capture = capture(contentsAtLaunch: atLaunch)

        clipboard.simulateForeignCopy("Wren Castellan")

        #expect(capture.activeItem == ClipboardItem(text: "Wren Castellan"))
        #expect(history.items() == [ClipboardItem(text: "Wren Castellan"), atLaunch])
    }
}
