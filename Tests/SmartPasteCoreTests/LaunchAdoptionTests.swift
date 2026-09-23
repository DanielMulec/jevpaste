import SmartPasteCore
import Testing

/// Launch Adoption: the text on the clipboard when the app launches counts as a copy — it becomes the Active Item
/// and is recorded in Clipboard History unless it is concealed.
@MainActor
struct LaunchAdoptionTests {
    private let clipboard = FakeClipboard(log: DeliveryLog(clock: ManualClock()), initialText: "")
    private let history = FakeHistoryRepository()

    private func capture(contentsAtLaunch: ClipboardItem?) -> CopyCapture {
        CopyCapture(clipboard: clipboard, history: history, contentsAtLaunch: { contentsAtLaunch })
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

    /// The launch contents are read only after observation has started, so a copy landing in between is never lost:
    /// it is adopted at launch, and the observer's later report of it is recorded again as a harmless re-copy (same
    /// identity, moved to the top).
    @Test func copyBetweenStartingObservationAndReadingTheLaunchContentsIsAdoptedAtLaunch() {
        let later = ClipboardItem(text: "Wren Castellan")

        let capture = CopyCapture(clipboard: clipboard, history: history) { [clipboard] in
            clipboard.simulateForeignCopyNotYetObserved(later.text)
            return later
        }
        clipboard.deliverPendingChanges()

        #expect(capture.activeItem == later)
        #expect(history.items() == [later])
        #expect(history.recordedItems == [later, later])
    }

    /// The launch race: a copy lands after the clipboard was first looked at but before observation starts. Since
    /// the launch contents are read after observation starts, that copy is adopted at launch, recorded once.
    @Test func copyJustBeforeObservationStartsIsNeverLost() {
        clipboard.simulateForeignCopy("Tamsin Vorlage")
        clipboard.foreignCopyJustBeforeObservationStarts = "Wren Castellan"

        let capture = CopyCapture(clipboard: clipboard, history: history) { [clipboard] in clipboard.currentItem() }
        clipboard.deliverPendingChanges()

        #expect(capture.activeItem == ClipboardItem(text: "Wren Castellan"))
        #expect(history.recordedItems == [ClipboardItem(text: "Wren Castellan")])
    }
}
