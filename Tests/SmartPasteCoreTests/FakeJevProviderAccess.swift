import SmartPasteCore

/// The Jev Provider chosen in Settings and which providers hold a key: opening for a Paste Attempt hands out the
/// chosen provider's decision service, or reports that it has no key. Counts every opening.
@MainActor
final class FakeJevProviderAccess: JevProviderAccess {
    var chosenProvider = JevProvider.vercelAIGateway
    /// What each provider's key reaches; a provider missing here has no key.
    var servicesByKeyedProvider: [JevProvider: FakeDecisionService]
    private(set) var openingCount = 0

    init(servicesByKeyedProvider: [JevProvider: FakeDecisionService]) {
        self.servicesByKeyedProvider = servicesByKeyedProvider
    }

    func openForPasteAttempt() -> JevProviderOpening {
        openingCount += 1
        guard let service = servicesByKeyedProvider[chosenProvider] else { return .noKey(chosenProvider) }
        return .ready(service)
    }
}
