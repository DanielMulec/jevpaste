import HistoryStore
import Testing

@testable import JevPasteApp

struct IndicatorNoticeHistoryTests {
    @Test(arguments: [
        (HistoryStoreFailure.directoryUnavailable, "History unavailable — folder not usable"),
        (.fileNotCreated, "History unavailable — file not created"),
        (.permissionsNotRestricted, "History unavailable — file permissions not set"),
        (.sqlite(operation: "open", resultCode: 14), "History unavailable — file could not be opened"),
        (.sqlite(operation: "readSchemaVersion", resultCode: 26), "History unavailable — file is not a database"),
        (.sqlite(operation: "createSchema", resultCode: 8), "History unavailable — database error 8"),
        (.unsupportedSchemaVersion(2), "History unavailable — written by a newer version"),
    ])
    func unusableHistoryAtLaunchNamesItsReasonForFiveSeconds(failure: HistoryStoreFailure, text: String) {
        let notice = IndicatorNotice(historyUnavailable: failure)

        #expect(notice.content == IndicatorContent(symbolName: "exclamationmark.triangle", text: text))
        #expect(notice.displayDuration == .seconds(5))
    }

    @Test func failedReadSaysSoForTwoAndAHalfSeconds() {
        let notice = IndicatorNotice(historyRuntimeFailure: .sqlite(operation: "items", resultCode: 26))

        #expect(notice.content == IndicatorContent(symbolName: "exclamationmark.triangle", text: "History read failed"))
        #expect(notice.displayDuration == .milliseconds(2500))
    }

    @Test(arguments: ["record", "evict", "delete", "clearAll", "changeRetentionLimit"])
    func everyOtherFailedOperationIsAFailedWrite(operation: String) {
        let notice = IndicatorNotice(historyRuntimeFailure: .sqlite(operation: operation, resultCode: 8))

        #expect(notice.content.text == "History write failed")
        #expect(notice.displayDuration == .milliseconds(2500))
    }
}
