import Foundation

/// Where the history file lives and how it is kept readable by the user only.
public enum HistoryStoreLocation {
    /// `~/Library/Application Support/jevpaste/history.sqlite`.
    public static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("jevpaste", isDirectory: true)
            .appendingPathComponent("history.sqlite")
    }

    private static let directoryMode = 0o700
    private static let fileMode = 0o600

    /// Creates the file's directory (mode 0700) if absent, and the file itself (mode 0600) if absent.
    static func prepareFile(at fileURL: URL) throws(HistoryStoreFailure) {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: directoryMode])
        } catch {
            throw .directoryUnavailable
        }
        guard !fileManager.fileExists(atPath: fileURL.path) else { return }
        let created = fileManager.createFile(
            atPath: fileURL.path, contents: nil, attributes: [.posixPermissions: fileMode])
        guard created else { throw .fileNotCreated }
    }

    /// Sets mode 0600 on the file, which also tightens a file created earlier with looser permissions.
    static func restrictToUser(_ fileURL: URL) throws(HistoryStoreFailure) {
        do {
            try FileManager.default.setAttributes([.posixPermissions: fileMode], ofItemAtPath: fileURL.path)
        } catch {
            throw .permissionsNotRestricted
        }
    }
}
