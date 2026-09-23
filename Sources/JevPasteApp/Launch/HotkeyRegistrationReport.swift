import os

/// Makes a failed ⌘⇧V registration visible: without it Smart Paste can never start, so silence would look like a
/// broken app.
@MainActor
enum HotkeyRegistrationReport {
    private static let log = Logger(subsystem: "jevpaste", category: "Launch")
    private static let noticeDuration = Duration.seconds(8)

    /// Logs the Carbon `status` and shows the shortcut notice.
    static func failed(status: Int32, notices: IndicatorNoticeSurface) {
        log.error("⌘⇧V registration failed with status \(status, privacy: .public)")
        notices.show(
            IndicatorNotice(
                warning: "⌘⇧V unavailable — another app uses it; quit that app, then relaunch JevPaste",
                for: noticeDuration
            )
        )
    }
}
