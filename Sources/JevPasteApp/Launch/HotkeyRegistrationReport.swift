import Carbon.HIToolbox
import os

/// Makes a failed ⌘⇧V registration visible: without it Smart Paste can never start, so silence would look like a
/// broken app. Only `eventHotKeyExistsErr` means another app holds the shortcut; any other status (e.g. the event
/// handler could not be installed) is reported without blaming one.
@MainActor
enum HotkeyRegistrationReport {
    private static let log = Logger(subsystem: "jevpaste", category: "Launch")
    private static let noticeDuration = Duration.seconds(8)

    /// Logs the Carbon `status` and shows the notice for its cause.
    static func failed(status: Int32, notices: IndicatorNoticeSurface) {
        log.error("⌘⇧V registration failed with status \(status, privacy: .public)")
        let text =
            status == eventHotKeyExistsErr
            ? "⌘⇧V unavailable — another app uses it; quit that app, then relaunch JevPaste"
            : "Could not listen for ⌘⇧V — relaunch JevPaste"
        notices.show(IndicatorNotice(warning: text, for: noticeDuration))
    }
}
