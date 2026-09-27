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
        let directoryFailure = preparedDirectory()
        guard directoryFailure == 0 else { return directoryFailure }
        let temporary = directory.appending(path: ".\(file.lastPathComponent).\(UUID().uuidString)")
        let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { return errno }
        let writeError = Self.writeAll(Array(key.utf8)) { buffer, count in Foundation.write(descriptor, buffer, count) }
        guard close(descriptor) == 0, writeError == 0, rename(temporary.path, file.path) == 0 else {
            let failure = writeError == 0 ? errno : writeError
            unlink(temporary.path)
            return failure
        }
        return 0
    }

    /// Creates the directory if missing, then insists it is a real directory (not a symbolic link) owned by the user
    /// and tightens it to 0700 — also when it already existed with a looser mode. 0 on success, else an errno.
    private func preparedDirectory() -> Int32 {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
            )
        } catch {
            return Int32((error as NSError).code)
        }
        var status = stat()
        guard lstat(directory.path, &status) == 0 else { return errno }
        guard status.st_mode & S_IFMT == S_IFDIR else { return ENOTDIR }
        guard status.st_uid == getuid() else { return EPERM }
        guard status.st_mode & 0o777 != 0o700 else { return 0 }
        return chmod(directory.path, 0o700) == 0 ? 0 : errno
    }

    /// Writes every byte through `write`, retrying after a short write or EINTR. 0 on success; else the write's errno,
    /// or EIO when a write makes no progress without saying why — never 0 for an incomplete key.
    static func writeAll(
        _ bytes: [UInt8], through write: (UnsafeRawPointer?, Int) -> Int
    ) -> Int32 {
        var offset = 0
        while offset < bytes.count {
            let written = bytes.withUnsafeBytes { write($0.baseAddress?.advanced(by: offset), $0.count - offset) }
            if written > 0 {
                offset += written
            } else if written < 0, errno == EINTR {
                continue
            } else {
                return written < 0 && errno != 0 ? errno : EIO
            }
        }
        return 0
    }

    private func remove(_ file: URL) -> Int32 {
        unlink(file.path) == 0 || errno == ENOENT ? 0 : errno
    }
}
