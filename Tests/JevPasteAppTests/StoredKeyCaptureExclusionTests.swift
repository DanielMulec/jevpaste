import Foundation
import OSLog
import SmartPasteCore
import Testing

@testable import JevPasteApp

/// A copy of a stored Jev Provider key never reaches Clipboard History; the log says only that a copy matched.
@MainActor
struct StoredKeyCaptureExclusionTests {
    private let keys = InMemoryJevKeyStore(keys: [.vercelAIGateway: "fake-stored-key-5301"])

    @Test(arguments: ["fake-stored-key-5301", "  fake-stored-key-5301\n"])
    func aCopyOfAStoredKeyIsExcluded(copied: String) {
        #expect(StoredKeyCaptureExclusion(keys: keys).excludes(copied))
    }

    @Test(arguments: ["fake-stored-key-530", "fake-stored-key-5301 and more", "", "   "])
    func anyOtherCopyIsNotExcluded(copied: String) {
        #expect(!StoredKeyCaptureExclusion(keys: keys).excludes(copied))
    }

    @Test func aKeySavedLaterCountsAtTheNextCopy() throws {
        let exclusion = StoredKeyCaptureExclusion(keys: keys)
        #expect(!exclusion.excludes("fake-later-key-5302"))

        try keys.setAPIKey("fake-later-key-5302", for: .typesafeDirect)

        #expect(exclusion.excludes("fake-later-key-5302"))
    }

    @Test func aCopiedKeyStaysOutOfHistoryAndOutOfTheLog() throws {
        let clipboard = CopyingClipboard()
        let scratch = try ScratchHistory()
        let start = Date()
        let capture = CopyCapture(
            clipboard: clipboard, history: scratch.repository, exclusion: StoredKeyCaptureExclusion(keys: keys)
        )

        clipboard.copy("fake-stored-key-5301")

        #expect(capture.activeItem?.isConcealed == true)
        #expect(scratch.repository.entries().isEmpty)
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let messages = try store.getEntries(at: store.position(date: start))
            .compactMap { $0 as? OSLogEntryLog }.filter { $0.subsystem == "jevpaste" }.map(\.composedMessage)
        #expect(messages.contains("copy of a stored key kept out of history"))
        #expect(!messages.contains { $0.contains("fake-stored-key") })
    }
}
