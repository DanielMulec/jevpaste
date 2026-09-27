import JevGateway
import SmartPasteCore
import os

/// Keeps a copied Jev Provider key out of Clipboard History: a copy whose text, trimmed of outer whitespace, equals
/// any stored key is excluded (Copy Capture adopts it as concealed). Reads the key store at each copy, so a key
/// saved or changed in Settings counts at once. Logs only that a copy matched — never the text or which provider.
@MainActor
struct StoredKeyCaptureExclusion: CaptureExclusion {
    private static let log = Logger(subsystem: "jevpaste", category: "Keys")

    let keys: any JevCredentials

    func excludes(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let matches = JevProvider.allCases.contains { keys.apiKey(for: $0) == trimmed }
        if matches {
            Self.log.notice("copy of a stored key kept out of history")
        }
        return matches
    }
}
