import HistoryStore

/// The visible form of a Clipboard History failure: a short line on the indicator. Smart Paste keeps working
/// without history, so a notice only informs; it never offers an action.
struct HistoryNotice: Equatable {
    let content: IndicatorContent
    let displayDuration: Duration

    private static let symbolName = "exclamationmark.triangle"
    /// Read with the launch notice, which appears once and names a cause, so it stays longer.
    private static let unavailableDuration = Duration.seconds(5)
    private static let runtimeFailureDuration = Duration.milliseconds(2500)
    /// `SQLITE_NOTADB`: the file exists but is not a database.
    private static let notADatabase: Int32 = 26

    /// The history file could not be opened at launch; the app runs without Clipboard History.
    init(unavailable failure: HistoryStoreFailure) {
        self.init(text: "History unavailable — " + Self.reason(for: failure), displayDuration: Self.unavailableDuration)
    }

    /// An operation failed after a successful open: reading history, or any write (the write is lost).
    init(runtimeFailure failure: HistoryStoreFailure) {
        let text = Self.isRead(failure) ? "History read failed" : "History write failed"
        self.init(text: text, displayDuration: Self.runtimeFailureDuration)
    }

    private init(text: String, displayDuration: Duration) {
        content = IndicatorContent(symbolName: Self.symbolName, text: text)
        self.displayDuration = displayDuration
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
