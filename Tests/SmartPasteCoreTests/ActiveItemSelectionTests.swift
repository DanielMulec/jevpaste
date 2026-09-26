import SmartPasteCore
import Testing

/// Selecting an older Clipboard Item inside the app makes it the Active Item until the next copy or selection,
/// without touching Clipboard History or the clipboard.
@MainActor
struct ActiveItemSelectionTests {
    /// An older copy that still holds two of the harness's Candidates, so a Paste Attempt on it reaches Jev.
    private static let older = ClipboardItem(text: "Ada Lovelace\nada@work.example")

    private let harness = PasteAttemptHarness()

    @Test func selectingMakesTheItemActiveWithoutRecordingReorderingOrWritingTheClipboard() {
        harness.history.record(Self.older)
        harness.clipboard.simulateForeignCopy(PasteAttemptHarness.sourceText)
        let historyBefore = harness.history.items()
        let recordedBefore = harness.history.recordedItems
        let clipboardBefore = harness.clipboard.contents

        harness.capture.select(Self.older)

        #expect(harness.capture.activeItem == Self.older)
        #expect(harness.history.items() == historyBefore)
        #expect(harness.history.recordedItems == recordedBefore)
        #expect(harness.clipboard.contents == clipboardBefore)
    }

    @Test func aLaterCopyReplacesASelection() {
        harness.capture.select(Self.older)

        harness.clipboard.simulateForeignCopy("Wren Castellan")

        #expect(harness.capture.activeItem == ClipboardItem(text: "Wren Castellan"))
    }

    @Test func aSelectionDuringAPasteAttemptLeavesThePinnedItemAloneAndServesTheNextAttempt() {
        harness.hotkey.press()

        harness.capture.select(Self.older)
        harness.jev.narrow(to: "ada@example.com")
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.log.steps.first == .write("ada@example.com"))
        #expect(harness.capture.activeItem == Self.older)
        harness.hotkey.press()
        #expect(harness.jev.requests.last?.sourceDocument == Self.older.text)
    }

    @Test func deletingTheActiveItemFromHistoryKeepsItActiveForTheNextPaste() {
        harness.history.record(Self.older)
        harness.capture.select(Self.older)

        harness.history.delete(Self.older)
        harness.hotkey.press()

        #expect(harness.history.items().contains(Self.older) == false)
        #expect(harness.capture.activeItem == Self.older)
        #expect(harness.jev.requests.last?.sourceDocument == Self.older.text)
    }

    @Test func thePasteAttemptsOwnWriteAndRestoreLeaveASelectionActive() {
        harness.clipboard.simulateForeignCopy("Wren Castellan")
        harness.capture.select(Self.older)

        harness.pasteChoosing("ada@work.example")
        harness.clock.advance(by: .milliseconds(120))
        harness.clipboard.deliverPendingChanges()

        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.capture.activeItem == Self.older)
    }

    @Test func theObserverHearsCopiesAndSelectionsWithTheirCause() {
        var changes: [ActiveItemChange] = []
        harness.capture.observeActiveItemChanges { changes.append($0) }

        harness.capture.select(Self.older)
        harness.clipboard.simulateForeignCopy("Wren Castellan")

        #expect(
            changes == [
                ActiveItemChange(item: Self.older, cause: .selected),
                ActiveItemChange(item: ClipboardItem(text: "Wren Castellan"), cause: .copied),
            ]
        )
    }

    @Test func thePasteAttemptsOwnWritesAreNeverReportedAsChanges() {
        var changes: [ActiveItemChange] = []
        harness.capture.observeActiveItemChanges { changes.append($0) }

        harness.pasteChoosing("ada@example.com")
        harness.clock.advance(by: .milliseconds(120))
        harness.clipboard.deliverPendingChanges()

        #expect(changes.isEmpty)
    }
}
