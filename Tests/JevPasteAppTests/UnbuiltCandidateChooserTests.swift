import SmartPasteCore
import Testing

@testable import JevPasteApp

@MainActor
struct UnbuiltCandidateChooserTests {
    private static let emailField = BoundTarget(
        identity: TargetIdentity(processIdentifier: 7, elementToken: 1),
        context: TargetContext(fieldLabel: "Email address"),
        isSecureField: false
    )
    private static let emails = [Candidate(text: "maren@example.org"), Candidate(text: "maren@work.example")]

    private let surface = RecordingIndicatorSurface()
    private let presenter: IndicatorPresenter
    private let chooser: UnbuiltCandidateChooser

    init() {
        presenter = IndicatorPresenter(surface: surface, clock: SteppedClock())
        chooser = UnbuiltCandidateChooser(presenter: presenter)
    }

    @Test func declinesToChooseAtOnceAndNeverGuesses() {
        var replies: [Candidate?] = []

        chooser.presentChoice(among: Self.emails, for: Self.emailField) { replies.append($0) }

        #expect(replies == [nil])
    }

    @Test func theResultingCancellationSaysTheChooserIsNotBuilt() {
        chooser.presentChoice(among: Self.emails, for: Self.emailField) { _ in
            presenter.showOutcome(.cancelled)
        }

        #expect(surface.displayed == OutcomeMessage.chooserNotBuilt.content)
    }

    @Test func aLaterPlainCancellationSaysCancelled() {
        chooser.presentChoice(among: Self.emails, for: Self.emailField) { _ in
            presenter.showOutcome(.cancelled)
        }
        presenter.showProcessing {}
        presenter.showOutcome(.cancelled)

        #expect(surface.displayed == OutcomeMessage(.cancelled).content)
    }
}
