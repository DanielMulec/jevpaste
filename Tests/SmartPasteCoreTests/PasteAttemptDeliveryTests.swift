import SmartPasteCore
import Testing

@MainActor
struct PasteAttemptDeliveryTests {
    @Test func deliveryWritesPastesWaitsExactly120MillisecondsThenRestoresTheOriginal() {
        let harness = PasteAttemptHarness()
        let original = harness.clipboard.contents

        harness.pasteChoosing("ada@example.com")
        harness.clock.advance(by: .milliseconds(119))
        #expect(harness.log.steps == [.write("ada@example.com"), .pasteKeystroke])
        harness.clock.advance(by: .milliseconds(1))

        #expect(harness.log.steps == [.write("ada@example.com"), .pasteKeystroke, .restore])
        #expect(harness.log.time(of: .restore) == .milliseconds(120))
        #expect(harness.clipboard.contents == original)
        #expect(harness.presenter.outcomes == [.inserted])
    }

    @Test func deliveryStartedJustBeforeTheDeadlineIsNotInterruptedByIt() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(4950))
        harness.jev.choose("ada@example.com")
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.log.steps.last == .restore)
    }

    @Test func foreignCopyDuringTheRestoreWindowSkipsRestoreAndBecomesActive() {
        let harness = PasteAttemptHarness()
        let foreignCopy = "Meeting moved to 3 pm"

        harness.pasteChoosing("ada@example.com")
        harness.clock.advance(by: .milliseconds(60))
        harness.clipboard.simulateForeignCopy(foreignCopy)
        harness.clock.advance(by: .milliseconds(60))

        #expect(harness.log.steps == [.write("ada@example.com"), .pasteKeystroke])
        #expect(harness.clipboard.contents == FakeClipboard.snapshot(of: foreignCopy))
        #expect(harness.presenter.outcomes == [.insertedWithoutRestore])
        #expect(harness.capture.activeItem == ClipboardItem(text: foreignCopy))
    }

    @Test func deliveryTellsThePresenterOnceBeforeItWritesTheClipboard() {
        let harness = PasteAttemptHarness()
        var stepsWhenTold: [DeliveryLog.Entry]?
        harness.presenter.onShowDelivering = { stepsWhenTold = harness.log.steps }

        harness.pasteChoosing("ada@example.com")
        harness.clock.advance(by: .milliseconds(120))

        #expect(stepsWhenTold == [])
        #expect(harness.presenter.deliveringShownCount == 1)
    }

    @Test func aTargetThatChangedBeforeDeliveryIsNeverAnnouncedAsDelivering() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.targetResolver.focusedTarget = nil
        harness.jev.choose("ada@example.com")

        #expect(harness.presenter.deliveringShownCount == 0)
        #expect(harness.presenter.outcomes == [.failed(.targetChanged)])
    }
}
