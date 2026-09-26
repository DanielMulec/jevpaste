import JevGateway
import Security
import SmartPasteCore

/// The Jev Providers' API keys as Settings reads and writes them; JevGateway reads them as `JevCredentials`. In the
/// app, the Keychain (`KeychainJevKeyStore`); in tests, in memory. Keys are never logged.
@MainActor
protocol JevKeyStore: JevCredentials {
    /// Stores `key` as the provider's key; an empty key removes it.
    func setAPIKey(_ key: String, for provider: JevProvider) throws(JevKeyStoreFailure)
}

/// A Keychain call failed; only its status is kept, so it is safe to log.
struct JevKeyStoreFailure: Error, Equatable {
    let status: OSStatus
}
