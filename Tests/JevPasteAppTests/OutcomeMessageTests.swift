import SmartPasteCore
import Testing

@testable import JevPasteApp

struct OutcomeMessageTests {
    @Test func insertedShowsACheckmarkForOneSecond() {
        let message = OutcomeMessage(.inserted)

        #expect(message.content == IndicatorContent(symbolName: "checkmark.circle.fill", text: "Pasted"))
        #expect(message.displayDuration == .seconds(1))
    }

    @Test(arguments: [
        (
            PasteAttemptOutcome.insertedWithoutRestore,
            "Pasted — original clipboard not restored (replaced by your new copy)"
        ),
        (.noSuitableMatch, "No suitable match"),
        (.refused(.noActiveItem), "Nothing copied yet"),
        (.refused(.noEditableTarget), "No text field focused"),
        (
            .refused(.targetWaking(applicationName: "ChatGPT")),
            "Waking ChatGPT for Smart Paste — press ⌘⇧V again in a moment"
        ),
        (.refused(.secureField), "Secure field — not supported"),
        (.refused(.suspectedSecret), "Suspected secret — blocked"),
        (.cancelled, "Cancelled"),
        (.failed(.timedOut), "Jev took longer than 5 s"),
        (.failed(.decisionUnavailable), "Jev unavailable"),
        (.failed(.invalidResult), "Jev's answer was not an exact excerpt"),
        (.failed(.targetChanged), "Target changed — nothing pasted"),
    ])
    func everyOtherOutcomeNamesItsReasonForTwoAndAHalfSeconds(outcome: PasteAttemptOutcome, reason: String) {
        let message = OutcomeMessage(outcome)

        #expect(message.content.text == reason)
        #expect(!message.content.symbolName.isEmpty)
        #expect(message.displayDuration == .milliseconds(2500))
    }

    @Test(arguments: [
        (PasteAttemptOutcome.inserted, "inserted"),
        (.insertedWithoutRestore, "insertedWithoutRestore"),
        (.noSuitableMatch, "noSuitableMatch"),
        (.refused(.noEditableTarget), "refused.noEditableTarget"),
        (.refused(.targetWaking(applicationName: "ChatGPT")), "refused.targetWaking"),
        (.cancelled, "cancelled"),
        (.failed(.timedOut), "failed.timedOut"),
    ])
    func logNameIsTheShortOutcomeKind(outcome: PasteAttemptOutcome, logName: String) {
        #expect(OutcomeMessage.logName(for: outcome) == logName)
    }
}
