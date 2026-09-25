import SmartPasteCore
import Testing

/// Direct Paste: a single-line Active Item is inserted whole through the ordinary delivery step, without Jev.
@MainActor
struct PasteAttemptDirectPasteTests {
    static let phoneNumber = "  +41 44 668 18 00\t"
    /// A phone number copied with its trailing line break, as a terminal or a table cell yields it.
    static let copiedPhoneNumber = "\r\n" + phoneNumber + "\r\n\n"

    @Test func aSingleLineItemIsPastedWithoutAskingJevEvenIntoALabelledEmailField() {
        let harness = PasteAttemptHarness(candidates: [], sourceText: Self.copiedPhoneNumber)
        let original = harness.clipboard.contents

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.jev.requests.isEmpty)
        #expect(harness.chooser.offeredCandidates == nil)
        #expect(harness.log.steps == [.write(Self.phoneNumber), .pasteKeystroke, .restore])
        #expect(harness.log.time(of: .restore) == .milliseconds(120))
        #expect(harness.clipboard.contents == original)
        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.presenter.paths == [.directPaste])
    }

    @Test func aDirectPasteShowsNoProcessingIndicatorAndRunsNoFiveSecondClock() {
        let harness = PasteAttemptHarness(sourceText: Self.phoneNumber)

        harness.hotkey.press()
        harness.clock.advance(by: .seconds(6))

        #expect(harness.presenter.processingShownAt == nil)
        #expect(harness.presenter.retryingShownCount == 0)
        #expect(harness.presenter.outcomes == [.inserted])
    }

    @Test func aForeignCopyDuringTheRestoreWindowWinsAsForAnySmartPaste() {
        let harness = PasteAttemptHarness(sourceText: Self.phoneNumber)

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(60))
        harness.clipboard.simulateForeignCopy("Meeting moved to 3 pm")
        harness.clock.advance(by: .milliseconds(60))

        #expect(harness.log.steps == [.write(Self.phoneNumber), .pasteKeystroke])
        #expect(harness.presenter.outcomes == [.insertedWithoutRestore])
        #expect(harness.presenter.paths == [.directPaste])
    }

    @Test func aTargetThatLostFocusBeforeDeliveryLeavesTheClipboardUntouched() {
        let harness = PasteAttemptHarness(sourceText: Self.phoneNumber)
        harness.targetResolver.focusMovesAwayOnceResolved = true

        harness.hotkey.press()

        #expect(harness.log.steps.isEmpty)
        #expect(harness.presenter.deliveringShownCount == 0)
        #expect(harness.presenter.outcomes == [.failed(.targetChanged)])
        #expect(harness.presenter.paths == [.directPaste])
    }

    @Test(arguments: [PreCheckRefusal.secureField, .suspectedSecret])
    func thePreChecksStillRefuseASingleLineItemFirst(refusal: PreCheckRefusal) {
        let harness =
            refusal == .secureField
            ? PasteAttemptHarness(focusedTarget: PasteAttemptStartTests.passwordField, sourceText: Self.phoneNumber)
            : PasteAttemptHarness(sourceText: StubPreCheck.secretPrefix + "4f9a1c")

        harness.hotkey.press()

        #expect(harness.presenter.outcomes == [.refused(refusal)])
        #expect(harness.presenter.paths == [nil])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func aWhitespaceOnlyItemEndsInNoSuitableMatchWithoutJevOrPaste() {
        let harness = PasteAttemptHarness(sourceText: " \t\r\n\n ")

        harness.hotkey.press()

        #expect(harness.presenter.outcomes == [.noSuitableMatch])
        #expect(harness.jev.requests.isEmpty)
        #expect(harness.log.steps.isEmpty)
    }

    @Test func aMultiLineItemStillGoesThroughJev() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        #expect(harness.jev.requests.count == 1)
        harness.jev.choose("ada@example.com")
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.log.steps == [.write("ada@example.com"), .pasteKeystroke, .restore])
        #expect(harness.presenter.paths == [.jev(freeTextProbability: 0)])
    }

    /// Stand-in for a Rejev-paste until the history UI can select an older item: the Active Item, not whatever the
    /// clipboard holds now, is what a Direct Paste inserts.
    @Test func anOlderSingleLineActiveItemIsDirectPastedWhileTheClipboardHoldsSomethingElse() {
        let harness = PasteAttemptHarness(sourceText: Self.copiedPhoneNumber)
        harness.clipboard.simulateForeignNonTextCopy()
        let imageOnClipboard = harness.clipboard.contents

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.jev.requests.isEmpty)
        #expect(harness.log.steps == [.write(Self.phoneNumber), .pasteKeystroke, .restore])
        #expect(harness.clipboard.contents == imageOnClipboard)
    }
}
