import SmartPasteCore
import Testing

@testable import MacInterop

/// An app whose focus is unreadable until its Accessibility is fully on (Electron: `AXEnhancedUserInterface`)
/// is asked to wake once, and ⌘⇧V says so instead of "no text field" until the wake window ends.
@MainActor
struct AccessibilityWakeTests {
    private static let chatGPT = FrontmostApplication(processIdentifier: 7, name: "ChatGPT")
    private let source = FakeFocusSource()
    private let clock = FakeNow()
    private let resolver: FocusedTargetResolver<FakeFocusSource>

    init() {
        source.frontmost = Self.chatGPT
        resolver = FocusedTargetResolver(source: source, now: clock.read)
    }

    @Test func unreadableFocusInAnAppWhoseAccessibilityIsOffWakesItOnceAndSaysSo() {
        #expect(resolver.resolveFocusedTarget() == .waking(applicationName: "ChatGPT"))
        #expect(source.wakeRequests == [7])
    }

    @Test func pressingAgainWithinFiveSecondsStillSaysWakingWithoutAskingAgain() {
        _ = resolver.resolveFocusedTarget()
        clock.advance(by: .milliseconds(4_900))

        #expect(resolver.resolveFocusedTarget() == .waking(applicationName: "ChatGPT"))
        #expect(source.wakeRequests == [7])
    }

    @Test func focusStillUnreadableFiveSecondsAfterTheWakeIsNoEditableTarget() {
        _ = resolver.resolveFocusedTarget()
        clock.advance(by: .seconds(5))

        #expect(resolver.resolveFocusedTarget() == .noEditableTarget)
        #expect(source.wakeRequests == [7])
    }

    @Test func onceAwakeTheFocusedFieldResolves() {
        _ = resolver.resolveFocusedTarget()
        source.focus(FakeNode("AXTextArea"), processIdentifier: 7)

        #expect(resolver.resolveFocusedTarget().boundTarget?.identity.processIdentifier == 7)
    }

    @Test func appWhoseAccessibilityIsAlreadyOnIsNotWoken() {
        source.awakeProcesses = [7]

        #expect(resolver.resolveFocusedTarget() == .noEditableTarget)
        #expect(source.wakeRequests.isEmpty)
    }

    @Test func appThatIgnoresTheWakeRequestIsNoEditableTarget() {
        source.wakeRequestsTake = false

        #expect(resolver.resolveFocusedTarget() == .noEditableTarget)
    }

    @Test func theWakeWindowBelongsToTheProcessThatWasWoken() {
        _ = resolver.resolveFocusedTarget()
        source.frontmost = FrontmostApplication(processIdentifier: 8, name: "Other")
        source.wakeRequestsTake = false

        #expect(resolver.resolveFocusedTarget() == .noEditableTarget)
        #expect(source.wakeRequests == [7, 8])
    }

    @Test func noFrontmostAppIsNoEditableTarget() {
        source.frontmost = nil

        #expect(resolver.resolveFocusedTarget() == .noEditableTarget)
        #expect(source.wakeRequests.isEmpty)
    }

    @Test func focusedNonEditableElementNeverWakes() {
        source.focus(FakeNode("AXGroup"), processIdentifier: 7)

        #expect(resolver.resolveFocusedTarget() == .noEditableTarget)
        #expect(source.wakeRequests.isEmpty)
    }
}

/// A settable monotonic time for the wake window.
@MainActor
final class FakeNow {
    private var instant = ContinuousClock.now

    func read() -> ContinuousClock.Instant {
        instant
    }

    func advance(by duration: Duration) {
        instant += duration
    }
}
