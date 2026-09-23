import ApplicationServices
import SmartPasteCore
import os

/// Whether macOS trusts this process for Accessibility; in the app `AXIsProcessTrusted()`, which never prompts.
@MainActor
protocol AccessibilityTrust {
    var isTrusted: Bool { get }
}

struct ProcessAccessibilityTrust: AccessibilityTrust {
    var isTrusted: Bool { AXIsProcessTrusted() }
}

/// Makes a missing Accessibility grant visible. A grant can be missing while System Settings shows JevPaste as on
/// (a stale row after a Signing Identity change); only turning it off and on again helps, so the notice says that.
/// Checked at launch and again on every ⌘⇧V — no polling.
@MainActor
final class AccessibilityGrantCheck {
    private static let log = Logger(subsystem: "jevpaste", category: "Launch")
    /// Read once at launch, so it stays longer than the per-press reminder.
    private static let launchNoticeDuration = Duration.seconds(8)
    private static let pressNoticeDuration = Duration.seconds(5)

    private let trust: any AccessibilityTrust
    private let notices: IndicatorNoticeSurface
    private var lastSeenTrusted = true

    init(trust: any AccessibilityTrust, notices: IndicatorNoticeSurface) {
        self.trust = trust
        self.notices = notices
    }

    func checkAtLaunch() {
        let isTrusted = trust.isTrusted
        lastSeenTrusted = isTrusted
        Self.log.notice("grant check at launch trusted=\(isTrusted, privacy: .public)")
        if !isTrusted { notices.show(.accessibilityMissing(for: Self.launchNoticeDuration)) }
    }

    /// Re-checks on ⌘⇧V: `true` when the Paste Attempt may start; otherwise shows the grant notice instead, since
    /// the attempt would only refuse with a misleading "No text field focused".
    func allowsPasteAttempt() -> Bool {
        let isTrusted = trust.isTrusted
        defer { lastSeenTrusted = isTrusted }
        if isTrusted {
            if !lastSeenTrusted { Self.log.notice("grant check on ⌘⇧V: Accessibility grant is back") }
            return true
        }
        Self.log.error("grant check on ⌘⇧V trusted=false; Paste Attempt not started")
        notices.show(.accessibilityMissing(for: Self.pressNoticeDuration))
        return false
    }
}

/// The `Hotkey` the coordinator listens to: ⌘⇧V passes on only while the Accessibility grant is present.
@MainActor
final class GrantCheckingHotkey: Hotkey {
    private let hotkey: any Hotkey
    private let check: AccessibilityGrantCheck

    init(wrapping hotkey: any Hotkey, check: AccessibilityGrantCheck) {
        self.hotkey = hotkey
        self.check = check
    }

    func startListening(onPress: @escaping @MainActor () -> Void) {
        hotkey.startListening { [check] in
            if check.allowsPasteAttempt() { onPress() }
        }
    }
}

extension IndicatorNotice {
    static func accessibilityMissing(for displayDuration: Duration) -> IndicatorNotice {
        IndicatorNotice(
            warning: "No Accessibility access — turn JevPaste off and on in Settings › Privacy › Accessibility",
            for: displayDuration
        )
    }
}
