import AppKit
import SmartPasteCore
import Testing

@testable import JevPasteApp

/// A long key stays one scrolling line in both key fields (the secure one and the plain one behind Show) — it never
/// wraps into a second row that the one-line field hides.
@MainActor
struct ProviderKeyRowTests {
    private static func row(savedKey: String) -> ProviderKeyRow {
        let settings = ProviderKeySettings(
            keys: InMemoryJevKeyStore(keys: [.typesafeDirect: savedKey]), excludeFromHistory: { _ in },
            runTest: { _, _ in }
        )
        return ProviderKeyRow(provider: .typesafeDirect, settings: settings)
    }

    @Test func bothKeyFieldsAreOneScrollingLine() throws {
        let row = Self.row(savedKey: "fake-key-" + String(repeating: "x", count: 191))

        for field in row.keyFields {
            let cell = try #require(field.cell)
            #expect(cell.usesSingleLineMode)
            #expect(!cell.wraps)
            #expect(cell.isScrollable)
            #expect(cell.lineBreakMode == .byClipping)
        }
    }

    @Test func aTwoHundredCharacterKeyIsAsTallAsAOneCharacterKey() throws {
        let long = Self.row(savedKey: "fake-key-" + String(repeating: "x", count: 191))
        let short = Self.row(savedKey: "f")
        let bounds = NSRect(x: 0, y: 0, width: 300, height: 1000)

        for (longField, shortField) in zip(long.keyFields, short.keyFields) {
            let longHeight = try #require(longField.cell).cellSize(forBounds: bounds).height
            let shortHeight = try #require(shortField.cell).cellSize(forBounds: bounds).height
            #expect(longField.stringValue.count == 200)
            #expect(longHeight == shortHeight)
        }
    }
}
