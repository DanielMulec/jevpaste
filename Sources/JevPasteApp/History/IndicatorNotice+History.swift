import HistoryStore

/// The visible form of a Clipboard History failure: a short line on the indicator. Smart Paste keeps working
/// without history, so a notice only informs; it never offers an action.
extension IndicatorNotice {
    /// Read with the launch notice, which appears once and names a cause, so it stays longer.
    private static let unavailableDuration = Duration.seconds(5)
    private static let runtimeFailureDuration = Duration.milliseconds(2500)
    /// `SQLITE_NOTADB`: the file exists but is not a database.
    private static let notADatabase: Int32 = 26

    /// The history file could not be opened at launch; the app runs without Clipboard History.
    init(historyUnavailable failure: HistoryStoreFailure) {
        self.init(warning: "History unavailable — " + Self.reason(for: failure), for: Self.unavailableDuration)
    }

    /// An operation failed after a successful open: reading history, or any write (the write is lost).
    /// "History read failed" is unreachable today — nothing in the app calls `items()` yet; the history UI will
    /// (https://github.com/DanielMulec/jevpaste/issues/27, "Implement the history UI"). Keep it.
    init(historyRuntimeFailure failure: HistoryStoreFailure) {
        let text = Self.isRead(failure) ? "History read failed" : "History write failed"
        self.init(warning: text, for: Self.runtimeFailureDuration)
    }

    private static func isRead(_ failure: HistoryStoreFailure) -> Bool {
        guard case .sqlite(let operation, _) = failure else { return false }
        return operation == "items"
    }

    private static func reason(for failure: HistoryStoreFailure) -> String {
        switch failure {
        case .directoryUnavailable: "folder not usable"
        case .fileNotCreated: "file not created"
        case .permissionsNotRestricted: "file permissions not set"
        case .sqlite(operation: "open", _): "file could not be opened"
        case .sqlite(_, notADatabase): "file is not a database"
        case .sqlite(_, let resultCode): "database error \(resultCode)"
        case .unsupportedSchemaVersion: "written by a newer version"
        }
    }
}
