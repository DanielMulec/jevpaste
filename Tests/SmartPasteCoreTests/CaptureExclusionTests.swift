import Foundation
import SmartPasteCore
import Testing

/// A copy that is a secret JevPaste itself holds (a stored Jev Provider key) is treated like a marked secret: it
/// becomes the Active Item as a concealed item and never enters Clipboard History — at launch or on a live copy.
@MainActor
struct CaptureExclusionTests {
    private let clipboard = FakeClipboard(log: DeliveryLog(clock: ManualClock()), initialText: "")
    private let history = FakeHistoryRepository()
    private let exclusion = FakeCaptureExclusion(excluded: ["fake-provider-key-0000"])

    private func capture(contentsAtLaunch: ClipboardItem? = nil) -> CopyCapture {
        CopyCapture(
            clipboard: clipboard, history: history, exclusion: exclusion, contentsAtLaunch: { contentsAtLaunch }
        )
    }

    @Test func anExcludedLiveCopyBecomesAConcealedActiveItemAndIsNeverRecorded() {
        let capture = capture()

        clipboard.simulateForeignCopy("fake-provider-key-0000")

        #expect(capture.activeItem == ClipboardItem(text: "fake-provider-key-0000", isConcealed: true))
        #expect(history.recordedItems.isEmpty)
        #expect(exclusion.askedTexts == ["fake-provider-key-0000"])
    }

    @Test func anExcludedLaunchContentIsNeverRecorded() {
        let capture = capture(contentsAtLaunch: ClipboardItem(text: "fake-provider-key-0000"))

        #expect(capture.activeItem == ClipboardItem(text: "fake-provider-key-0000", isConcealed: true))
        #expect(history.recordedItems.isEmpty)
    }

    @Test func aCopyThatIsNotExcludedIsRecordedUnchanged() {
        let capture = capture()

        clipboard.simulateForeignCopy("Wren Castellan")

        #expect(capture.activeItem == ClipboardItem(text: "Wren Castellan"))
        #expect(history.items() == [ClipboardItem(text: "Wren Castellan")])
    }

    @Test func anAlreadyConcealedCopyIsNotAskedAbout() {
        _ = capture(contentsAtLaunch: ClipboardItem(text: "correct horse battery staple", isConcealed: true))

        #expect(exclusion.askedTexts.isEmpty)
        #expect(history.recordedItems.isEmpty)
    }
}

/// Excludes exactly the texts it was given and remembers every text it was asked about.
@MainActor
final class FakeCaptureExclusion: CaptureExclusion {
    private let excluded: Set<String>
    private(set) var askedTexts: [String] = []

    init(excluded: Set<String>) {
        self.excluded = excluded
    }

    func excludes(_ text: String) -> Bool {
        askedTexts.append(text)
        return excluded.contains(text)
    }
}
