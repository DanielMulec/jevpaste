import Foundation
import SmartPasteCore
import os

/// The API keys as files only the user can read: `~/.config/jevpaste/keys/<provider>` (the provider's raw value),
/// the key's UTF-8 bytes, mode 0600, in a directory of mode 0700. A key is written to a new 0600 file beside the old
/// one and renamed over it, so a reader never sees a half-written or wider-readable key; an empty key removes the file.
/// Chosen over the Keychain for self-signed builds (see docs/design/menu-and-settings.md). Logs carry errno only.
struct FileJevKeyStore: JevKeyStore {
    static let standardDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".config/jevpaste/keys", directoryHint: .isDirectory)
    private static let log = Logger(subsystem: "jevpaste", category: "Keys")

    let directory: URL

    init(directory: URL = standardDirectory) {
        self.directory = directory
    }

    func apiKey(for provider: JevProvider) -> String? {
        guard let data = FileManager.default.contents(atPath: file(of: provider).path),
            let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty
        else { return nil }
        return key
    }

    func setAPIKey(_ key: String, for provider: JevProvider) throws(JevKeyStoreFailure) {
        let result = key.isEmpty ? remove(file(of: provider)) : write(key, to: file(of: provider))
        guard result == 0 else {
            Self.log.error("key write failed errno=\(result, privacy: .public)")
            throw JevKeyStoreFailure(code: result)
        }
        let change = key.isEmpty ? "removed" : "stored"
        Self.log.notice("key for \(provider.rawValue, privacy: .public) \(change, privacy: .public)")
    }

    private func file(of provider: JevProvider) -> URL {
        directory.appending(path: provider.rawValue, directoryHint: .notDirectory)
    }

    /// 0 on success, else the errno of the step that failed.
    private func write(_ key: String, to file: URL) -> Int32 {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
            )
        } catch {
            return Int32((error as NSError).code)
        }
        let temporary = directory.appending(path: ".\(file.lastPathComponent).\(UUID().uuidString)")
        let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        guard descriptor >= 0 else { return errno }
        let bytes = Array(key.utf8)
        let written = bytes.withUnsafeBytes { Foundation.write(descriptor, $0.baseAddress, $0.count) }
        let writeError = written == bytes.count ? 0 : errno
        guard close(descriptor) == 0, writeError == 0, rename(temporary.path, file.path) == 0 else {
            let failure = writeError == 0 ? errno : writeError
            unlink(temporary.path)
            return failure
        }
        return 0
    }

    private func remove(_ file: URL) -> Int32 {
        unlink(file.path) == 0 || errno == ENOENT ? 0 : errno
    }
}
