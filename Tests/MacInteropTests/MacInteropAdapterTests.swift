import MacInterop
import SmartPasteCore
import Testing

@Test func systemClipboardFillsTheClipboardSeam() {
    let clipboard: any Clipboard = SystemClipboard()
    #expect(clipboard is SystemClipboard)
}

@Test func globalHotkeyFillsTheHotkeySeam() {
    let hotkey: any Hotkey = GlobalHotkey()
    #expect(hotkey is GlobalHotkey)
}

@Test func accessibilityResolverFillsTheTargetResolverSeam() {
    let resolver: any TargetResolver = AccessibilityTargetResolver()
    #expect(resolver is AccessibilityTargetResolver)
}

@Test func pasteboardSwapInserterFillsTheInserterSeam() {
    let inserter: any Inserter = PasteboardSwapInserter()
    #expect(inserter is PasteboardSwapInserter)
}
