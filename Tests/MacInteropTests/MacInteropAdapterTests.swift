import MacInterop
import SmartPasteCore
import Testing

@Test @MainActor func systemClipboardFillsTheClipboardSeam() {
    let clipboard: any Clipboard = SystemClipboard()
    #expect(clipboard is SystemClipboard)
}

@Test @MainActor func globalHotkeyFillsTheHotkeySeam() {
    let hotkey: any Hotkey = GlobalHotkey()
    #expect(hotkey is GlobalHotkey)
}

@Test @MainActor func accessibilityResolverFillsTheTargetResolverSeam() {
    let resolver: any TargetResolver = AccessibilityTargetResolver()
    #expect(resolver is AccessibilityTargetResolver)
}

@Test @MainActor func pasteboardSwapInserterFillsTheInserterSeam() {
    let inserter: any Inserter = PasteboardSwapInserter()
    #expect(inserter is PasteboardSwapInserter)
}
