import Foundation

/// The Vercel AI Gateway key in a shell-style env file (`~/.config/jevpaste/env`): since keys live in the Keychain,
/// only the source of the one-time import at launch, and of the opt-in live test. The key is never logged.
public struct GatewayCredentials: Sendable {
    static let keyName = "AI_GATEWAY_API_KEY"

    /// `~/.config/jevpaste/env`.
    public static let standard = GatewayCredentials(
        envFile: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/jevpaste/env")
    )

    public let envFile: URL

    public init(envFile: URL) {
        self.envFile = envFile
    }

    /// Whether a key is available, without revealing it.
    public var hasAPIKey: Bool { apiKey() != nil }

    /// The key from the first non-empty `AI_GATEWAY_API_KEY=` line, or `nil` if the file or the key is missing.
    public func apiKey() -> String? {
        guard let contents = try? String(contentsOf: envFile, encoding: .utf8) else { return nil }
        return contents.split(whereSeparator: \.isNewline).lazy.compactMap(Self.keyValue(in:)).first
    }

    private static func keyValue(in line: Substring) -> String? {
        var assignment = line.trimmingCharacters(in: .whitespaces)[...]
        if assignment.hasPrefix("export ") {
            assignment = assignment.dropFirst("export ".count).drop(while: \.isWhitespace)
        }
        guard assignment.hasPrefix(keyName + "=") else { return nil }
        let value = unquoted(assignment.dropFirst(keyName.count + 1).trimmingCharacters(in: .whitespaces))
        return value.isEmpty ? nil : value
    }

    private static func unquoted(_ value: String) -> String {
        for quote in ["\"", "'"] where value.count >= 2 && value.hasPrefix(quote) && value.hasSuffix(quote) {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
