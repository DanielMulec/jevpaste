import SmartPasteCore
import Testing

/// The chosen Jev Provider is read once, at ⌘⇧V: without its key the attempt is refused before anything else happens;
/// with it, every request of the attempt goes through that provider, whatever Settings says meanwhile.
@MainActor
struct JevProviderAccessTests {
    @Test func withoutAKeyForTheChosenProviderTheAttemptIsRefusedBeforeReadingTheTarget() {
        let harness = PasteAttemptHarness()
        harness.jevProvider.servicesByKeyedProvider = [:]

        harness.hotkey.press()

        #expect(harness.presenter.outcomes == [.refused(.noProviderKey(.vercelAIGateway))])
        #expect(harness.targetResolver.readCount == 0)
        #expect(harness.jev.requests.isEmpty)
        #expect(harness.log.steps.isEmpty)
    }

    @Test func nothingCopiedYetIsRefusedFirstWithoutOpeningTheProvider() {
        let harness = PasteAttemptHarness(copySource: false)
        harness.jevProvider.servicesByKeyedProvider = [:]

        harness.hotkey.press()

        #expect(harness.presenter.outcomes == [.refused(.noActiveItem)])
        #expect(harness.jevProvider.openingCount == 0)
    }

    @Test func theProviderIsOpenedOnceForAnAttemptOfSeveralSteps() {
        let harness = PasteAttemptHarness()

        harness.pasteChoosing("ada@example.com")

        #expect(harness.jev.requests.count == 2)
        #expect(harness.jevProvider.openingCount == 1)
    }

    @Test func aProviderSwitchDuringAnAttemptAppliesFromTheNextAttempt() {
        let harness = PasteAttemptHarness()
        let typesafe = FakeDecisionService()
        harness.jevProvider.servicesByKeyedProvider[.typesafeDirect] = typesafe

        harness.hotkey.press()
        harness.jevProvider.chosenProvider = .typesafeDirect
        harness.jev.pick("ada@example.com")
        harness.jev.keep()
        harness.clock.advance(by: .seconds(1))
        harness.hotkey.press()

        #expect(harness.jev.requests.count == 2)
        #expect(typesafe.requests.count == 1)
    }
}
