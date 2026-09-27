import Foundation
import JevGateway
import SmartPasteCore

/// The opt-in live tests' switch and keys: `JEVPASTE_LIVE_JEV=1`, and a provider's key read from the app's key file
/// `~/.config/jevpaste/keys/<provider raw value>`. A provider without a key file (or with an empty one) is skipped.
/// Nothing here ever prints or logs a key, or anything about it.
enum LiveJev {
    static let keysDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".config/jevpaste/keys", directoryHint: .isDirectory)

    static func isEnabled(for provider: JevProvider) -> Bool {
        ProcessInfo.processInfo.environment["JEVPASTE_LIVE_JEV"] == "1" && apiKey(for: provider) != nil
    }

    static func apiKey(for provider: JevProvider) -> String? {
        let file = keysDirectory.appending(path: provider.rawValue, directoryHint: .notDirectory)
        guard let data = FileManager.default.contents(atPath: file.path),
            let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty
        else { return nil }
        return key
    }

    /// The provider's production service with its stored key; `session` lets a measurement start cold.
    static func service(for provider: JevProvider, session: URLSession = .shared) throws -> JevGatewayDecisionService {
        guard let apiKey = apiKey(for: provider) else { throw MissingKey() }
        return JevGatewayDecisionService(
            provider: provider, apiKey: apiKey, transport: URLSessionTransport(session: session)
        )
    }

    /// One labelled line on standard error: `[<tag>] <fields>` — numbers, ids and fixed words only.
    static func report(_ tag: String, _ fields: String) {
        FileHandle.standardError.write(Data("[\(tag)] \(fields)\n".utf8))
    }

    static func milliseconds(_ duration: Duration) -> Int {
        Int((Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15).rounded())
    }

    struct MissingKey: Error {}
}
