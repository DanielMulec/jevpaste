import SmartPasteCore
import Testing

@testable import JevPasteApp

/// The No Suitable Match offer on the indicator: it takes key focus for Enter and Esc, hands focus back to the
/// Bound Target's app, and only then calls Core back — once.
@MainActor
struct NoSuitableMatchOfferPresenterTests {
    private static let chrome: Int32 = 4242
    private static let phoneField = BoundTarget(
        identity: TargetIdentity(processIdentifier: chrome, elementToken: 1),
        context: TargetContext(fieldLabel: "Phone"),
        isSecureField: false
    )
    private static let offerText = "No suitable match — press Enter to paste everything"

    private let surface = RecordingIndicatorSurface()
    private let activator = FakeApplicationActivator()
    private let clock = SteppedClock()
    private let presenter: IndicatorPresenter
    private let replies = OfferReplies()

    init() {
        activator.frontmostProcessIdentifier = Self.chrome
        presenter = IndicatorPresenter(
            surface: surface, clock: clock, focusReturn: TargetAppFocusReturn(activator: activator, clock: clock)
        )
    }

    private func offer() {
        presenter.showNoSuitableMatchOffer(
            for: Self.phoneField, onAccept: { replies.log.append("accept") },
            onDismiss: { replies.log.append("dismiss") })
    }

    @Test func theOfferShowsItsWordingAndTakesKeyFocus() {
        offer()

        #expect(surface.displayed == IndicatorContent(symbolName: "questionmark.circle", text: Self.offerText))
        #expect(surface.holdsKeyFocus)
        #expect(replies.log.isEmpty)
    }

    @Test func enterHidesTheOfferReturnsFocusAndAcceptsOnce() {
        offer()

        surface.send(.accept)
        surface.send(.accept)

        #expect(surface.displayed == nil)
        #expect(activator.activated == [Self.chrome])
        #expect(replies.log == ["accept"])
    }

    @Test func enterAcceptsOnlyOnceTheTargetAppIsFrontmost() {
        activator.frontmostProcessIdentifier = 1
        offer()

        surface.send(.accept)
        clock.step(by: .milliseconds(10))
        #expect(replies.log.isEmpty)
        activator.frontmostProcessIdentifier = Self.chrome
        clock.step(by: .milliseconds(10))

        #expect(replies.log == ["accept"])
    }

    @Test(arguments: [KeyPanelDismissal.escape, .clickAway])
    func escapeOrClickAwayDismisses(dismissal: KeyPanelDismissal) {
        offer()

        surface.send(.dismiss(dismissal))

        #expect(surface.displayed == nil)
        #expect(activator.activated == [Self.chrome])
        #expect(replies.log == ["dismiss"])
    }

    @Test func aLaterOutcomeWithdrawsTheOfferWithoutCallingBackAndReturnsFocus() {
        offer()

        presenter.showOutcome(.noSuitableMatch, note: nil, path: .jev(offer: .timedOut))
        surface.send(.accept)

        #expect(surface.displayed == OutcomeMessage(.noSuitableMatch).content)
        #expect(!surface.holdsKeyFocus)
        #expect(activator.activated == [Self.chrome])
        #expect(replies.log.isEmpty)
    }

    /// The panel reports its own resign-key as a click-away while the outcome replaces the offer; that must not
    /// answer the withdrawn offer.
    @Test func theClickAwayCausedByWithdrawingTheOfferIsNotAnAnswer() {
        surface.reportsClickAwayWhenGivingUpKeyFocus = true
        offer()

        presenter.showOutcome(.noSuitableMatch, note: nil, path: .jev(offer: .timedOut))

        #expect(surface.displayed == OutcomeMessage(.noSuitableMatch).content)
        #expect(activator.activated == [Self.chrome])
        #expect(replies.log.isEmpty)
    }

    @Test func aClickOnTheOfferDoesNothing() {
        offer()

        surface.click()

        #expect(surface.displayed?.text == Self.offerText)
        #expect(replies.log.isEmpty)
    }
}

@MainActor
private final class OfferReplies {
    var log: [String] = []
}
