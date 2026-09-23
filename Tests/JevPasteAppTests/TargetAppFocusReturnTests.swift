import SmartPasteCore
import Testing

@testable import JevPasteApp

@MainActor
struct TargetAppFocusReturnTests {
    private static let chrome: Int32 = 4242

    private let activator = FakeApplicationActivator()
    private let clock = SteppedClock()
    private let focusReturn: TargetAppFocusReturn

    init() {
        focusReturn = TargetAppFocusReturn(activator: activator, clock: clock)
    }

    @Test func activatesTheTargetAppAndFinishesAtOnceWhenItIsAlreadyFrontmost() {
        activator.frontmostProcessIdentifier = Self.chrome
        var results: [FocusReturnResult] = []

        focusReturn.returnFocus(to: Self.chrome) { results.append($0) }

        #expect(activator.activated == [Self.chrome])
        #expect(results == [.frontmost(after: .zero)])
    }

    @Test func finishesOnTheFirstPollThatSeesTheTargetAppFrontmost() {
        activator.frontmostProcessIdentifier = 1
        var results: [FocusReturnResult] = []

        focusReturn.returnFocus(to: Self.chrome) { results.append($0) }
        clock.step(by: .milliseconds(10))
        clock.step(by: .milliseconds(10))
        #expect(results.isEmpty)
        activator.frontmostProcessIdentifier = Self.chrome
        clock.step(by: .milliseconds(10))

        #expect(results == [.frontmost(after: .milliseconds(30))])
    }

    @Test func givesUpAfterOneSecondWhenTheTargetAppNeverComesToTheFront() {
        activator.frontmostProcessIdentifier = 1
        var results: [FocusReturnResult] = []

        focusReturn.returnFocus(to: Self.chrome) { results.append($0) }
        for _ in 0..<99 {
            clock.step(by: .milliseconds(10))
        }
        #expect(results.isEmpty)
        clock.step(by: .milliseconds(10))
        clock.step(by: .milliseconds(100))

        #expect(results == [.notFrontmost(after: .seconds(1))])
    }

    @Test func finishesAtOnceWhenTheTargetAppIsGone() {
        activator.runningProcessIdentifiers = []
        var results: [FocusReturnResult] = []

        focusReturn.returnFocus(to: Self.chrome) { results.append($0) }

        #expect(results == [.appGone])
    }
}

/// Stands in for `NSRunningApplication` activation and `NSWorkspace.frontmostApplication`; a test moves the front.
@MainActor
final class FakeApplicationActivator: ApplicationActivator {
    var runningProcessIdentifiers: Set<Int32> = [4242, 1]
    var frontmostProcessIdentifier: Int32?
    private(set) var activated: [Int32] = []

    func activate(processIdentifier: Int32) -> Bool {
        activated.append(processIdentifier)
        return runningProcessIdentifiers.contains(processIdentifier)
    }
}
