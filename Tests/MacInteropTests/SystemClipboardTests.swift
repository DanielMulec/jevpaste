import AppKit
import MacInterop
import SmartPasteCore
import Testing

@MainActor
struct SystemClipboardTests {
    private let scratch = ScratchPasteboard()
    private var pasteboard: NSPasteboard { scratch.pasteboard }

    @Test func writtenTextIsWhatTheSnapshotHoldsAsPlainText() {
        let clipboard = SystemClipboard(pasteboard: pasteboard, pollingSchedule: ManualPollingSchedule())

        _ = clipboard.write("Jane Doe")

        let plainText = clipboard.snapshot().items.first?[NSPasteboard.PasteboardType.string.rawValue]
        #expect(plainText == Data("Jane Doe".utf8))
    }

    @Test func restorePutsBackEveryItemAndTypeByteForByte() {
        let clipboard = SystemClipboard(pasteboard: pasteboard, pollingSchedule: ManualPollingSchedule())
        let original = ClipboardSnapshot(items: [
            ["public.utf8-plain-text": Data("first".utf8), "public.html": Data("<b>first</b>".utf8)],
            ["com.example.custom": Data([0x00, 0xFF, 0x10])],
        ])

        _ = clipboard.restore(original)

        #expect(clipboard.snapshot() == original)
    }

    @Test func writeAndRestoreReturnTheChangeCountTheyProduced() {
        let clipboard = SystemClipboard(pasteboard: pasteboard, pollingSchedule: ManualPollingSchedule())
        let original = clipboard.snapshot()

        let afterWrite = clipboard.write("Jane Doe")
        #expect(afterWrite == pasteboard.changeCount)
        let afterRestore = clipboard.restore(original)
        #expect(afterRestore == pasteboard.changeCount)
        #expect(afterRestore > afterWrite)
    }
}
