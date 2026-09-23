import Testing

@testable import JevPasteApp

@MainActor
struct HotkeyRegistrationReportTests {
    private let screen = RecordingIndicatorSurface()
    private let clock = SteppedClock()
    private let notices: IndicatorNoticeSurface

    init() {
        notices = IndicatorNoticeSurface(wrapping: screen, clock: clock)
    }

    @Test func anotherAppHoldingTheShortcutIsNamedForEightSeconds() {
        HotkeyRegistrationReport.failed(status: -9878, notices: notices)  // eventHotKeyExistsErr

        #expect(
            screen.displayed
                == IndicatorContent(
                    symbolName: "exclamationmark.triangle",
                    text: "⌘⇧V unavailable — another app uses it; quit that app, then relaunch JevPaste"
                )
        )
        clock.step(by: .seconds(8))
        #expect(screen.displayed == nil)
    }

    @Test(arguments: [Int32(-50), -9870, -108])
    func anyOtherFailureSaysListeningFailedWithoutBlamingAnotherApp(status: Int32) {
        HotkeyRegistrationReport.failed(status: status, notices: notices)

        #expect(screen.displayed?.text == "Could not listen for ⌘⇧V — relaunch JevPaste")
        clock.step(by: .seconds(8))
        #expect(screen.displayed == nil)
    }
}
