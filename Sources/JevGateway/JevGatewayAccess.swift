import SmartPasteCore

/// The `JevProviderAccess` adapter: at ⌘⇧V it reads the chosen Jev Provider and that provider's key, once, and
/// hands out a decision service holding the key for the whole Paste Attempt. A provider without a key is reported,
/// never replaced by another.
@MainActor
public struct JevGatewayAccess: JevProviderAccess {
    private let credentials: any JevCredentials
    private let chosenProvider: @MainActor () -> JevProvider
    private let transport: any HTTPTransport

    public init(
        credentials: any JevCredentials, chosenProvider: @escaping @MainActor () -> JevProvider,
        transport: any HTTPTransport = URLSessionTransport()
    ) {
        self.credentials = credentials
        self.chosenProvider = chosenProvider
        self.transport = transport
    }

    public func openForPasteAttempt() -> JevProviderOpening {
        let provider = chosenProvider()
        guard let service = decisionService(for: provider) else { return .noKey(provider) }
        return .ready(service)
    }

    /// The provider's decision service holding its key as saved now, or `nil` when it has none.
    func decisionService(for provider: JevProvider) -> JevGatewayDecisionService? {
        guard let apiKey = credentials.apiKey(for: provider), !apiKey.isEmpty else { return nil }
        return JevGatewayDecisionService(provider: provider, apiKey: apiKey, transport: transport)
    }
}
