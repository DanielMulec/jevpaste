import Foundation
import HistoryStore
import SmartPasteCore
import os

/// Opens persistent Clipboard History at launch and makes every history failure visible on the indicator.
@MainActor
enum ClipboardHistoryOpening {
    static let retentionLimit = 500

    private static let log = Logger(subsystem: "jevpaste", category: "History")

    /// The SQLite history at `fileURL`, or — when the file is unusable — `UnavailableHistoryRepository` plus a
    /// notice naming the cause. Later failures are reported to `notices` from the main actor.
    static func open(
        at fileURL: URL = HistoryStoreLocation.defaultFileURL,
        notices: IndicatorNoticeSurface
    ) -> any HistoryRepository {
        do {
            return try SQLiteHistoryRepository(
                fileURL: fileURL,
                retentionLimit: retentionLimit,
                onFailure: reportingFailures { [weak notices] notice in notices?.show(notice) }
            )
        } catch {
            let kind = String(describing: error)
            log.error("history unavailable, running without it: \(kind, privacy: .public)")
            notices.show(IndicatorNotice(historyUnavailable: error))
            return UnavailableHistoryRepository()
        }
    }

    /// A failure callback for the repository's own queue: it only hops to the main actor and delivers the notice.
    /// It never touches the repository, so it cannot wait on the queue it is running on.
    nonisolated static func reportingFailures(
        to deliver: @escaping @MainActor (IndicatorNotice) -> Void
    ) -> @Sendable (HistoryStoreFailure) -> Void {
        { failure in
            Task { @MainActor in deliver(IndicatorNotice(historyRuntimeFailure: failure)) }
        }
    }
}
