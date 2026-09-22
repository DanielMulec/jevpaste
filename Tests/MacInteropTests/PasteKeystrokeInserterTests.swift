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

    /// A private source (its own state ID) keeps the keys still held from ⌘⇧V out of the synthetic ⌘V.
    @Test func pasteKeystrokeComesFromAPrivateEventSource() {
        let sourceStates = PasteKeystrokeInserter.pasteKeystroke().map {
            $0.getIntegerValueField(.eventSourceStateID)
        }
        let sharedStates = [CGEventSourceStateID.combinedSessionState, .hidSystemState].map { Int64($0.rawValue) }
        #expect(sourceStates.count == 2)
        #expect(sourceStates.allSatisfy { !sharedStates.contains($0) })
    }

    @Test func postsAtOnceWhenNoShortcutKeyIsHeld() {
        let keyboard = FakeKeyboard(heldForPolls: 0)
        let poster = RecordingPoster()

        PasteKeystrokeInserter(keyboard: keyboard, post: poster.post).postPasteKeystroke()

        #expect(keyboard.pauses.isEmpty)
        #expect(poster.postedEventCount == 2)
    }

    @Test func waitsInTenMillisecondStepsUntilTheShortcutKeysAreReleased() {
        let keyboard = FakeKeyboard(heldForPolls: 3)
        let poster = RecordingPoster()

        PasteKeystrokeInserter(keyboard: keyboard, post: poster.post).postPasteKeystroke()

        #expect(keyboard.pauses == Array(repeating: .milliseconds(10), count: 3))
        #expect(poster.postedEventCount == 2)
    }

    @Test func stopsWaitingAfterOneSecondAndPastesAnyway() {
        let keyboard = FakeKeyboard(heldForPolls: .max)
        let poster = RecordingPoster()

        PasteKeystrokeInserter(keyboard: keyboard, post: poster.post).postPasteKeystroke()

        #expect(keyboard.pauses.count == 100)
        #expect(poster.postedEventCount == 2)
    }
}

/// Reports the shortcut keys as held for a number of polls and records every pause instead of sleeping.
@MainActor
final class FakeKeyboard: ShortcutKeyboard {
    private var remainingHeldPolls: Int
    private(set) var pauses: [Duration] = []

    init(heldForPolls: Int) {
        remainingHeldPolls = heldForPolls
    }

    var isPasteShortcutKeyHeld: Bool {
        guard remainingHeldPolls > 0 else { return false }
        remainingHeldPolls -= 1
        return true
    }

    func pause(for duration: Duration) {
        pauses.append(duration)
    }
}

@MainActor
final class RecordingPoster {
    private(set) var postedEventCount = 0

    func post(_ events: [CGEvent]) {
        postedEventCount += events.count
    }
}
