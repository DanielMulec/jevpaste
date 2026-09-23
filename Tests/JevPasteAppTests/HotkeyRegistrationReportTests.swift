import Testing

@testable import JevPasteApp

@MainActor
struct HotkeyRegistrationReportTests {
    @Test func aFailedRegistrationShowsTheShortcutNoticeForEightSeconds() {
        let screen = RecordingIndicatorSurface()
        let clock = SteppedClock()
        let notices = IndicatorNoticeSurface(wrapping: screen, clock: clock)

        HotkeyRegistrationReport.failed(status: -9878, notices: notices)

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
}
