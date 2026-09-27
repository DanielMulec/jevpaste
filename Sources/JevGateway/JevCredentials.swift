import SmartPasteCore

/// Where the API key of each Jev Provider is kept — in the app, user-only files. Keys are never logged. Read on the
/// main actor, once per Paste Attempt at ⌘⇧V.
@MainActor
public protocol JevCredentials {
    /// The provider's key, or `nil` when it has none.
    func apiKey(for provider: JevProvider) -> String?
}
