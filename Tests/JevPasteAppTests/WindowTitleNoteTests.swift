import SmartPasteCore
import Testing

@testable import JevPasteApp

/// A withheld window title is noted on the outcome like withheld surrounding text.
@MainActor
struct WindowTitleNoteTests {
    @Test(arguments: [
        (PasteAttemptNote.windowTitleWithheld, "Pasted · window title withheld (suspected secret)"),
        (.surroundingTextAndWindowTitleWithheld, "Pasted · nearby text and window title withheld (suspected secret)"),
    ])
    func aWithheldWindowTitleIsNotedAfterTheOutcome(note: PasteAttemptNote, text: String) {
        let message = OutcomeMessage(.inserted, note: note)

        #expect(message.content.text == text)
        #expect(message.displayDuration == .milliseconds(2500))
    }

    @Test(arguments: [PasteAttemptNote.windowTitleWithheld, .surroundingTextAndWindowTitleWithheld])
    func theLogLineNamesTheNote(note: PasteAttemptNote) {
        let line = IndicatorPresenter.outcomeLogLine(.inserted, note: note, path: nil)
        #expect(line == "outcome inserted note=\(note)")
    }
}
