import Foundation
import HistoryStore
import SmartPasteCore
import Testing

@testable import JevPasteApp

@MainActor
struct ClipboardHistoryOpeningTests {
    private let screen = RecordingIndicatorSurface()
    private let notices: IndicatorNoticeSurface
    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("jevpaste-app-test-\(UUID().uuidString)", isDirectory: true)

    init() {
        notices = IndicatorNoticeSurface(wrapping: screen, clock: SteppedClock())
    }

    private func removeDirectory() {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func usableFileOpensPersistentHistoryWithoutANotice() {
        defer { removeDirectory() }

        let history = ClipboardHistoryOpening.open(
            at: directory.appendingPathComponent("history.sqlite"), notices: notices)

        #expect(history is SQLiteHistoryRepository)
        #expect(screen.displayed == nil)
    }

    @Test func unusableFileFallsBackToNoHistoryAndSaysWhy() throws {
        defer { removeDirectory() }
        let fileURL = directory.appendingPathComponent("history.sqlite")
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)

        let history = ClipboardHistoryOpening.open(at: fileURL, notices: notices)

        #expect(history is UnavailableHistoryRepository)
        #expect(screen.displayed?.text.hasPrefix("History unavailable — ") == true)
    }

    @Test func failureReportedOffTheMainThreadArrivesOnTheMainActorAsANotice() async {
        let delivered = await withCheckedContinuation { continuation in
            let report = ClipboardHistoryOpening.reportingFailures { notice in
                MainActor.assertIsolated()
                continuation.resume(returning: notice)
            }
            DispatchQueue.global().async {
                report(.sqlite(operation: "record", resultCode: 8))
            }
        }

        #expect(delivered == IndicatorNotice(historyRuntimeFailure: .sqlite(operation: "record", resultCode: 8)))
    }

    @Test func unavailableHistoryKeepsNothing() {
        let history = UnavailableHistoryRepository()

        history.record(ClipboardItem(text: "Wren Castellan"))

        #expect(history.items().isEmpty)
    }
}
