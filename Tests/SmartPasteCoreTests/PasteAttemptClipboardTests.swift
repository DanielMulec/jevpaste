import SmartPasteCore
import Testing

@MainActor
struct PasteAttemptClipboardTests {
    static let newCopy = "Call me at +44 20 7946 0000"

    @Test func newCopyMidFlightDeliversThePinnedItemAndBecomesActiveAfterwards() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clipboard.simulateForeignCopy(Self.newCopy)
        harness.jev.choose("ada@example.com")
        harness.clipboard.deliverPendingChanges()
        harness.clock.advance(by: .milliseconds(120))
        harness.clipboard.deliverPendingChanges()

        #expect(harness.jev.requests.map(\.sourceDocument) == [PasteAttemptHarness.sourceText])
        #expect(harness.log.steps.first == .write("ada@example.com"))
        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.capture.activeItem == ClipboardItem(text: Self.newCopy))
    }

    @Test func targetMismatchAtDeliveryFailsAsTargetChangedWithPasteboardUntouched() {
        let harness = PasteAttemptHarness()
        let contentsBefore = harness.clipboard.contents

        harness.hotkey.press()
        harness.targetResolver.focusedTarget = BoundTarget(
            identity: TargetIdentity(processIdentifier: 42, elementToken: 8),
            context: TargetContext(fieldLabel: "Name"),
            isSecureField: false
        )
        harness.jev.choose("ada@example.com")

        #expect(harness.presenter.outcomes == [.failed(.targetChanged)])
        #expect(harness.log.steps.isEmpty)
        #expect(harness.clipboard.contents == contentsBefore)
    }

    @Test func ownPasteboardWritesNeverProduceAHistoryItem() {
        let harness = PasteAttemptHarness()
        let source = ClipboardItem(text: PasteAttemptHarness.sourceText)

        harness.pasteChoosing("ada@example.com")
        harness.clipboard.deliverPendingChanges()
        harness.clock.advance(by: .milliseconds(120))
        harness.clipboard.deliverPendingChanges()

        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.history.recordedItems == [source])
        #expect(harness.capture.activeItem == source)
    }

    @Test func concealedCopyBecomesActiveButIsNeverRecorded() {
        let harness = PasteAttemptHarness()
        let password = ClipboardItem(text: "correct horse battery staple", isConcealed: true)

        harness.clipboard.simulateForeignCopy(password.text, isConcealed: true)

        #expect(harness.capture.activeItem == password)
        #expect(harness.history.recordedItems == [ClipboardItem(text: PasteAttemptHarness.sourceText)])
    }
}
