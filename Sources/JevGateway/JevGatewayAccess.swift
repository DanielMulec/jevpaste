import SmartPasteCore
import os

/// The `JevProviderAccess` adapter: at ⌘⇧V it reads the chosen Jev Provider and that provider's key, once, and
/// hands out a decision service holding the key for the whole Paste Attempt. A provider without a key is reported,
/// never replaced by another. Only the Vercel AI Gateway is built; Typesafe direct follows in its own ticket.
@MainActor
public struct JevGatewayAccess: JevProviderAccess {
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
        guard provider == .vercelAIGateway else {
            Self.log.error("provider \(provider.rawValue, privacy: .public) is not built yet")
            return .noKey(provider)
        }
        guard let apiKey = credentials.apiKey(for: provider), !apiKey.isEmpty else { return .noKey(provider) }
        return .ready(JevGatewayDecisionService(apiKey: apiKey, transport: transport))
    }
}
