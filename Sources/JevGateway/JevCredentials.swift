import SmartPasteCore

/// Where the API key of each Jev Provider is kept — in the app, the Keychain. Keys are never logged.
public protocol JevCredentials {
    /// The provider's key, or `nil` when it has none.
    func apiKey(for provider: JevProvider) -> String?
}
