import SmartPasteCore
import Testing

@testable import JevPasteApp

/// "No key for <provider> — open Settings" is the one outcome a click acts on: it opens Settings at that provider's
/// key. Every other outcome stays click-inert, and the refusal only while it is shown.
@MainActor
struct NoProviderKeyRefusalTests {
    private let surface = RecordingIndicatorSurface()
    private let clock = SteppedClock()
    private let presenter: IndicatorPresenter
    private let settings = SettingsOpenings()

    init() {
        presenter = IndicatorPresenter(
            surface: surface, clock: clock,
            focusReturn: TargetAppFocusReturn(activator: FakeApplicationActivator(), clock: clock))
        presenter.opensSettingsToKey = { [settings] provider in settings.openedToKeyOf.append(provider) }
    }

    @Test func aClickOnTheRefusalOpensSettingsAtThatProvidersKeyAndHidesIt() {
        presenter.showOutcome(.refused(.noProviderKey(.vercelAIGateway)), note: nil, path: nil, wakeWait: nil)
        surface.click()
        surface.click()

        #expect(settings.openedToKeyOf == [.vercelAIGateway])
        #expect(surface.displayed == nil)
    }

    @Test(arguments: [
        PasteAttemptOutcome.refused(.noActiveItem), .refused(.noEditableTarget), .refused(.suspectedSecret),
        .failed(.decisionUnavailable), .noSuitableMatch, .cancelled, .inserted,
    ])
    func aClickOnAnyOtherOutcomeOpensNothing(outcome: PasteAttemptOutcome) {
        presenter.showOutcome(outcome, note: nil, path: nil, wakeWait: nil)
        surface.click()

        #expect(settings.openedToKeyOf.isEmpty)
        #expect(surface.displayed != nil)
    }

    @Test func aClickAfterTheRefusalHidOpensNothing() {
        presenter.showOutcome(.refused(.noProviderKey(.vercelAIGateway)), note: nil, path: nil, wakeWait: nil)
        clock.step(by: .seconds(5))
        surface.click()

        #expect(surface.displayed == nil)
        #expect(settings.openedToKeyOf.isEmpty)
    }

    @Test func aNewAttemptOverTheRefusalTakesTheClickAsACancel() {
        var cancels = 0
        presenter.showOutcome(.refused(.noProviderKey(.vercelAIGateway)), note: nil, path: nil, wakeWait: nil)
        presenter.showProcessing { cancels += 1 }
        surface.click()

        #expect(cancels == 1)
        #expect(settings.openedToKeyOf.isEmpty)
    }
}

/// Where the refusal sent the user.
@MainActor
final class SettingsOpenings {
    var openedToKeyOf: [JevProvider] = []
}
