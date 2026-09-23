import SmartPasteCore
import Testing

@testable import JevPasteApp

/// A missing Accessibility grant — including a stale one that Settings still shows as on — is visible at launch and
/// on ⌘⇧V, never a silent or misleading refusal.
@MainActor
struct AccessibilityGrantCheckTests {
    private let screen = RecordingIndicatorSurface()
    private let clock = SteppedClock()
    private let trust = FakeAccessibilityTrust()
    private let hotkey = ListeningHotkeyDouble()
    private let check: AccessibilityGrantCheck

    init() {
        check = AccessibilityGrantCheck(trust: trust, notices: IndicatorNoticeSurface(wrapping: screen, clock: clock))
    }

    @Test func grantedAtLaunchShowsNothing() {
        check.checkAtLaunch()

        #expect(screen.displayed == nil)
    }

    @Test func missingAtLaunchShowsTheGrantNoticeForEightSeconds() {
        trust.isTrusted = false
        check.checkAtLaunch()

        #expect(screen.displayed == IndicatorNotice.accessibilityMissing(for: .seconds(8)).content)
        clock.step(by: .seconds(8))
        #expect(screen.displayed == nil)
    }

    @Test func theNoticeSaysWhatToDo() {
        let text = IndicatorNotice.accessibilityMissing(for: .seconds(5)).content.text

        #expect(text == "No Accessibility access — turn JevPaste off and on in Settings › Privacy › Accessibility")
    }

    @Test func pressWhileGrantedStartsThePasteAttempt() {
        var attempts = 0
        GrantCheckingHotkey(wrapping: hotkey, check: check).startListening { attempts += 1 }

        hotkey.press()

        #expect(attempts == 1)
        #expect(screen.displayed == nil)
    }

    @Test func pressWhileMissingShowsTheNoticeForFiveSecondsInsteadOfAPasteAttempt() {
        var attempts = 0
        GrantCheckingHotkey(wrapping: hotkey, check: check).startListening { attempts += 1 }
        trust.isTrusted = false

        hotkey.press()

        #expect(attempts == 0)
        #expect(screen.displayed == IndicatorNotice.accessibilityMissing(for: .seconds(5)).content)
        clock.step(by: .seconds(5))
        #expect(screen.displayed == nil)
    }

    @Test func theNextPressAfterTheGrantReturnsStartsThePasteAttempt() {
        var attempts = 0
        GrantCheckingHotkey(wrapping: hotkey, check: check).startListening { attempts += 1 }
        trust.isTrusted = false
        check.checkAtLaunch()
        hotkey.press()

        trust.isTrusted = true
        hotkey.press()

        #expect(attempts == 1)
    }
}

@MainActor
final class FakeAccessibilityTrust: AccessibilityTrust {
    var isTrusted = true
}

/// Stands in for the ⌘⇧V registration: keeps the handler the decorator registered, so a test can press ⌘⇧V.
@MainActor
final class ListeningHotkeyDouble: Hotkey {
    private(set) var press: @MainActor () -> Void = {}

    func startListening(onPress: @escaping @MainActor () -> Void) {
        press = onPress
    }
}
