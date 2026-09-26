import Foundation
import JevGateway
import SmartPasteCore
import os

/// The one-time import at launch: the Vercel AI Gateway key of `~/.config/jevpaste/env` moves into the Keychain, so
/// an existing setup carries over. Once done — imported, already in the Keychain, or no key in the file — it is
/// remembered and the env file is never read again. The file is never deleted.
@MainActor
enum JevKeyImport {
    enum Result: String, Equatable {
        case alreadyDone
        case keychainHasKey
        case imported
        case noEnvKey
        /// The Keychain refused the key; the import runs again at the next launch.
        case failed
    }

    static let doneFlag = "jevProviderKeyImportDone"
    private static let log = Logger(subsystem: "jevpaste", category: "Keys")

    @discardableResult
    static func runOnce(
        into keys: any JevKeyStore, from envFile: GatewayCredentials, remembering defaults: UserDefaults
    ) -> Result {
        let result = importUnlessDone(into: keys, from: envFile, remembering: defaults)
        if result != .alreadyDone && result != .failed { defaults.set(true, forKey: doneFlag) }
        log.notice("key import \(result.rawValue, privacy: .public)")
        return result
    }

    private static func importUnlessDone(
        into keys: any JevKeyStore, from envFile: GatewayCredentials, remembering defaults: UserDefaults
    ) -> Result {
        guard !defaults.bool(forKey: doneFlag) else { return .alreadyDone }
        guard keys.apiKey(for: .vercelAIGateway) == nil else { return .keychainHasKey }
        guard let envKey = envFile.apiKey() else { return .noEnvKey }
        do {
            try keys.setAPIKey(envKey, for: .vercelAIGateway)
            return .imported
        } catch {
            log.error("key import could not store the key status=\(error.status, privacy: .public)")
            return .failed
        }
    }
}
