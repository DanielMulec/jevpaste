import AppKit
import MacInterop
import SmartPasteCore
import Testing

/// `currentItem()` reads what is on the clipboard right now, so the app can seed the Active Item at launch.
@MainActor
struct ClipboardCurrentItemTests {
    private let scratch = ScratchPasteboard()

    private var clipboard: SystemClipboard {
        SystemClipboard(pasteboard: scratch.pasteboard, pollingSchedule: ManualPollingSchedule())
    }

    @Test func textOnTheClipboardIsTheCurrentItem() {
        scratch.copyLikeAnotherApp(["public.utf8-plain-text": Data("Tamsin Vorlage".utf8)])

        #expect(clipboard.currentItem() == ClipboardItem(text: "Tamsin Vorlage"))
    }

    @Test func markedTextIsAConcealedCurrentItem() {
        scratch.copyLikeAnotherApp([
            "public.utf8-plain-text": Data("hunter2".utf8), "org.nspasteboard.ConcealedType": Data(),
        ])

        #expect(clipboard.currentItem() == ClipboardItem(text: "hunter2", isConcealed: true))
    }

    @Test func clipboardWithoutTextHasNoCurrentItem() {
        scratch.copyLikeAnotherApp(["public.png": Data([0x89, 0x50])])

        #expect(clipboard.currentItem() == nil)
    }
}
