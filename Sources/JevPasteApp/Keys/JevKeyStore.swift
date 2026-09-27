import JevGateway
import Security
import SmartPasteCore

/// The Jev Providers' API keys as Settings reads and writes them; JevGateway reads them as `JevCredentials`. In the
/// app, user-only files (`FileJevKeyStore`); in tests, in memory. Keys are never logged.
@MainActor
protocol JevKeyStore: JevCredentials {
    /// Stores `key` as the provider's key; an empty key removes it.
    func setAPIKey(_ key: String, for provider: JevProvider) throws(JevKeyStoreFailure)
}

/// Storing a key failed; only a numeric code (errno or Keychain status) is kept, so it is safe to log and show.
struct JevKeyStoreFailure: Error, Equatable {
    let code: Int32
}
