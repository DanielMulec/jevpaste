import CryptoKit
import Foundation

/// The identity of a Clipboard History entry: the SHA-256 of its text's UTF-8 bytes after trimming leading and
/// trailing whitespace. Two copies with the same key are one entry. Compared byte for byte, so differently
/// encoded but canonically equivalent text stays distinct.
struct DistinctKey {
    let bytes: Data

    /// `nil` for empty and whitespace-only text, which is never stored.
    init?(of text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        bytes = Data(SHA256.hash(data: Data(trimmed.utf8)))
    }
}
