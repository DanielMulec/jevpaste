import SmartPasteCore
import os

/// The `JevProviderAccess` adapter: at ⌘⇧V it reads the chosen Jev Provider and that provider's key, once, and
/// hands out a decision service holding the key for the whole Paste Attempt. A provider without a key is reported,
/// never replaced by another. Only the Vercel AI Gateway is built; Typesafe direct follows in its own ticket.
@MainActor
public struct JevGatewayAccess: JevProviderAccess {
    /// The providers this adapter can reach; Settings offers only these.
    public static let builtProviders: Set<JevProvider> = [.vercelAIGateway]
    private static let log = Logger(subsystem: "jevpaste", category: "JevGateway")

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

    /// The provider's decision service holding its key as saved now, or `nil` when it has none or is not built.
    func decisionService(for provider: JevProvider) -> JevGatewayDecisionService? {
        guard Self.builtProviders.contains(provider) else {
            Self.log.error("provider \(provider.rawValue, privacy: .public) is not built yet")
            return nil
        }
        guard let apiKey = credentials.apiKey(for: provider), !apiKey.isEmpty else { return nil }
        return JevGatewayDecisionService(apiKey: apiKey, transport: transport)
    }
}
