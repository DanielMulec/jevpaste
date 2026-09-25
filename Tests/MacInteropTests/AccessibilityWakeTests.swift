import SmartPasteCore
import Testing

@testable import MacInterop

/// An unreadable focus in any frontmost app is reported as not readable yet, never as "no text field": Core re-reads
/// it during the Wake Wait. An app whose Accessibility is off (Electron: `AXEnhancedUserInterface`) is asked once
/// per process to turn it on.
@MainActor
struct AccessibilityWakeTests {
    private static let chatGPT = FrontmostApplication(processIdentifier: 7, name: "ChatGPT")
    private let source = FakeFocusSource()
    private let resolver: FocusedTargetResolver<FakeFocusSource>

    init() {
        source.frontmost = Self.chatGPT
        resolver = FocusedTargetResolver(source: source)
    }

    @Test func unreadableFocusInAnAppWhoseAccessibilityIsOnIsNotReadableYet() {
        source.awakeProcesses = [7]

        #expect(resolver.resolveFocusedTarget() == .focusUnreadable(applicationName: "ChatGPT"))
        #expect(source.wakeRequests.isEmpty)
    }

    /// An app that ignores the attribute (it keeps reading `false`) is not asked again on every read either.
    @Test(arguments: [true, false])
    func anAppWhoseAccessibilityIsOffIsAskedToWakeOnceAcrossReads(requestTakes: Bool) {
        source.wakeRequestsTake = requestTakes

        #expect(resolver.resolveFocusedTarget() == .focusUnreadable(applicationName: "ChatGPT"))
        #expect(resolver.resolveFocusedTarget() == .focusUnreadable(applicationName: "ChatGPT"))
        #expect(source.wakeRequests == [7])
    }

    @Test func eachProcessIsAskedOnce() {
        _ = resolver.resolveFocusedTarget()
        source.frontmost = FrontmostApplication(processIdentifier: 8, name: "Other")
        _ = resolver.resolveFocusedTarget()
        source.frontmost = Self.chatGPT
        _ = resolver.resolveFocusedTarget()

        #expect(source.wakeRequests == [7, 8])
    }

    @Test func onceAwakeTheFocusedFieldResolves() {
        _ = resolver.resolveFocusedTarget()
        source.focus(FakeNode("AXTextArea"), processIdentifier: 7)

        #expect(resolver.resolveFocusedTarget().boundTarget?.identity.processIdentifier == 7)
    }

    @Test func noFrontmostAppIsNoEditableTarget() {
        source.frontmost = nil

        #expect(resolver.resolveFocusedTarget() == .noEditableTarget)
        #expect(source.wakeRequests.isEmpty)
    }

    @Test func aReadableFocusWithNothingEditableIsNoEditableTargetAndNeverWakes() {
        source.focus(FakeNode("AXGroup"), processIdentifier: 7)

        #expect(resolver.resolveFocusedTarget() == .noEditableTarget)
        #expect(source.wakeRequests.isEmpty)
    }
}
