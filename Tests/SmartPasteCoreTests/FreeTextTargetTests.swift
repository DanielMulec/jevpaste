import SmartPasteCore
import Testing

/// Free-text Target: when Jev judges the Target a free-text place (probability ≥ 0.8), the whole Active Item is
/// pasted as a Direct Paste — outer line breaks stripped, no Candidate Chooser — whatever else Jev answered.
@MainActor
struct FreeTextTargetTests {
    /// Ada's contact card copied with outer line breaks, as a terminal or a document selection yields it.
    static let copiedCard = "\r\n" + PasteAttemptHarness.sourceText + "\n\n"
    static let chatComposer = BoundTarget(
        identity: TargetIdentity(processIdentifier: 42, elementToken: 11),
        context: TargetContext(surroundingText: "Can you summarise this contact?", appName: "ChatGPT"),
        isSecureField: false
    )

    private static func harness(sameTypeGroup: [Candidate] = []) -> PasteAttemptHarness {
        PasteAttemptHarness(sameTypeGroup: sameTypeGroup, focusedTarget: chatComposer, sourceText: copiedCard)
    }

    private static func decision(
        _ choice: Decision.Choice, containsValue: Double = 0.9, freeText: Double
    ) -> DecisionReply {
        .decided(Decision(choice: choice, containsValueProbability: containsValue, freeTextProbability: freeText))
    }

    @Test func atTheThresholdTheWholeItemIsPastedWithoutItsOuterLineBreaksAndNoChooser() {
        let harness = Self.harness(sameTypeGroup: PasteAttemptHarness.emailCandidates)

        harness.hotkey.press()
        harness.jev.reply(Self.decision(.candidate(Candidate(text: "ada@example.com")), freeText: 0.8))
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.chooser.offeredCandidates == nil)
        #expect(harness.log.steps == [.write(PasteAttemptHarness.sourceText), .pasteKeystroke, .restore])
        #expect(harness.presenter.outcomes == [.inserted])
        #expect(harness.presenter.paths == [.freeTextTarget(probability: 0.8)])
    }

    /// The whole item is derived locally from the pinned Active Item, never picked from what Jev was offered.
    @Test func theWholeItemIsDeliveredEvenThoughItIsNotAmongTheCandidates() {
        let harness = Self.harness()

        harness.hotkey.press()
        #expect(harness.jev.requests.first?.candidates.contains(Candidate(text: Self.copiedCard)) == false)
        #expect(
            harness.jev.requests.first?.candidates.contains(Candidate(text: PasteAttemptHarness.sourceText)) == false
        )
        harness.jev.reply(Self.decision(.candidate(Candidate(text: "ada@example.com")), freeText: 0.97))
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.log.steps == [.write(PasteAttemptHarness.sourceText), .pasteKeystroke, .restore])
    }

    @Test(arguments: [
        (Decision.Choice.noneOfThese, 0.9), (Decision.Choice.candidate(Candidate(text: "ada@example.com")), 0.1),
    ])
    func aFreeTextTargetWinsOverNoneOfTheseAndALowGate(choice: Decision.Choice, containsValue: Double) {
        let harness = Self.harness()

        harness.hotkey.press()
        harness.jev.reply(Self.decision(choice, containsValue: containsValue, freeText: 0.93))
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.log.steps == [.write(PasteAttemptHarness.sourceText), .pasteKeystroke, .restore])
        #expect(harness.presenter.outcomes == [.inserted])
    }

    @Test func justBelowTheThresholdTheExcerptFlowIsUnchanged() {
        let harness = Self.harness(sameTypeGroup: PasteAttemptHarness.emailCandidates)

        harness.hotkey.press()
        harness.jev.reply(Self.decision(.candidate(Candidate(text: "ada@example.com")), freeText: 0.79))

        #expect(harness.chooser.offeredCandidates == PasteAttemptHarness.emailCandidates)
        harness.chooser.choose("ada@work.example")
        harness.clock.advance(by: .milliseconds(120))
        #expect(harness.log.steps == [.write("ada@work.example"), .pasteKeystroke, .restore])
        #expect(harness.presenter.paths == [.jev(freeTextProbability: 0.79)])
    }

    @Test func aLabelledEmailFieldStillReceivesOnlyTheExcerpt() {
        let harness = PasteAttemptHarness()

        harness.hotkey.press()
        harness.jev.reply(Self.decision(.candidate(Candidate(text: "ada@example.com")), freeText: 0.05))
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.log.steps == [.write("ada@example.com"), .pasteKeystroke, .restore])
        #expect(harness.presenter.paths == [.jev(freeTextProbability: 0.05)])
    }

    @Test func belowTheThresholdNoneOfTheseIsStillNoSuitableMatch() {
        let harness = Self.harness()

        harness.hotkey.press()
        harness.jev.reply(Self.decision(.noneOfThese, freeText: 0.12))

        #expect(harness.log.steps.isEmpty)
        #expect(harness.presenter.outcomes == [.noSuitableMatch])
        #expect(harness.presenter.paths == [.jev(freeTextProbability: 0.12)])
    }

    @Test func anAttemptThatEndsBeforeJevAnswersReportsNoProbability() {
        let harness = Self.harness()

        harness.hotkey.press()
        harness.clock.advance(by: .seconds(5))

        #expect(harness.presenter.outcomes == [.failed(.timedOut)])
        #expect(harness.presenter.paths == [.jev(freeTextProbability: nil)])
    }

    @Test func aFreeTextTargetThatLostFocusBeforeDeliveryLeavesTheClipboardUntouched() {
        let harness = Self.harness()

        harness.hotkey.press()
        harness.targetResolver.focusedTarget = nil
        harness.jev.reply(Self.decision(.noneOfThese, freeText: 0.95))

        #expect(harness.log.steps.isEmpty)
        #expect(harness.presenter.outcomes == [.failed(.targetChanged)])
        #expect(harness.presenter.paths == [.freeTextTarget(probability: 0.95)])
    }

    @Test(arguments: [PreCheckRefusal.secureField, .suspectedSecret])
    func thePreChecksStillRefuseBeforeJevIsAsked(refusal: PreCheckRefusal) {
        let harness =
            refusal == .secureField
            ? PasteAttemptHarness(focusedTarget: PasteAttemptStartTests.passwordField, sourceText: Self.copiedCard)
            : PasteAttemptHarness(focusedTarget: Self.chatComposer, sourceText: StubPreCheck.secretPrefix + "a\nb")

        harness.hotkey.press()

        #expect(harness.jev.requests.isEmpty)
        #expect(harness.presenter.outcomes == [.refused(refusal)])
    }

    @Test func aSingleLineItemNeverAsksJevEvenInAFreeTextTarget() {
        let harness = PasteAttemptHarness(focusedTarget: Self.chatComposer, sourceText: "ada@example.com\n")

        harness.hotkey.press()
        harness.clock.advance(by: .milliseconds(120))

        #expect(harness.jev.requests.isEmpty)
        #expect(harness.log.steps == [.write("ada@example.com"), .pasteKeystroke, .restore])
        #expect(harness.presenter.paths == [.directPaste])
    }
}
