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
    case notSaved(code: Int32)

    func text(for provider: JevProvider) -> String {
        switch self {
        case .none: ""
        case .missingKey: "⚠︎ No key for \(provider.displayName) — paste it here."
        case .testing: "Testing…"
        case .works: "✓ Works — Jev answered through \(provider.displayName)."
        case .failed(let failure): "✕ " + Self.reason(for: failure, through: provider)
        case .notSaved(let code): "✕ Could not save the key (error \(code))"
        }
    }

    /// Every reason names the provider, so the two rows never read alike.
    private static func reason(for failure: JevConnectionTestFailure, through provider: JevProvider) -> String {
        let name = provider.displayName
        return switch failure {
        case .noKey: "No key saved for \(name)"
        case .keyRejected(let status): "\(name) did not accept the key (HTTP \(status))"
        case .rateLimited: "\(name) asked us to wait — try again in a moment"
        case .noConnection: "No connection to \(name)"
        case .httpStatus(let status): "\(name) answered HTTP \(status)"
        case .unexpectedAnswer: "Jev's answer through \(name) was not the one offered"
        }
    }
}

/// The key rows' logic in Settings › Jev Provider: every edit saves the key to the key store (an empty field removes
/// it) and clears the row's result; Test sends one cheap Jev call with the saved key. A result for a key that has
/// been edited since is dropped. When editing ends (the field is left, Test, Settings closes) the saved key is taken
/// out of Clipboard History — it was usually copied, and so recorded, before it was pasted here. Keys never reach a
/// log.
@MainActor
final class ProviderKeySettings {
    typealias ConnectionTest = @MainActor (JevProvider, @escaping @MainActor (JevConnectionTestResult) -> Void) -> Void

    private static let log = Logger(subsystem: "jevpaste", category: "Settings")

    private let keys: any JevKeyStore
    private let runTest: ConnectionTest
    private let excludeFromHistory: @MainActor (String) -> Void
    private var results: [JevProvider: ProviderKeyResult] = [:]
    /// Counts edits per provider, so a test answer for an older key is recognised.
    private var editCounts: [JevProvider: Int] = [:]
    /// Called after a row's result changed (a test answered).
    var onResultChange: (@MainActor (JevProvider) -> Void)?

    init(
        keys: any JevKeyStore, excludeFromHistory: @escaping @MainActor (String) -> Void,
        runTest: @escaping ConnectionTest
    ) {
        self.keys = keys
        self.excludeFromHistory = excludeFromHistory
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
            results[provider] = .notSaved(code: error.code)
        }
    }

    /// The field was left or Settings closed: the saved key, if any, leaves Clipboard History (`CopyCapture`).
    func editingEnded(for provider: JevProvider) {
        guard let key = keys.apiKey(for: provider) else { return }
        excludeFromHistory(key)
        Self.log.notice("key for \(provider.rawValue, privacy: .public) kept out of history")
    }

    func test(_ provider: JevProvider) {
        editingEnded(for: provider)
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
