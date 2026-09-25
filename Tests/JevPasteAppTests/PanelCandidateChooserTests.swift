import SmartPasteCore
import Testing

@testable import JevPasteApp

@MainActor
struct PanelCandidateChooserTests {
    private static let chrome: Int32 = 4242
    private static let emailField = BoundTarget(
        identity: TargetIdentity(processIdentifier: chrome, elementToken: 1),
        context: TargetContext(fieldLabel: "Email address"),
        isSecureField: false
    )
    private static let emails = [
        Candidate(text: "maren.holtby@example.org"), Candidate(text: "maren.h@example.net"),
        Candidate(text: "maren@holtby.example"),
    ]

    private let surface = RecordingChooserSurface()
    private let activator = FakeApplicationActivator()
    private let clock = SteppedClock()
    private let indicator = RecordingIndicatorSurface()
    private let chooser: PanelCandidateChooser

    init() {
        activator.frontmostProcessIdentifier = Self.chrome
        let presenter = IndicatorPresenter(
            surface: indicator, clock: clock,
            focusReturn: TargetAppFocusReturn(activator: FakeApplicationActivator(), clock: clock))
        chooser = PanelCandidateChooser(
            surface: surface,
            focusReturn: TargetAppFocusReturn(activator: activator, clock: clock),
            indicator: presenter
        )
        presenter.showProcessing {}
    }

    private func present() -> ReplyLog {
        let log = ReplyLog()
        chooser.presentChoice(among: Self.emails, for: Self.emailField) { log.replies.append($0) }
        return log
    }

    @Test func opensWithTheTitleAndEveryCandidateInCoreOrderFirstSelectedIndicatorHidden() {
        _ = present()

        #expect(surface.shown == ChooserContent(candidates: Self.emails, context: Self.emailField.context))
        #expect(surface.selectedRow == 0)
        #expect(indicator.displayed == nil)
    }

    @Test func downAndEnterRepliesWithTheSecondCandidateUntouched() {
        let log = present()

        surface.send(.moveDown)
        surface.send(.chooseSelected)

        #expect(log.replies == [Self.emails[1]])
        #expect(surface.shown == nil)
    }

    @Test func selectionStopsAtBothEnds() {
        let log = present()

        surface.send(.moveUp)
        #expect(surface.selectedRow == 0)
        for _ in 0..<5 {
            surface.send(.moveDown)
        }
        #expect(surface.selectedRow == 2)
        surface.send(.chooseSelected)

        #expect(log.replies == [Self.emails[2]])
    }

    @Test func clickingARowRepliesWithThatCandidate() {
        let log = present()

        surface.send(.choose(row: 2))

        #expect(log.replies == [Self.emails[2]])
    }

    @Test(arguments: [KeyPanelDismissal.escape, .clickAway])
    func cancellingClosesAndRepliesNothing(_ cancellation: KeyPanelDismissal) {
        let log = present()

        surface.send(.cancel(cancellation))

        #expect(log.replies == [nil])
        #expect(surface.shown == nil)
        #expect(activator.activated == [Self.chrome])
    }

    @Test func replyWaitsUntilTheTargetAppIsFrontmost() {
        activator.frontmostProcessIdentifier = 1
        let log = present()

        surface.send(.chooseSelected)
        #expect(surface.shown == nil)
        clock.step(by: .milliseconds(10))
        #expect(log.replies.isEmpty)
        activator.frontmostProcessIdentifier = Self.chrome
        clock.step(by: .milliseconds(10))

        #expect(log.replies == [Self.emails[0]])
    }

    @Test func replyComesAfterOneSecondWhenTheTargetAppNeverComesBack() {
        activator.frontmostProcessIdentifier = 1
        let log = present()

        surface.send(.chooseSelected)
        clock.step(by: .milliseconds(990))
        #expect(log.replies.isEmpty)
        clock.step(by: .milliseconds(10))

        #expect(log.replies == [Self.emails[0]])
    }

    @Test func replyComesAtOnceWhenTheTargetAppIsGone() {
        activator.runningProcessIdentifiers = []
        let log = present()

        surface.send(.cancel(.escape))

        #expect(log.replies == [nil])
    }

    @Test func eventsAfterTheAnswerAreIgnoredSoItRepliesOnce() {
        activator.frontmostProcessIdentifier = 1
        let log = present()

        surface.send(.chooseSelected)
        surface.send(.cancel(.clickAway))
        surface.send(.cancel(.escape))
        surface.send(.choose(row: 1))
        clock.step(by: .seconds(2))
        surface.send(.cancel(.escape))

        #expect(log.replies == [Self.emails[0]])
        #expect(activator.activated == [Self.chrome])
    }

    @Test func aSecondChoiceWhileOneIsOpenIsDeclinedAtOnceAndTheOpenOneStillAnswers() {
        let first = present()
        let second = ReplyLog()

        chooser.presentChoice(among: Array(Self.emails.prefix(2)), for: Self.emailField) { second.replies.append($0) }
        #expect(second.replies == [nil])
        #expect(first.replies.isEmpty)
        surface.send(.choose(row: 2))

        #expect(first.replies == [Self.emails[2]])
    }

    @Test func aReplyThatOpensTheNextChoiceSynchronouslyLeavesItOpen() {
        let next = ReplyLog()
        chooser.presentChoice(among: Self.emails, for: Self.emailField) { _ in
            chooser.presentChoice(among: Array(Self.emails.prefix(2)), for: Self.emailField) {
                next.replies.append($0)
            }
        }

        surface.send(.chooseSelected)
        #expect(surface.shown?.rows.count == 2)
        #expect(next.replies.isEmpty)
        surface.send(.moveDown)
        surface.send(.chooseSelected)

        #expect(next.replies == [Self.emails[1]])
    }

}

/// Collects a chooser's replies; a class, so the reply closure and the test see the same list.
@MainActor
private final class ReplyLog {
    var replies: [Candidate?] = []
}
