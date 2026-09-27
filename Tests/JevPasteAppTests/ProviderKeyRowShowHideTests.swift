import AppKit
import SmartPasteCore
import Testing

@testable import JevPasteApp

/// Show/Hide swaps the secure field for the plain one mid-edit: the text and the selection carry over, and the swap
/// is not "editing ended" — nothing is saved and nothing leaves Clipboard History.
@MainActor
struct ProviderKeyRowShowHideTests {
    @Test func showAndHideKeepTheValueAndSelectionWithoutSavingOrExcluding() throws {
        let key = "fake-key-0123456789"
        let store = InMemoryJevKeyStore(keys: [.typesafeDirect: key])
        var exclusions = 0
        let settings = ProviderKeySettings(
            keys: store, excludeFromHistory: { _ in exclusions += 1 }, runTest: { _, _ in }
        )
        let row = ProviderKeyRow(provider: .typesafeDirect, settings: settings)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 100), styleMask: [.titled], backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = row.view
        defer { window.close() }
        let secure = row.keyFields[0]
        let plain = row.keyFields[1]
        #expect(window.makeFirstResponder(secure))
        let selection = NSRange(location: 3, length: 5)
        try #require(secure.currentEditor()).selectedRange = selection

        row.toggleShown()
        #expect(plain.currentEditor() != nil)
        #expect(try #require(plain.currentEditor()).selectedRange == selection)
        #expect(plain.stringValue == key)

        row.toggleShown()
        #expect(secure.currentEditor() != nil)
        #expect(try #require(secure.currentEditor()).selectedRange == selection)
        #expect(secure.stringValue == key)

        #expect(store.writes == 0)
        #expect(exclusions == 0)
        #expect(store.apiKey(for: .typesafeDirect) == key)
    }
}
