import CoreGraphics
import Testing

@testable import MacInterop

@MainActor
struct PasteKeystrokeInserterTests {
    private let virtualKeyV: Int64 = 9

    @Test func pasteKeystrokeIsCommandVDownThenUpAndNothingElse() {
        let events = PasteKeystrokeInserter.pasteKeystroke()

        #expect(events.map(\.type) == [.keyDown, .keyUp])
        #expect(events.map { $0.getIntegerValueField(.keyboardEventKeycode) } == [virtualKeyV, virtualKeyV])
        let modifiers: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
        #expect(events.map { $0.flags.intersection(modifiers) } == [.maskCommand, .maskCommand])
    }
}
