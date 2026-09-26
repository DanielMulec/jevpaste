import JevGateway
import SmartPasteCore

/// Interim, until the Keychain store lands in this slice: the env file serves the Vercel AI Gateway's key.
extension GatewayCredentials: JevCredentials {
    public func apiKey(for provider: JevProvider) -> String? {
        provider == .vercelAIGateway ? apiKey() : nil
    }
}
