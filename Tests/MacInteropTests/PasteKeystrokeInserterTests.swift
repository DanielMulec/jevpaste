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

    /// A private source (its own state ID) keeps any other held key out of the synthetic ⌘V.
    @Test func pasteKeystrokeComesFromAPrivateEventSource() {
        let sourceStates = PasteKeystrokeInserter.pasteKeystroke().map {
            $0.getIntegerValueField(.eventSourceStateID)
        }
        let sharedStates = [CGEventSourceStateID.combinedSessionState, .hidSystemState].map { Int64($0.rawValue) }
        #expect(sourceStates.count == 2)
        #expect(sourceStates.allSatisfy { !sharedStates.contains($0) })
    }
}
