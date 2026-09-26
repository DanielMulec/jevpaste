import SmartPasteCore
import Testing

@MainActor
struct PasteAttemptCancellationTests {
    @Test func clickDuringProcessingCancelsWithoutDelivery() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(150))
        harness.presenter.clickIndicator()
        harness.jev.narrow(to: "ada@example.com")

        #expect(harness.presenter.outcomes == [.cancelled])
        #expect(harness.log.steps.isEmpty)
    }

    @Test func clickAfterDeliveryStartedHasNoEffect() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(150))
        harness.jev.narrow(to: "ada@example.com")
        harness.presenter.clickIndicator()
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.log.steps == [.write("ada@example.com"), .pasteKeystroke, .restore])
    }
}
