import JevGateway
import SmartPasteCore
import os

/// What the result slot right of a provider's Test button says.
enum ProviderKeyResult: Equatable {
    case none
    /// Opened from "No key for <provider> — open Settings" with no key saved.
    case missingKey
    case testing
    case works
    case failed(JevConnectionTestFailure)
    case notSaved(status: Int32)

    func text(for provider: JevProvider) -> String {
        switch self {
        case .none: ""
        case .missingKey: "⚠︎ No key for \(provider.displayName) — paste it here."
        case .testing: "Testing…"
        case .works: "✓ Works — Jev answered through \(provider.displayName)."
        case .failed(let failure): "✕ " + Self.reason(for: failure, through: provider)
        case .notSaved(let status): "✕ Could not save the key to the Keychain (error \(status))"
        }
    }

    private static func reason(for failure: JevConnectionTestFailure, through provider: JevProvider) -> String {
        switch failure {
        case .noKey: "No key saved"
        case .keyRejected(let status): "Key not accepted (HTTP \(status))"
        case .rateLimited: "Jev asked us to wait — try again in a moment"
        case .noConnection: "No connection to \(provider.displayName)"
        case .httpStatus(let status): "\(provider.displayName) answered HTTP \(status)"
        case .unexpectedAnswer: "Jev's answer was not the one offered"
        }
    }
}

/// The key rows' logic in Settings › Jev Provider: every edit saves the key to the Keychain (an empty field removes
/// it) and clears the row's result; Test sends one cheap Jev call with the saved key. A result for a key that has
/// been edited since is dropped. Keys never reach a log.
@MainActor
final class ProviderKeySettings {
    typealias ConnectionTest = @MainActor (JevProvider, @escaping @MainActor (JevConnectionTestResult) -> Void) -> Void

    private static let log = Logger(subsystem: "jevpaste", category: "Settings")

    private let keys: any JevKeyStore
    private let runTest: ConnectionTest
    private var results: [JevProvider: ProviderKeyResult] = [:]
    /// Counts edits per provider, so a test answer for an older key is recognised.
    private var editCounts: [JevProvider: Int] = [:]
    /// Called after a row's result changed (a test answered).
    var onResultChange: (@MainActor (JevProvider) -> Void)?

    init(keys: any JevKeyStore, runTest: @escaping ConnectionTest) {
        self.keys = keys
        self.runTest = runTest
    }

    func savedKey(of provider: JevProvider) -> String {
        keys.apiKey(for: provider) ?? ""
    }

    func result(for provider: JevProvider) -> ProviderKeyResult {
        results[provider] ?? .none
    }

    func keyEdited(_ key: String, for provider: JevProvider) {
        editCounts[provider, default: 0] += 1
        do {
            try keys.setAPIKey(key, for: provider)
            results[provider] = ProviderKeyResult.none
        } catch {
            results[provider] = .notSaved(status: error.status)
        }
    }

    func test(_ provider: JevProvider) {
        let edits = editCounts[provider, default: 0]
        results[provider] = .testing
        Self.log.notice("test \(provider.rawValue, privacy: .public) started")
        runTest(provider) { [weak self] outcome in
            guard let self, editCounts[provider, default: 0] == edits else { return }
            results[provider] = Self.result(of: outcome)
            Self.log.notice(
                "test \(provider.rawValue, privacy: .public) \(String(describing: outcome), privacy: .public)")
            onResultChange?(provider)
        }
    }

    func openedForMissingKey(of provider: JevProvider) {
        results[provider] = savedKey(of: provider).isEmpty ? .missingKey : ProviderKeyResult.none
    }

    private static func result(of outcome: JevConnectionTestResult) -> ProviderKeyResult {
        switch outcome {
        case .works: .works
        case .failed(let failure): .failed(failure)
        }
    }
}
