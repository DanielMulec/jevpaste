import Foundation
import JevGateway
import SmartPasteCore

@testable import JevPasteApp

/// The Keychain as far as JevPaste sees it: one key per provider; writes can be made to fail.
@MainActor
final class InMemoryJevKeyStore: JevKeyStore {
    private(set) var keys: [JevProvider: String]
    var failsWrites = false

    init(keys: [JevProvider: String] = [:]) {
        self.keys = keys
    }

    func apiKey(for provider: JevProvider) -> String? {
        keys[provider]
    }

    func setAPIKey(_ key: String, for provider: JevProvider) throws(JevKeyStoreFailure) {
        guard !failsWrites else { throw JevKeyStoreFailure(status: -25_299) }
        keys[provider] = key.isEmpty ? nil : key
    }
}

/// A `UserDefaults` domain of its own, removed when the value goes away.
final class ScratchDefaults {
    let suiteName = "JevPasteAppTests-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

/// An env file in a fresh temporary directory, as `~/.config/jevpaste/env` would hold it.
func temporaryEnvFile(containing text: String?) throws -> GatewayCredentials {
    let file = FileManager.default.temporaryDirectory.appending(path: "jevpaste-import-\(UUID().uuidString).env")
    if let text { try Data(text.utf8).write(to: file) }
    return GatewayCredentials(envFile: file)
}
