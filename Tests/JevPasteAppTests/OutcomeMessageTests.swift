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
        (.refused(.targetNotReady(applicationName: "ChatGPT")), "ChatGPT isn't ready — press ⌘⇧V again"),
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
        (PasteAttemptOutcome.inserted, "Pasted · nearby text withheld (suspected secret)"),
        (.noSuitableMatch, "No suitable match · nearby text withheld (suspected secret)"),
        (.failed(.timedOut), "Jev took longer than 5 s · nearby text withheld (suspected secret)"),
    ])
    func withheldSurroundingTextIsNotedAfterTheOutcomeForTwoAndAHalfSeconds(
        outcome: PasteAttemptOutcome, text: String
    ) {
        let message = OutcomeMessage(outcome, note: .surroundingTextWithheld)

        #expect(message.content.text == text)
        #expect(message.content.symbolName == OutcomeMessage(outcome).content.symbolName)
        #expect(message.displayDuration == .milliseconds(2500))
    }

    @Test(arguments: [
        (PasteAttemptOutcome.inserted, "inserted"),
        (.insertedWithoutRestore, "insertedWithoutRestore"),
        (.noSuitableMatch, "noSuitableMatch"),
        (.refused(.noActiveItem), "refused.noActiveItem"),
        (.refused(.noEditableTarget), "refused.noEditableTarget"),
        (.refused(.secureField), "refused.secureField"),
        (.refused(.suspectedSecret), "refused.suspectedSecret"),
        (.refused(.targetNotReady(applicationName: "ChatGPT")), "refused.targetNotReady"),
        (.refused(.targetNotReady(applicationName: "Notes (Beta)")), "refused.targetNotReady"),
        (.refused(.targetNotReady(applicationName: ".secureField")), "refused.targetNotReady"),
        (.cancelled, "cancelled"),
        (.failed(.timedOut), "failed.timedOut"),
    ])
    func logNameIsTheShortOutcomeKind(outcome: PasteAttemptOutcome, logName: String) {
        #expect(OutcomeMessage.logName(for: outcome) == logName)
    }
}
