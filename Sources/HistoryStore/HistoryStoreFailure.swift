/// Why the history file could not be opened or a statement failed. Carries result codes, never item text.
public enum HistoryStoreFailure: Error, Equatable {
    /// The directory that should hold the history file does not exist and could not be created.
    case directoryUnavailable
    /// The history file's permissions could not be restricted to the user.
    case permissionsNotRestricted
    /// SQLite returned `resultCode` during `operation` (for example 26 = `SQLITE_NOTADB` for a corrupt file).
    case sqlite(operation: String, resultCode: Int32)
    /// The file was written by a newer schema this build does not know how to read.
    case unsupportedSchemaVersion(Int)
}
