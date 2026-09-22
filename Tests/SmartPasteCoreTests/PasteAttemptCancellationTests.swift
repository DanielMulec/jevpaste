import SmartPasteCore
import Testing

@MainActor
struct PasteAttemptCancellationTests {
    @Test func escapeDuringProcessingCancelsWithoutDelivery() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(150))
        harness.presenter.pressEscape()
        harness.jev.choose("ada@example.com")

        #expect(harness.presenter.outcomes == [.cancelled])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func escapeAfterDeliveryStartedHasNoEffect() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(150))
        harness.jev.choose("ada@example.com")
        harness.presenter.pressEscape()
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.log.steps == [.write("ada@example.com"), .pasteKeystroke, .restore])
    }
}
